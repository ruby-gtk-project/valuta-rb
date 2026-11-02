# frozen_string_literal: true

require 'json'
require 'net/http'
require 'time'
require 'uri'

require_relative 'define'

# Requests is the network layer: it asks a provider for a rate and hands back
# the provider's serialized response.
#
# Ported from upstream's src/requests.py. Upstream talks to the one provider it
# ships, the European Central Bank's rates as republished by
# api.frankfurter.app, over libsoup; this port uses net/http, since the soup3
# bindings are not part of the ruby-gnome stack the fork builds against. The
# response shape, the URL and the error contract are upstream's: #get answers
# the response Hash on success and the error message String on failure, which
# is exactly the String-or-Hash the conversion cache branches on.
#
class Requests
  HEADERS = {
    'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/117.0',
  }.freeze

  MAX_REDIRECTS = 5
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 15

  # Providers is upstream's abstract provider: it holds the pair being
  # converted and knows how to turn a provider's date into the "January 1,
  # 2024" string the window's status line shows.
  class Providers
    ECB_BASE_URL = 'https://api.frankfurter.app/latest'

    INFO_FORMAT = '%B %e, %Y'

    attr_reader :from_currency, :to_currency, :from_currency_value

    def initialize(from_currency, to_currency, from_currency_value)
      @from_currency = from_currency
      @to_currency = to_currency
      @from_currency_value = from_currency_value
    end

    def response
      @response ||= {
        'from'       => '',
        'to'         => '',
        'amount'     => '',
        'converted'  => false,
        'info'       => '',
        'disclaimer' => '',
        'provider'   => '',
      }
    end

    # Upstream builds a GLib.DateTime in the local zone and formats it; the
    # ruby-gnome GLib::DateTime has no new_local, so this builds the same local
    # time with Time and formats it with the same strftime pattern.
    def create_info(date, time = '00:00:00')
      date.to_s.split('-').map(&:to_i).then do |year, month, day|
        time.to_s.split(':').map(&:to_i).then do |hour, minute, second|
          Time.local(
            year,
            month,
            day,
            hour,
            minute,
            second,
          ).strftime(INFO_FORMAT)
        end
      end
    end
  end

  # ECB quotes through api.frankfurter.app, which answers
  # {"amount":…,"base":…,"date":"YYYY-MM-DD","rates":{"EUR":0.9}}.
  class ECB < Providers
    INDEX = 0

    def mount_url
      "#{ECB_BASE_URL}?amount=#{from_currency_value}&from=#{from_currency}&to=#{to_currency}"
    end

    def serializer(data) = default_response(JSON.parse(data))

    def default_response(data)
      response.tap do |serialized|
        serialized['base'] = data.fetch('rates').fetch(to_currency)
        serialized['from'] = from_currency
        serialized['to'] = to_currency
        serialized['amount'] = 0
        serialized['info'] = create_info(data.fetch('date'))
        serialized['disclaimer'] = mount_url
        serialized['provider'] = INDEX
      end
    end
  end

  PROVIDERS = { 0 => ECB }.freeze

  # Session is upstream's SoupSession stand-in: it builds the request with the
  # headers the provider expects and reads the body.
  class Session
    def create_request(method, url, headers = {})
      Net::HTTP.const_get(method.to_s.capitalize).new(URI(url)).tap do |request|
        HEADERS.merge(headers).each { |name, value| request[name] = value }
      end
    end

    def get_response(url, request) = fetch(url, request, MAX_REDIRECTS)

    private

    # Soup.Session follows redirects on its own, and the provider's host does
    # redirect, so the same hop-following belongs here.
      def fetch(url, request, remaining)
        send_request(url, request).then do |response|
          if response.is_a?(Net::HTTPRedirection) && remaining.positive?
            response['location'].then do |location|
              fetch(location, create_request('GET', location), remaining - 1)
            end
          else
            body_of(response)
          end
        end
      end

      def send_request(url, request)
        URI(url).then do |uri|
          Net::HTTP.start(
            uri.host,
            uri.port,
            use_ssl:      uri.scheme == 'https',
            open_timeout: OPEN_TIMEOUT,
            read_timeout: READ_TIMEOUT,
          ) { |http| http.request(request) }
        end
      end

      def body_of(response)
        response.is_a?(Net::HTTPSuccess).then do |ok|
          unless ok
            raise IOError, "#{response.code} #{response.message}"
          end
        end
        response.body
      end
  end

  def initialize(provider, from_currency, to_currency, from_currency_value)
    @provider = PROVIDERS.fetch(provider.to_i).new(from_currency, to_currency, from_currency_value)
    @url = @provider.mount_url
  end

  # Answers the serialized response, or the error's message — the String that
  # tells the caller the conversion did not happen.
  def get
    Session.new.then do |session|
      @provider.serializer(session.get_response(@url, session.create_request('GET', @url)))
    end
  rescue StandardError => error
    error.message
  end
end
