# frozen_string_literal: true

require 'adwaita'

require_relative 'actions'
require_relative 'define'
require_relative 'style'
require_relative 'utils'
require_relative 'window'

# Application is the application singleton.
#
# Ported from upstream's src/application.py: it owns the shared Utils (the
# settings, the conversion cache and the number formatting), installs the
# application's actions, and handles the command line so a second invocation
# carrying --src-currency-value reloads the running window's page with that
# amount instead of starting a new process.
#
# Adwaita::Application is unusable from these bindings, so the application
# object is a Gtk::Application and only the window and the widgets inside it
# are Adwaita's. Upstream overrides do_activate and do_command_line; Ruby
# cannot subclass a GObject class that way without registering a new GType, so
# the same two entry points are the "activate" and "command-line" signals.
#
class Application
  OPTION = '--src-currency-value'

  attr_reader :utils

  def initialize(app_id: Define::APP_ID, flags: :handles_command_line, utils: nil, present: true)
    @app_id = app_id
    @flags = flags
    @utils = utils || Utils.new(app_id)
    @present = present
    @from_currency_value = 0
    @window = nil
  end

  def build
    app.tap do |a|
      a.signal_connect('startup') do
        Style.load
        add_icon_search_path
      end

      a.signal_connect('activate') { activate }

      a.signal_connect('command-line') { |_application, line| command_line(line) }

      Actions.install(self)
    end
  end

  def run(argv = []) = app.run(argv)

  def app = @app ||= Gtk::Application.new(@app_id, @flags)

  # The icons upstream ships in its gresource live in data/icons here, as a
  # hicolor theme the display's icon theme is pointed at.
  def icon_search_path = File.expand_path('../data/icons', __dir__)

  private

    def add_icon_search_path
      Gdk::Display.default.then do |display|
        if display
          Gtk::IconTheme.get_for_display(display).add_search_path(icon_search_path)
        end
      end
    end

    def activate
      app.active_window.then do |existing|
        if existing
          existing.present
        else
          open_window
        end
      end
    end

    def open_window
      @window = Window.new(self, @from_currency_value)
      @window.build
      if @present
        @window.present
      end
    end

  # Upstream's do_command_line: hand the amount to the running window, or
  # remember it for the window that activate is about to build.
    def command_line(command_line)
      src_currency_value(command_line.arguments).then do |value|
        if @window && app.active_window
          @window.load_convertion_page(value)
        else
          @from_currency_value = value
        end
      end

      app.activate
      0
    end

  # The one option upstream registers with add_main_option, accepted in both
  # its "--src-currency-value=12" and "--src-currency-value 12" spellings.
    def src_currency_value(arguments)
      arguments.to_a.map(&:to_s).then do |args|
        args.index { |argument| argument == OPTION }.then do |position|
          if position
            args[position + 1].to_s
          else
            joined_option(args)
          end
        end
      end
    end

    def joined_option(args)
      args.find { |argument| argument.start_with?("#{OPTION}=") }.then do |argument|
        if argument
          argument.split('=', 2).last.to_s
        else
          ''
        end
      end
    end
end
