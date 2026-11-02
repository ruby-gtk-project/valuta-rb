# frozen_string_literal: true

require_relative 'requests'

# Convertion is the conversion cache and the event bus the pages listen on.
#
# Ported from the Convertion class in upstream's src/utils.py. One rate is
# fetched per currency pair and kept; while the pair and the provider stay the
# same, changing the amount only multiplies the cached rate, so typing in the
# entry does not hit the network on every keystroke. Every outcome — a fresh
# rate, a cached re-multiplication, or a failure — emits "converted" with the
# current data, and the window and the page both listen for it.
#
class Convertion
  EVENTS = %w[converted].freeze

  attr_reader :converted_data

  def initialize(settings)
    @settings = settings
    @converted_data = {
      'base'       => 1,
      'from'       => '',
      'to'         => '',
      'amount'     => 1,
      'info'       => '',
      'disclaimer' => '',
      'provider'   => settings.get_enum('providers'),
      'converted'  => false,
    }
    @events = EVENTS.to_h { |name| [name, []] }
  end

  # Converting a currency into itself is not a conversion; upstream drops the
  # cache's converted flag and emits nothing, which leaves the page's stack
  # wherever it was.
  def convert(from_currency_value, from_currency, to_currency, provider)
    if from_currency == to_currency
      @converted_data['converted'] = false
    elsif stale?(from_currency, to_currency, provider)
      fetch(
        from_currency_value,
        from_currency,
        to_currency,
        provider,
      )
    else
      remultiply(from_currency_value)
    end
  end

  # The rate on its own, with no caching and no event — what the shell search
  # provider converts one-off queries with.
  def convert_raw(from_currency_value, from_currency, to_currency, provider)
    if from_currency == to_currency
      @converted_data['converted'] = false
    else
      Requests.new(
        provider,
        from_currency,
        to_currency,
        from_currency_value,
      ).get.then do |response|
        if response.is_a?(String)
          @converted_data['converted'] = false
        else
          response['base']
        end
      end
    end
  end

  # True when the cache holds this pair from this provider.
  def match_data(from_currency, to_currency, provider)
    @converted_data['from'] == from_currency &&
      @converted_data['to'] == to_currency &&
      @converted_data['provider'] == provider
  end

  def get_convertion = @converted_data

  def connect(event, callback = nil, &block)
    (callback || block).then do |listener|
      @events.fetch(event.to_s) << listener
      listener
    end
  end

  private

    def stale?(from_currency, to_currency, provider)
      !match_data(from_currency, to_currency, provider) || !@converted_data['converted']
    end

  # A fresh rate. The amount the provider echoes back is replaced by the
  # amount the user asked for, multiplied by the rate.
    def fetch(from_currency_value, from_currency, to_currency, provider)
      Requests.new(
        provider,
        from_currency,
        to_currency,
        1,
      ).get.then do |response|
        if response.is_a?(String)
          failed
        else
          @converted_data = response.merge(
            'converted' => true,
            'amount'    => from_currency_value * response['base'],
          )
          event('converted', @converted_data)
          @converted_data
        end
      end
    rescue StandardError
      @converted_data = @converted_data.merge('converted' => false, 'amount' => 0)
      event('converted', @converted_data)
      @converted_data
    end

    def remultiply(from_currency_value)
      @converted_data = @converted_data.merge(
        'amount' => from_currency_value * @converted_data['base'],
      )
      event('converted', @converted_data)
      @converted_data
    end

    def failed
      @converted_data['converted'] = false
      event('converted', @converted_data)
    end

    def event(name, data)
      @events.fetch(name).each { |listener| listener.call(data) }
    end
end
