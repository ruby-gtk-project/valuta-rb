# frozen_string_literal: true

require 'gio2'

require_relative 'define'
require_relative 'utils'

# ConvertionService answers the GNOME Shell overview's searches.
#
# Ported from the ConvertionService class in upstream's
# src/search_provider/search_provider.in. Typing a bare amount converts it with
# the currency pair the app has stored; typing the four-term form
# "100 USD to EUR" stores that pair first and converts with it. A successful
# search answers two result ids — the conversion itself and a "copy to
# clipboard" row the shell renders beneath it — and a failed one answers a
# single id prefixed with ERROR_PREFIX, which the shell shows as the query text.
#
# The rate is fetched once per pair and kept in @currency_data, so re-typing the
# amount only re-multiplies it. The conversions themselves live in
# @dest_currencies keyed by the query string, which is also the result id: the
# shell asks for the metas of an id it was given, and that is where the value
# computed for it is waiting.
#
# Only Gio is required here, not Adwaita: requiring the gtk4 gem calls Gtk.init
# at load time, and this process is started by D-Bus activation, which may have
# no display to initialise against.
#
class ConvertionService
  CLIPBOARD_PREFIX = 'copy-to-clipboard'

  # Upstream's prefix, inherited from the dialect project its search provider
  # was based on, and kept so the ids read the same on the bus.
  ERROR_PREFIX = 'translation-error'

  # The option the app takes the amount on, as upstream's LaunchSearch spawns it.
  OPTION = '--src-currency-value'

  # The amount, the source code, a joining word and the destination code —
  # "100 USD to EUR".
  PAIR_TERMS = 4

  SOURCE_TERM = 1
  DESTINATION_TERM = 3

  BIN = 'valuta'

  PROVIDER_LABEL = 'According to'
  COPY_LABEL = 'Copy'
  COPY_DESCRIPTION = 'Copy convertion to clipboard'

  def initialize(utils = Utils.new)
    @utils = utils
    @currency_data = { 'from_currency_value' => 1, 'to_currency_value' => nil }
    @dest_currencies = {}
    @from_currency = settings.get_string('src-currency')
    @to_currency = settings.get_string('dest-currency')
    @provider = settings.get_enum('providers')

    settings.on_changed('src-currency') { currencies_changed }
    settings.on_changed('dest-currency') { currencies_changed }
  end

  # The shell hands the typed query over as terms. A query that is a number on
  # its own converts with the stored pair; otherwise the four-term form is
  # tried, and anything else matches nothing.
  def get_initial_result_set(terms)
    terms.map(&:to_s).join(' ').then do |value|
      if number?(value)
        results_for(value, value)
      else
        pair_results(value)
      end
    end
  end

  # Narrowing a search re-runs it: the query is what the conversion depends on,
  # so the previous ids say nothing about the new result.
  def get_subsearch_result_set(_previous_results, terms) = get_initial_result_set(terms)

  # The shell asks for the metas of the ids it was handed. Two ids are the
  # conversion and its clipboard row, which is the pair that carries the
  # formatted conversion, the provider line and the text to copy. A single id
  # is answered with whatever was computed for it, and anything else is echoed
  # back so the shell has something to render.
  def get_result_metas(identifiers)
    identifiers.map(&:to_s).then do |ids|
      if convertion_metas?(ids)
        convertion_metas(ids[0], ids[1])
      else
        ids.map { |id| single_meta(id) }
      end
    end
  end

  # Clicking the conversion opens the app on that amount; clicking the
  # clipboard row only copies, which the shell does itself from clipboardText.
  def activate_result(identifier, terms, timestamp)
    unless identifier.to_s.start_with?(CLIPBOARD_PREFIX)
      launch_search(terms, timestamp)
    end
  end

  # Pressing Enter on the provider's section opens the app with the amount
  # pre-filled: the first term of the four-term form, or the whole query.
  def launch_search(terms, _timestamp)
    terms.map(&:to_s).join(' ').then do |value|
      value.split(' ').then do |parts|
        if parts.length == PAIR_TERMS
          spawn_app(parts.first)
        else
          spawn_app(value)
        end
      end
    end
  end

  private

    def settings = @utils.settings

    def number?(text) = @utils.parse_number(text) != false

  # The four-term form. Both codes have to be ones a provider quotes, and the
  # first term has to be an amount, or this is just text the app cannot answer.
    def pair_results(value)
      value.upcase.split(' ').then do |parts|
        if pair?(parts)
          store_pair(parts)
          results_for(parts.first, value)
        else
          []
        end
      end
    end

    def pair?(parts)
      parts.length == PAIR_TERMS &&
        Define::CODES.key?(parts[SOURCE_TERM]) &&
        Define::CODES.key?(parts[DESTINATION_TERM]) &&
        number?(parts.first)
    end

  # Writing the pair notifies the settings' listeners, which is what drops the
  # cached rate — upstream sets the same two keys and relies on the same
  # "changed::" notification.
    def store_pair(parts)
      settings.set_string('src-currency', parts[SOURCE_TERM])
      settings.set_string('dest-currency', parts[DESTINATION_TERM])
    end

  # `amount` is the term the number is parsed from; `key` is the query string
  # the shell will hand back as a result id.
    def results_for(amount, key)
      @currency_data['from_currency_value'] = @utils.parse_number(amount)
      convertion(key).then do |identifier|
        if identifier.nil?
          []
        elsif identifier.start_with?(ERROR_PREFIX)
          [identifier]
        else
          [identifier, CLIPBOARD_PREFIX + key]
        end
      end
    end

  # Converting a currency into itself is not a conversion; upstream answers
  # nothing at all for it, and so does this.
    def convertion(key)
      if @from_currency == @to_currency
        nil
      else
        rate.then do |base|
          if base
            multiply(key, base)
          else
            ERROR_PREFIX + key
          end
        end
      end
    end

  # One rate per pair: it is fetched when there is none cached, or when the
  # provider the app is set to is not the one the cache was filled from.
    def rate
      if @currency_data['to_currency_value'].nil? || @provider != settings.get_enum('providers')
        @currency_data['to_currency_value'] = @utils.convertion.convert_raw(
          1,
          @from_currency,
          @to_currency,
          settings.get_enum('providers'),
        )
      end
      @currency_data['to_currency_value']
    end

    def multiply(key, base)
      (@currency_data['from_currency_value'].to_f * base.to_f).then do |converted|
        @dest_currencies[key] = converted.to_s
        key
      end
    end

    def convertion_metas?(ids)
      ids.length == 2 &&
        @dest_currencies.key?(ids[0]) &&
        ids[1] == CLIPBOARD_PREFIX + ids[0]
    end

  # The conversion and the row that copies it. The cache is emptied once its
  # value has been handed over, as upstream does: the ids the shell still holds
  # belong to a query that has now been answered.
    def convertion_metas(identifier, clipboard_identifier)
      @dest_currencies.fetch(identifier).then do |value|
        [
          {
            'id'          => identifier,
            'name'        => summary(value),
            'description' => "#{PROVIDER_LABEL} #{settings.get_string('providers').upcase}",
          },
          {
            'id'            => clipboard_identifier,
            'name'          => COPY_LABEL,
            'description'   => COPY_DESCRIPTION,
            'clipboardText' => formatted(value),
          },
        ].tap { @dest_currencies.clear }
      end
    end

    def single_meta(identifier)
      {
        'id'   => identifier,
        'name' => @dest_currencies.fetch(identifier, identifier),
      }
    end

    def summary(value)
      [
        formatted(@currency_data['from_currency_value']),
        @from_currency,
        '=',
        formatted(value),
        @to_currency,
      ].join(' ')
    end

  # Utils#format_number answers false for an amount it cannot format, which the
  # shell has no use for, so that becomes the empty string here.
    def formatted(value) = @utils.format_number(value.to_s).to_s

    def spawn_app(value)
      Process.detach(Process.spawn(bin, OPTION, value.to_s))
    end

  # The app's executable: the one shipped beside this file, whether that is a
  # checkout or an installed gem, and otherwise whatever the PATH resolves
  # `valuta` to. Upstream spawns the installed binary the same way.
    def bin
      File.expand_path("../exe/#{BIN}", __dir__).then do |packaged|
        if File.executable?(packaged)
          packaged
        else
          BIN
        end
      end
    end

    def currencies_changed
      @from_currency = settings.get_string('src-currency')
      @to_currency = settings.get_string('dest-currency')
      @currency_data['to_currency_value'] = nil
    end
