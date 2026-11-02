# frozen_string_literal: true

require 'adwaita'

require_relative 'convertion_page'
require_relative 'shortcuts'

# Window is the application window.
#
# Ported from upstream's src/window.py and src/window.blp: a ToolbarView with
# a header bar carrying the primary menu, the conversion page in the middle,
# and a bottom toolbar whose dim label and link button name the rate's date and
# the provider it came from. The primary menu is window.blp's `menu
# primary_menu`, folded in here: a Providers section whose one item targets the
# window.providers action the settings expose, then the shortcuts and about
# items.
#
class Window
  WIDTH_REQUEST = 350
  HEIGHT_REQUEST = 300
  TOOLBAR_MARGIN = 6

  TITLE = 'Valuta'

  def initialize(application, from_currency_value = 0)
    @application = application
    @utils = application.utils
    @settings = @utils.settings
    @convertion = @utils.convertion
    @from_currency_value = from_currency_value
  end

  def build
    window.tap do |win|
      win.content = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = content
        view.add_bottom_bar(status_bar)

        header_bar.pack_end(menu_button)

        status_bar.tap do |bar|
          bar.append(info)
          bar.append(source)
        end
      end

      win.insert_action_group('window', providers_action_group)
      providers_action_group.add_action(@settings.create_action('providers'))
      win.add_action(show_help_overlay_action)

      load_window_state
      @convertion.connect('converted') { |data| on_main_loop { converted(data) } }
      load_convertion_page(@from_currency_value)

      win.application = @application.app
      win.icon_name = @application.app.application_id
      win.signal_connect('close-request') do
        @settings.remember(win)
        false
      end
    end
  end

  # The window's own entry point for a second invocation carrying an amount,
  # which is what upstream attaches to the window object as
  # load_convertion_page.
  def load_convertion_page(from_currency_value = 0)
    content.child = ConvertionPage.new(@utils, from_currency_value).build
  end

  def present = window.present

  # Widgets

  # Adwaita::ApplicationWindow is used by composition rather than inheritance:
  # subclassing it fails in these bindings, while an instance built from the
  # Gtk::Application works.
  def window
    @window ||= Adwaita::ApplicationWindow.new(@application.app).tap do |win|
      win.title = TITLE
      win.width_request = WIDTH_REQUEST
      win.height_request = HEIGHT_REQUEST
    end
  end

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.primary = true
      button.menu_model = primary_menu
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = 'Main menu'
    end
  end

  # window.blp's `menu primary_menu`. The provider item's target is spelled
  # into the action name — "window.providers::ecb" is the detailed form of
  # blueprint's action/target pair.
  def primary_menu
    @primary_menu ||= Gio::Menu.new.tap do |menu|
      menu.append_section(
        'Providers',
        Gio::Menu.new.tap { |section| section.append('ECB', 'window.providers::ecb') },
      )

      menu.append_section(
        nil,
        Gio::Menu.new.tap do |section|
          section.append('Keyboard shortcuts', 'win.show-help-overlay')
          section.append('About Valuta', 'app.about')
        end,
      )
    end
  end

  def content = @content ||= Adwaita::Bin.new

  def status_bar
    @status_bar ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.add_css_class('toolbar')
      box.halign = :center
      box.margin_top = TOOLBAR_MARGIN
      box.margin_bottom = TOOLBAR_MARGIN
    end
  end

  def info
    @info ||= Gtk::Label.new.tap do |label|
      label.add_css_class('dim-label')
    end
  end

  def source
    @source ||= Gtk::LinkButton.new('').tap do |button|
      button.tooltip_text = 'Source'
      button.visible = false
    end
  end

  def providers_action_group = @providers_action_group ||= Gio::SimpleActionGroup.new

  # Upstream gets this action for free from Gtk.Window.set_help_overlay; the
  # shortcuts window cannot be constructed from these bindings, so the action
  # is registered here and presents an Adwaita shortcuts dialog instead.
  def show_help_overlay_action
    @show_help_overlay_action ||= Gio::SimpleAction.new('show-help-overlay').tap do |action|
      action.signal_connect('activate') { Shortcuts.new.build.present(window) }
    end
  end

  private

    def load_window_state
      @settings.apply_to(window)
    end

  # The bottom toolbar's status line: the rate's date, and a link to the
  # request the rate came from, labelled with the provider.
    def converted(data)
      info.text = "#{data['info']} -"
      source.label = @settings.get_string('providers').upcase
      source.uri = @convertion.get_convertion['disclaimer'].to_s
      source.visible = true
    end

  # A conversion can finish on a worker thread, so the status line is updated
  # from the main loop rather than from wherever the event was emitted.
    def on_main_loop(&work)
      GLib::Idle.add do
        work.call
        false
      end
    end
end
