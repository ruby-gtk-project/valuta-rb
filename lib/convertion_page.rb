# frozen_string_literal: true

require 'adwaita'

require_relative 'currencies_list_model'
require_relative 'currency_selector'
require_relative 'define'

# ConvertionPage is the application's only page: an amount in one currency and
# the same amount in another.
#
# Ported from upstream's src/pages/convertion/convertion.py and index.blp. The
# "From" group holds the amount entry and its currency selector; a circular
# button between the groups triggers app.switch-currencies; the "To" group
# holds an accent-coloured panel whose stack shows the result, a spinner while
# a rate is being fetched, or a reload button when the fetch failed. A failed
# conversion also raises a toast.
#
# The rate is fetched off the main thread, as upstream does with a Gio.Task;
# every widget touch that follows is marshalled back onto the main loop with
# an idle callback, so the fetch never blocks the UI and never touches a widget
# from the worker.
#
class ConvertionPage
  RESULT = 'result'
  LOADING = 'loading'
  ERROR = 'convertion-error'

  ENTRY_HEIGHT = 70
  SPINNER_SIZE = 25
  GROUP_MARGIN = 24
  FROM_GROUP_BOTTOM_MARGIN = 20

  FALLBACK_SRC = 'USD'
  FALLBACK_DEST = 'EUR'

  TOAST_MESSAGE = 'Error converting, please try again.'

  def initialize(utils, from_currency_value = 0)
    @utils = utils
    @settings = utils.settings
    @convertion = utils.convertion
    @from_currency_value = from_currency_value
  end

  def build
    toast_overlay.tap do |overlay|
      overlay.child = page_box

      page_box.tap do |box|
        box.append(preferences_page)

        preferences_page.tap do |page|
          page.add(from_group)
          page.add(switch_group)
          page.add(to_group)

          from_group.tap do |group|
            group.header_suffix = from_selector_box
            group.add(from_currency_entry)

            from_selector_box.append(from_currency_selector.build)

            from_currency_entry.signal_connect('changed') { |entry| convert(entry.text) }
          end

          switch_group.add(invert_currencies)

          to_group.tap do |group|
            group.header_suffix = to_selector_box
            group.add(result_bin)

            to_selector_box.append(to_currency_selector.build)

            result_bin.child = stack

            stack.tap do |st|
              st.add_named(result_handle, RESULT)
              st.add_named(loading_handle, LOADING)
              st.add_named(error_handle, ERROR)

              result_handle.child = to_currency_entry
              loading_handle.child = spinner_box
              error_handle.child = reload_box

              spinner_box.append(spinner)
              reload_box.append(reload)

              reload.signal_connect('clicked') { convert(from_currency_entry.text) }
            end
          end
        end
      end

      # The order is upstream's: the models are filled and the selections
      # restored before anything is listening, so restoring them does not look
      # like the user choosing a currency and write a half-built pair back to
      # the settings.
      load_currencies(@settings.get_enum('providers'))

      from_currency_selector.on_selected_changed { currency_selectors_changed }
      to_currency_selector.on_selected_changed { currency_selectors_changed }

      @convertion.connect('converted') { |data| on_main_loop { converted(data) } }

      @settings.on_changed('providers') { change_provider }
      @settings.on_changed('src-currency') { from_currency_selector.set_selected(@settings.get_string('src-currency')) }
      @settings.on_changed('dest-currency') { to_currency_selector.set_selected(@settings.get_string('dest-currency')) }

      from_currency_entry.text = initial_amount
    end
  end

  # Widgets

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

  def page_box
    @page_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.valign = :center
    end
  end

  def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new

  def from_group
    @from_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = 'From'
      group.margin_start = GROUP_MARGIN
      group.margin_end = GROUP_MARGIN
      group.margin_bottom = FROM_GROUP_BOTTOM_MARGIN
    end
  end

  def from_selector_box = @from_selector_box ||= Gtk::Box.new(:horizontal, 0)

  def from_currency_selector = @from_currency_selector ||= CurrencySelector.new

  def from_currency_entry
    @from_currency_entry ||= Gtk::Entry.new.tap do |entry|
      entry.add_css_class('f-l')
      entry.xalign = 0.5
      entry.height_request = ENTRY_HEIGHT
      entry.input_purpose = :number
    end
  end

  def switch_group
    @switch_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.halign = :center
      group.valign = :center
    end
  end

  def invert_currencies
    @invert_currencies ||= Gtk::Button.new.tap do |button|
      button.add_css_class('circular')
      button.add_css_class('pd')
      button.tooltip_text = 'Switch'
      button.icon_name = 'vertical-arrows-symbolic'
      button.action_name = 'app.switch-currencies'
    end
  end

  def to_group
    @to_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = 'To'
      group.add_css_class('top-transform')
      group.margin_start = GROUP_MARGIN
      group.margin_end = GROUP_MARGIN
    end
  end

  def to_selector_box = @to_selector_box ||= Gtk::Box.new(:horizontal, 0)

  def to_currency_selector = @to_currency_selector ||= CurrencySelector.new

  def result_bin
    @result_bin ||= Adwaita::Bin.new.tap do |bin|
      bin.add_css_class('f-l')
      bin.add_css_class('text-light')
      bin.add_css_class('bg-accent-color')
      bin.add_css_class('rounded')
    end
  end

  def stack
    @stack ||= Gtk::Stack.new.tap do |st|
      st.transition_type = :crossfade
    end
  end

  def result_handle = @result_handle ||= Gtk::WindowHandle.new

  def to_currency_entry
    @to_currency_entry ||= Gtk::Label.new.tap do |label|
      label.selectable = true
      label.xalign = 0.5
      label.height_request = ENTRY_HEIGHT
    end
  end

  def loading_handle = @loading_handle ||= Gtk::WindowHandle.new

  def spinner_box
    @spinner_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.halign = :center
      box.valign = :center
    end
  end

  def spinner
    @spinner ||= Gtk::Spinner.new.tap do |sp|
      sp.spinning = true
      sp.width_request = SPINNER_SIZE
      sp.height_request = SPINNER_SIZE
    end
  end

  def error_handle = @error_handle ||= Gtk::WindowHandle.new

  def reload_box
    @reload_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.halign = :center
      box.valign = :center
    end
  end

  def reload
    @reload ||= Gtk::Button.new.tap do |button|
      button.add_css_class('circular')
      button.icon_name = 'refresh-large-symbolic'
      button.tooltip_text = 'Reload'
    end
  end

  private

  # Only the codes the chosen provider quotes. Upstream matches the provider's
  # index as a substring of the comma-joined "providers" field, and so does
  # this.
    def load_currencies(provider)
      codes = Define::CODES.select { |_code, details| details['providers'].include?(provider.to_s) }.keys

      from_currency_selector.bind_models(CurrenciesListModel.new(names_func))
      from_currency_selector.model.set_currencies(codes)
      to_currency_selector.bind_models(CurrenciesListModel.new(names_func))
      to_currency_selector.model.set_currencies(codes)

      (codes.include?(@settings.get_string('src-currency')) &&
        codes.include?(@settings.get_string('dest-currency'))).then do |usable|
        unless usable
          @settings.set_string('src-currency', FALLBACK_SRC)
          @settings.set_string('dest-currency', FALLBACK_DEST)
        end
      end

      from_currency_selector.set_selected(@settings.get_string('src-currency'))
      to_currency_selector.set_selected(@settings.get_string('dest-currency'))
    end

    def names_func = ->(code) { Define::CODES.fetch(code, {})['name'] }

    def change_provider
      stack.visible_child_name = LOADING
      load_currencies(@settings.get_enum('providers'))
      convert(from_currency_entry.text, force: true)
    end

    def loading? = stack.visible_child_name == LOADING

  # Upstream's `if from_currency_value:` — in Python an absent option is an
  # empty string and an unset amount is the integer 0, and both are falsey, so
  # both mean "start at 1".
    def initial_amount
      @from_currency_value.to_s.strip.then do |text|
        if text.empty? || text.to_f.zero?
          '1'
        else
          text
        end
      end
    end

  # Upstream's convert: nothing happens while a fetch is in flight unless the
  # caller forces it, an unparseable amount turns the entry red instead, and a
  # parseable one either re-multiplies the cached rate or fetches a new one.
    def convert(value, force: false)
      ((!loading? && !value.to_s.empty?) || force).then do |proceed|
        if proceed
          @utils.parse_number(value).then do |amount|
            if amount
              from_currency_entry.remove_css_class('error')
              dispatch(amount, force: force)
            else
              from_currency_entry.add_css_class('error')
            end
          end
        end
      end
    end

    def dispatch(amount, force: false)
      from_code = from_currency_selector.selected
      to_code = to_currency_selector.selected
      data = @convertion.converted_data
      refetch = data['from'] != from_code || data['to'] != to_code || !data['converted'] || force

      if refetch
        stack.visible_child_name = LOADING
        Thread.new { @convertion.convert(
          amount,
          from_code,
          to_code,
          provider,
        ) }
      else
        @convertion.convert(
          amount,
          from_code,
          to_code,
          provider,
        )
      end
    end

    def provider = @settings.get_enum('providers')

    def converted(data)
      if data['converted']
        show_result(data)
      else
        stack.visible_child_name = ERROR
        toast_overlay.add_toast(Adwaita::Toast.new(TOAST_MESSAGE))
      end
    end

    def show_result(data)
      stack.visible_child_name = RESULT
      @utils.format_number(data['amount']).then do |result|
        if result
          to_currency_entry.label = result
        else
          stack.visible_child_name = ERROR
        end
      end
    end

    def currency_selectors_changed
      from_code = from_currency_selector.selected
      to_code = to_currency_selector.selected

      (from_code == to_code).then do |same|
        unless same
          @settings.set_string('src-currency', from_code)
          @settings.set_string('dest-currency', to_code)
          convert(from_currency_entry.text)
        end
      end
    end

  # The conversion may have been driven from a worker thread, so anything that
  # touches a widget is handed to the main loop first.
    def on_main_loop(&work)
      GLib::Idle.add do
        work.call
        false
      end
    end
end
