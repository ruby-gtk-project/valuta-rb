# frozen_string_literal: true

require 'adwaita'

require_relative 'currencies_list_model'
require_relative 'currency_selector_row'

# CurrencySelector is the menu button that opens a searchable currency list.
#
# Ported from upstream's src/components/currency_selector/
# currency_selector.py and index.blp: a MenuButton showing the selected code
# (and an insight label beside it), whose popover holds a search entry over a
# scrolled list of every currency the provider quotes. The list is sorted by
# name and filtered by the search text; Enter activates the first match,
# Escape closes the popover, and closing it resets the search and the scroll
# position.
#
# Upstream drives the list through Gtk.SortListModel / Gtk.FilterListModel on
# top of its Gio.ListModel and a `selected` GObject property; this port asks
# CurrenciesListModel for the sorted, filtered list and rebuilds the rows, and
# notifies listeners of a selection change instead of emitting notify::.
#
class CurrencySelector < Adwaita::Bin
  POPOVER_SIZE = 300

  attr_reader :selected, :model

  def initialize
    super()
    @selected = nil
    @model = nil
    @selected_listeners = []
    @user_selection_listeners = []
  end

  def build
    tap do |selector|
      selector.child = button

      button.tap do |b|
        b.child = button_box
        b.popover = popover

        button_box.tap do |box|
          box.append(label)
          box.append(insight)
        end
      end

      popover.tap do |pop|
        pop.child = popover_box
        pop.signal_connect('show') { search.grab_focus }
        pop.signal_connect('closed') { reset_search }

        popover_box.tap do |box|
          box.append(search_box)
          box.append(scroll)

          search_box.tap do |sb|
            sb.append(search)

            search.tap do |entry|
              entry.key_capture_widget = popover
              entry.signal_connect('search-changed') { populate }
              entry.signal_connect('activate') { activate_first_row }
              entry.add_controller(key_events)
            end
          end

          scroll.tap do |sw|
            sw.child = currency_list

            currency_list.signal_connect('row-activated') { |_list, row| activated(row) }
          end
        end
      end

      key_events.tap do |controller|
        controller.signal_connect('key-pressed') { |_c, keyval, _code, _state| on_key_pressed(keyval) }
      end
    end
  end

  # Upstream's bind_models: adopt the model, then show what it holds.
  def bind_models(currencies)
    @model = currencies
    @model.on_items_changed { populate }
    populate
    @model
  end

  # Upstream assigns its `selected` property here, so the body runs on every
  # call but notify:: only fires when the value actually changes; the listeners
  # below are notified on the same terms, which is what keeps the page and the
  # settings from bouncing a change back and forth.
  def set_selected(code)
    @model.then do |model|
      if model
        changed = @selected != code
        @selected = code
        model.set_selected(code)
        label.label = code.to_s
        insight.label = ''
        if changed
          notify_selected
        end
      end
    end
  end

  # Upstream's set_insight: only the pseudo-code "auto" names the currency it
  # resolved to beside the code.
  def set_insight(code)
    (@selected == 'auto').then do |resolving|
      if resolving
        insight.label = "(#{currency_name(code)})"
      end
    end
  end

  def on_selected_changed(&listener)
    @selected_listeners << listener
    listener
  end

  def on_user_selection_changed(&listener)
    @user_selection_listeners << listener
    listener
  end

  # Widgets

  def button
    @button ||= Gtk::MenuButton.new.tap do |b|
      b.always_show_arrow = true
      b.valign = :center
      b.halign = :center
      b.add_css_class('rised')
      b.add_css_class('flat')
    end
  end

  def button_box = @button_box ||= Gtk::Box.new(:horizontal, 3)

  def label
    @label ||= Gtk::Label.new.tap do |l|
      l.ellipsize = :end
      l.xalign = 0
    end
  end

  def insight
    @insight ||= Gtk::Label.new.tap do |l|
      l.ellipsize = :end
      l.xalign = 0
    end
  end

  # The stylesheet names this class ".currency-selector"; upstream's blueprint
  # misspells it as "curency-selector", so upstream's own popover rules never
  # match. This port applies the class the stylesheet defines.
  def popover
    @popover ||= Gtk::Popover.new.tap do |pop|
      pop.width_request = POPOVER_SIZE
      pop.height_request = POPOVER_SIZE
      pop.add_css_class('currency-selector')
      pop.add_css_class('menu')
    end
  end

  def popover_box = @popover_box ||= Gtk::Box.new(:vertical, 0)

  def search_box
    @search_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.add_css_class('search-box')
    end
  end

  def search
    @search ||= Gtk::SearchEntry.new.tap do |entry|
      entry.placeholder_text = 'Search Currencies'
    end
  end

  def scroll
    @scroll ||= Gtk::ScrolledWindow.new.tap do |sw|
      sw.vexpand = true
    end
  end

  def currency_list
    @currency_list ||= Gtk::ListBox.new.tap do |list|
      list.selection_mode = :single
    end
  end

  def key_events = @key_events ||= Gtk::EventControllerKey.new

  private

    def populate
      clear
      @model.then do |model|
        if model
          model.filtered(search.text).each do |currency|
            currency_list.append(CurrencySelectorRow.new(currency).build)
          end
        end
      end
    end

    def clear
      while (row = currency_list.first_child)
        currency_list.remove(row)
      end
    end

    def activated(row)
      popover.popdown
      set_selected(row.currency.code)
      @user_selection_listeners.each(&:call)
    end

    def activate_first_row
      search.text.empty?.then do |blank|
        unless blank
          currency_list.get_row_at_index(0).then do |row|
            if row
              currency_list.signal_emit('row-activated', row)
            end
          end
        end
      end
    end

    def reset_search
      scroll.vadjustment.value = 0
      search.text = ''
    end

  # Escape closes the popover; Down is swallowed so the search entry keeps the
  # focus instead of the list stealing it.
    def on_key_pressed(keyval)
      if keyval == Gdk::Keyval::KEY_Escape
        popover.popdown
        false
      elsif keyval == Gdk::Keyval::KEY_Down
        true
      else
        false
      end
    end

    def notify_selected
      @selected_listeners.each { |listener| listener.call(@selected) }
    end

    def currency_name(code) = @model.names_func.call(code)
end
