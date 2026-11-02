# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'gio2'

# Settings holds the same keys as upstream's io.github.idevecore.Valuta
# GSettings schema.
#
# Ported from data/io.github.idevecore.Valuta.gschema.xml.in (the seven keys
# and their defaults) and the Settings wrapper in src/utils.py. Upstream uses
# GSettings, which needs a compiled schema installed into the system's
# glib-2.0/schemas directory; requiring an install step to run the app from a
# checkout is worse than the alternative, so the same keys, defaults,
# enumerations and change notifications are backed by a small JSON file under
# XDG_CONFIG_HOME instead.
#
# Gio alone is required, not gtk4: the shell search provider loads this class
# in a process that D-Bus activates, which may have no display, and requiring
# the gtk4 gem calls Gtk.init at load time.
#
class Settings
  # The schema's <enum id="…Window"> — one nick per provider index, so
  # get_enum('providers') answers the integer the request layer indexes by.
  ENUMS = {
    'providers' => %w[ecb].freeze,
  }.freeze

  DEFAULTS = {
    'providers'     => 'ecb',
    'width'         => 420,
    'height'        => 600,
    'is-maximized'  => false,
    'is-fullscreen' => false,
    'src-currency'  => 'USD',
    'dest-currency' => 'EUR',
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
    @listeners = {}
  end

  def location = @path

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  # Writing a key persists it and notifies the "changed::<key>" listeners, the
  # way GSettings does. Writing the value a key already holds is a no-op, so
  # listeners do not see spurious changes.
  def []=(key, value)
    name = key.to_s
    (@values[name] == value).then do |unchanged|
      unless unchanged
        @values[name] = value
        write
        notify(name)
      end
    end
    value
  end

  # The GSettings reader/writer names the port's callers use, so the ported
  # code reads like upstream's.
  def get_string(key) = self[key].to_s
  def set_string(key, value) = (self[key] = value.to_s)
  def get_int(key) = self[key].to_i
  def set_int(key, value) = (self[key] = value.to_i)
  def get_boolean(key) = self[key] == true
  def set_boolean(key, value) = (self[key] = value == true)

  def get_enum(key) = nicks(key).index(get_string(key)).to_i

  def set_enum(key, value)
    nicks(key)[value.to_i].then do |nick|
      if nick
        set_string(key, nick)
      end
    end
  end

  def on_changed(key, &callback)
    (@listeners[key.to_s] ||= []) << callback
    callback
  end

  # GSettings.create_action's stand-in: a stateful action whose state is the
  # key's nick, which is what window.blp's provider menu items target.
  def create_action(key)
    Gio::SimpleAction.new(
      key.to_s,
      GLib::VariantType.new('s'),
      GLib::Variant.new(get_string(key)),
    ).tap do |action|
      # ruby-gnome hands the action parameter over already unwrapped, so this
      # is a Ruby String rather than a GLib::Variant.
      action.signal_connect('activate') { |_, parameter| set_string(key, parameter.to_s) }
      on_changed(key) { action.set_state(GLib::Variant.new(get_string(key))) }
    end
  end

  # Upstream binds width/height/is-maximized/is-fullscreen to the window with
  # Gio.SettingsBindFlags.DEFAULT; this is the restore half of that bind.
  def apply_to(window)
    window.set_default_size(get_int('width'), get_int('height'))
    if get_boolean('is-maximized')
      window.maximize
    end
    if get_boolean('is-fullscreen')
      window.fullscreen
    end
  end

  # …and this is the store half. The size is skipped while the window is
  # maximized or fullscreen, so the restored size is the one the user chose.
  def remember(window)
    self['is-maximized'] = window.maximized?
    self['is-fullscreen'] = window.fullscreen?

    (window.maximized? || window.fullscreen?).then do |filling_the_screen|
      unless filling_the_screen
        @values['width'] = window.default_width
        @values['height'] = window.default_height
        write
      end
    end
  end

  private

    def nicks(key) = ENUMS.fetch(key.to_s, [])

    def notify(name)
      @listeners.fetch(name, []).each { |callback| callback.call(self, name) }
    end

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'valuta-rb',
        'settings.json',
      )
    end

    def read
      File.exist?(@path).then do |present|
        if present
          parse(File.read(@path))
        else
          {}
        end
      end
    end

    def parse(contents)
      JSON.parse(contents)
    rescue JSON::ParserError
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "#{JSON.pretty_generate(@values)}\n")
    end
end
