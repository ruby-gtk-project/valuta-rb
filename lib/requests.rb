# frozen_string_literal: true

require 'json'
require 'soup3'
require 'time'

require_relative 'define'

# Requests is the network layer: it asks a provider for a rate and hands back
# the provider's serialized response.
#
# Ported from upstream's src/requests.py. Upstream talks to the one provider
# it ships, the European Central Bank's rates as republished by
# api.frankfurter.app, over libsoup, via `Soup.Session`/`Soup.Message`; this
# port uses the `soup3` gem's own `Soup::Session`/`Soup::Message`, which are
# the same libsoup 3 types read off its typelib. The response shape, the URL
# and the error contract are upstream's: #get answers the response Hash on
# success and the error message String on failure, which is exactly the
# String-or-Hash the conversion cache branches on.
#
class Requests
  HEADERS = {
    'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/117.0',
  }.freeze

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

  # SoupSession is upstream's own class of the same name: it builds the
  # `Soup::Message` with the headers the provider expects and reads the body
  # through `Soup::Session#send_and_read`. libsoup follows redirects itself,
  # so there is no hop-following to replicate here.
  class SoupSession
    def initialize
      @session = Soup::Session.new
    end

    def create_request(method, url, headers = {})
      Soup::Message.new(method, url).tap do |message|
        HEADERS.merge(headers).each do |name, value|
          message.request_headers.append(name, value)
        end
      end
    end

    def get_response(message)
      @session.send_and_read(message, nil).to_s.then do |body|
        unless message.status_code.between?(200, 299)
          raise IOError, "#{message.status_code} #{message.reason_phrase}"
        end

        body
      end
    end
  end

  def initialize(provider, from_currency, to_currency, from_currency_value)
    @provider = PROVIDERS.fetch(provider.to_i).new(from_currency, to_currency, from_currency_value)
    @url = @provider.mount_url
  end

  # Answers the serialized response, or the error's message — the String that
  # tells the caller the conversion did not happen.
  def get
    SoupSession.new.then do |session|
      @provider.serializer(session.get_response(session.create_request('GET', @url, HEADERS)))
    end
  rescue StandardError => error
    error.message
  end
end