end

# ShellSearchProvider is the service process the shell talks to.
#
# Ported from the ConvertionServiceApplication class in upstream's
# src/search_provider/search_provider.in: a Gio.Application registered as a
# service under the app id with a ".SearchProvider" suffix, exporting
# org.gnome.Shell.SearchProvider2 on the object path the application's own id
# gives it, and quitting ten seconds after the last call.
#
# Upstream overrides do_dbus_register to export the interface. Ruby cannot
# override a GObject virtual function without registering a new GType, and
# there is no "dbus-register" signal to connect to either, so the object is
# exported from "startup" instead, where the application's connection and
# object path are both available and are the ones do_dbus_register would have
# been handed.
#
class ShellSearchProvider
  INTERFACE = 'org.gnome.Shell.SearchProvider2'
  INACTIVITY_TIMEOUT = 10_000

  NODE_XML = <<~XML
    <node>
      <interface name="org.gnome.Shell.SearchProvider2">
        <method name="GetInitialResultSet">
          <arg type="as" name="terms" direction="in"/>
          <arg type="as" name="results" direction="out"/>
        </method>
        <method name="GetSubsearchResultSet">
          <arg type="as" name="previous_results" direction="in"/>
          <arg type="as" name="terms" direction="in"/>
          <arg type="as" name="results" direction="out"/>
        </method>
        <method name="GetResultMetas">
          <arg type="as" name="identifiers" direction="in"/>
          <arg type="aa{sv}" name="metas" direction="out"/>
        </method>
        <method name="ActivateResult">
          <arg type="s" name="identifier" direction="in"/>
          <arg type="as" name="terms" direction="in"/>
          <arg type="u" name="timestamp" direction="in"/>
        </method>
        <method name="LaunchSearch">
          <arg type="as" name="terms" direction="in"/>
          <arg type="u" name="timestamp" direction="in"/>
        </method>
      </interface>
    </node>
  XML

  def initialize(app_id: "#{Define::APP_ID}.SearchProvider", service: nil)
    @app_id = app_id
    @service = service || ConvertionService.new
  end

  def build
    app.tap do |a|
      a.signal_connect('startup') { register(a.dbus_connection, a.dbus_object_path) }
    end
  end

  def run(argv = []) = app.run(argv)

  def app
    @app ||= Gio::Application.new(@app_id, :is_service).tap do |a|
      a.inactivity_timeout = INACTIVITY_TIMEOUT
    end
  end

  # Note lookup_interface rather than interfaces.first: Gio::DBusNodeInfo
  # #interfaces answers unusable strings in these bindings, while
  # #lookup_interface answers the Gio::DBusInterfaceInfo wanted here.
  def interface_info = Gio::DBusNodeInfo.new(NODE_XML).lookup_interface(INTERFACE)

  # Upstream gives up and quits when the export fails; there is nothing for the
  # process to do if the shell cannot reach it.
  def register(connection, object_path)
    connection.register_object(object_path, interface_info, method(:on_dbus_method_call))
  rescue StandardError, GLib::Error => e
    warn "Could not register the search provider: #{e.message}"
    app.quit
    nil
  end

  private

  # Upstream holds the application for the duration of a call and releases it
  # once the reply is sent, so the ten-second inactivity timeout only starts
  # running when the shell has stopped asking.
    def on_dbus_method_call(_connection, _sender, _path, _interface, method_name, parameters, invocation)
      app.hold
      dispatch(method_name, parameters, invocation)
      app.release
    rescue StandardError, GLib::Error => e
      invocation.return_dbus_error("#{INTERFACE}.Error", e.message)
      app.release
    end

    def dispatch(method_name, parameters, invocation)
      case method_name
      when 'GetInitialResultSet'
        invocation.return_value(
          string_array(@service.get_initial_result_set(terms(parameters, 0))),
        )
      when 'GetSubsearchResultSet'
        invocation.return_value(
          string_array(
            @service.get_subsearch_result_set(terms(parameters, 0), terms(parameters, 1)),
          ),
        )
      when 'GetResultMetas'
        invocation.return_value(metas_variant(@service.get_result_metas(terms(parameters, 0))))
      when 'ActivateResult'
        @service.activate_result(
          identifier(parameters, 0),
          terms(parameters, 1),
          timestamp(parameters, 2),
        )
        invocation.return_value(nil)
      when 'LaunchSearch'
        @service.launch_search(terms(parameters, 0), timestamp(parameters, 1))
        invocation.return_value(nil)
      else
        invocation.return_dbus_error("#{INTERFACE}.UnknownMethod", "Unknown method #{method_name}")
      end
    end

  # The call's arguments arrive already unpacked: these bindings hand the
  # method-call closure a Ruby Array of plain values, one per "in" argument,
  # the way upstream's parameters.unpack() leaves them.
    def terms(parameters, index) = Array(parameters[index]).map(&:to_s)

    def identifier(parameters, index) = parameters[index].to_s

    def timestamp(parameters, index) = parameters[index].to_i

  # Reply variants are built by parsing GVariant text.
  #
  # GLib::Variant.new cannot construct a dictionary in these bindings — it
  # raises NotImplementedError for a{sv} — and it cannot build the tuple a
  # D-Bus reply needs either. GLib::Variant.parse handles both.
    def string_array(values)
      GLib::Variant.parse("([#{values.map { |value| quote(value) }.join(', ')}],)", '(as)')
    end

    def metas_variant(metas)
      GLib::Variant.parse("([#{metas.map { |meta| meta_text(meta) }.join(', ')}],)", '(aa{sv})')
    end

    def meta_text(meta)
      "{#{meta.map { |key, value| "#{quote(key)}: <#{quote(value)}>" }.join(', ')}}"
    end

  # GVariant text format uses the same string escapes as C. The block form of
  # gsub is deliberate: backslashes in a replacement string are themselves
  # interpreted, which makes the escaping of an escape character unreadable.
    ESCAPES = { '\\' => '\\\\', '"' => '\\"' }.freeze

    def quote(value) = %("#{value.to_s.gsub(/[\\"]/) { |char| ESCAPES.fetch(char) }}")
end
