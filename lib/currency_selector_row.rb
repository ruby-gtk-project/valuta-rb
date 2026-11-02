# frozen_string_literal: true

require 'adwaita'

require_relative 'currency_object'

# CurrencySelectorRow is one currency in a selector's popover list.
#
# Ported from upstream's src/components/currency_selector_row/
# currency_selector_row.py and index.blp: a row holding the code and the
# shortened name, plus a check mark that is visible only while this row is the
# selection. Upstream keeps the check mark in sync with a GObject property
# binding; this port listens on the currency object instead, with the same
# sync-on-create behaviour.
#
class CurrencySelectorRow < Gtk::ListBoxRow
  # upstream: textwrap.shorten(name, width=30, placeholder="...")
  NAME_WIDTH = 30
  PLACEHOLDER = '...'
  SEPARATOR = '–'

  attr_reader :currency

  def initialize(currency)
    super()
    @currency = currency
  end

  def build
    tap do |row|
      row.child = box

      box.tap do |b|
        b.append(name)
        b.append(selection)

        @currency.on_selected_changed { |selected| selection.visible = selected }
      end
    end
  end

  def box = @box ||= Gtk::Box.new(:horizontal, 6)

  def name
    @name ||= Gtk::Label.new(label_text).tap do |label|
      label.xalign = 0
    end
  end

  def selection
    @selection ||= Gtk::Image.new(icon_name: 'object-select-symbolic').tap do |image|
      image.visible = false
    end
  end

  private

    def label_text = "#{@currency} #{SEPARATOR} #{shortened(@currency.name)}"

  # textwrap.shorten in Ruby: collapse the whitespace, and when the result is
  # too long keep the longest run of whole words that leaves room for the
  # placeholder.
    def shortened(text)
      text.to_s.split.join(' ').then do |collapsed|
        if collapsed.length <= NAME_WIDTH
          collapsed
        else
          "#{truncated(collapsed)}#{PLACEHOLDER}"
        end
      end
    end

    def truncated(collapsed)
      budget = NAME_WIDTH - PLACEHOLDER.length
      collapsed.split.inject('') do |kept, word|
        [kept, word].reject(&:empty?).join(' ').then do |candidate|
          if candidate.length <= budget
            candidate
          else
            kept
          end
        end
      end.then do |kept|
        if kept.empty?
          collapsed[0, budget]
        else
          kept
        end
      end
    end
end
