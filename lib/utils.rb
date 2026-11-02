# frozen_string_literal: true

require 'adwaita'

require_relative 'define'
require_relative 'settings'
require_relative 'convertion'

# Utils is the application's shared service bag.
#
# Ported from the Utils class in upstream's src/utils.py: it owns the settings,
# the conversion cache, the resolved locale, the currency table and the
# provider names, and formats and parses numbers for the locale.
#
# Upstream delegates the number work to Babel (format_number / parse_decimal),
# which ships CLDR. Ruby has no CLDR in the standard library, so the separators
# for the languages upstream is translated into are tabulated here and the
# grouping follows Babel's default decimal pattern, "#,##0.###": groups of
# three digits and at most three fraction digits, trailing zeros dropped.
#
class Utils
  FRACTION_DIGITS = 3
  GROUP_SIZE = 3

  # [group separator, decimal separator] per language. The default is the
  # "en" convention, which is also what Babel falls back to for the C locale.
  DEFAULT_SEPARATORS = [',', '.'].freeze
  NARROW_NO_BREAK_SPACE = "\u202F"

  SEPARATORS = {
    'ar' => [',', '.'],
    'be' => [NARROW_NO_BREAK_SPACE, ','],
    'bg' => [NARROW_NO_BREAK_SPACE, ','],
    'cs' => [NARROW_NO_BREAK_SPACE, ','],
    'de' => ['.', ','],
    'en' => [',', '.'],
    'es' => ['.', ','],
    'et' => [NARROW_NO_BREAK_SPACE, ','],
    'eu' => ['.', ','],
    'fi' => [NARROW_NO_BREAK_SPACE, ','],
    'fr' => [NARROW_NO_BREAK_SPACE, ','],
    'he' => [',', '.'],
    'hi' => [',', '.'],
    'hr' => ['.', ','],
    'ia' => ['.', ','],
    'it' => ['.', ','],
    'ja' => [',', '.'],
    'ka' => [NARROW_NO_BREAK_SPACE, ','],
    'kk' => [NARROW_NO_BREAK_SPACE, ','],
    'ko' => [',', '.'],
    'kw' => [',', '.'],
    'nb' => [NARROW_NO_BREAK_SPACE, ','],
    'nl' => ['.', ','],
    'pl' => [NARROW_NO_BREAK_SPACE, ','],
    'pt' => ['.', ','],
    'ro' => ['.', ','],
    'ru' => [NARROW_NO_BREAK_SPACE, ','],
    'sv' => [NARROW_NO_BREAK_SPACE, ','],
    'ta' => [',', '.'],
    'te' => [',', '.'],
    'tr' => ['.', ','],
    'uk' => [NARROW_NO_BREAK_SPACE, ','],
    'zh' => [',', '.'],
  }.freeze

  PROVIDERS = { '0' => 'ECB' }.freeze

  SIGNS = { true => '-', false => '' }.freeze
  SPACES = /[[:space:]\u00A0\u202F\u2009]/

  attr_reader :settings, :convertion, :locale, :currencies, :providers

  def initialize(_application_id = Define::APP_ID, settings: nil)
    @settings = settings || Settings.new
    @convertion = Convertion.new(@settings)
    @locale = GLib.language_names
    @currencies = Define::CODES
    @providers = PROVIDERS
  end

  # The language the separators are chosen by: the first entry of the locale
  # list, stripped of its territory and codeset, as Babel's locale negotiation
  # ends up doing for upstream.
  def language = @locale.first.to_s.split(/[_.@]/).first.to_s

  def separators = SEPARATORS.fetch(language, DEFAULT_SEPARATORS)

  # Formats a number for the locale, or answers false when there is nothing to
  # format — the false is what upstream's callers branch on.
  def format_number(number)
    numeric(number).then do |value|
      if value
        group(value)
      else
        false
      end
    end
  end

  # Parses a locale-formatted number back to a Float, or false when the text is
  # not a number. Upstream's callers use the false to flag the entry red.
  #
  # Zero parses to false, matching upstream: Babel's parse_decimal returns a
  # Decimal, and `if not value` treats a zero Decimal as no value at all, so
  # upstream flags a lone "0" as unconvertible too.
  def parse_number(number)
    canonical(number).then do |text|
      if text
        numeric(text)
      else
        false
      end
    end
  end

  private

  # Accepts what upstream's callers pass: a number, or the string form of one.
  # Zero and nil are both falsey for upstream's `if number` check, so a zero
  # amount formats as false here too.
    def numeric(number)
      Float(number.to_s.strip, exception: false).then do |value|
        if value && !value.zero?
          value
        else
          false
        end
      end
    end

  # Babel's "#,##0.###": groups of three, at most three fraction digits, and
  # no trailing zeros in the fraction.
    def group(value)
      group_separator, decimal_separator = separators
      sign, whole, fraction = split(value)

      whole
        .reverse
        .scan(/\d{1,#{GROUP_SIZE}}/)
        .join(group_separator)
        .reverse
        .then do |grouped|
          if fraction.empty?
            "#{sign}#{grouped}"
          else
            "#{sign}#{grouped}#{decimal_separator}#{fraction}"
          end
        end
    end

    def split(value)
      format("%.#{FRACTION_DIGITS}f", value.abs).split('.').then do |whole, fraction|
        [SIGNS[value.negative?], whole, fraction.to_s.sub(/0+\z/, '')]
      end
    end

  # Strips the locale's group separators — and every other kind of space a
  # CLDR group separator can be — then normalises the decimal separator, so
  # Float() sees a plain machine-readable number.
    def canonical(number)
      group_separator, decimal_separator = separators
      number.to_s.strip.then do |text|
        if text.empty?
          false
        else
          text
            .delete(group_separator)
            .gsub(SPACES, '')
            .tr(decimal_separator, '.')
        end
      end
    end
end
