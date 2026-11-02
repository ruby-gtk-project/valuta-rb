# frozen_string_literal: true

require_relative 'currency_object'

# CurrenciesListModel is the list of currencies a selector offers.
#
# Ported from the CurrenciesListModel class in upstream's src/utils.py, a
# Gio.ListModel of CurrencyObjects built from the currency codes a provider
# quotes, with the name of each looked up through the names_func the page
# supplies. Upstream wraps it in a Gtk.SortListModel and a Gtk.FilterListModel
# and hands it to ListBox.bind_model; implementing Gio.ListModel from Ruby
# needs a GType registration the bindings do not offer, so this model sorts and
# filters the same way itself and notifies its listeners when its contents
# change — which is what the selector rebuilds its rows from.
#
class CurrenciesListModel
  include Enumerable

  attr_reader :currencies, :names_func

  def initialize(names_func)
    @names_func = names_func
    @currencies = []
    @listeners = []
  end

  def each(&) = @currencies.each(&)

  def item(position) = @currencies[position]

  def item_type = CurrencyObject

  def n_items = @currencies.length

  # Replaces the contents, exactly as upstream's set_currencies does: one
  # CurrencyObject per code, in the order the codes arrive, then one
  # items-changed for the whole list.
  def set_currencies(currencies)
    removed = @currencies.length
    @currencies = currencies.map { |code| CurrencyObject.new(code, @names_func.call(code)) }
    items_changed(0, removed, @currencies.length)
    @currencies
  end

  def set_selected(code)
    @currencies.each { |item| item.selected = item.code == code }
  end

  # Upstream's Gtk.CustomSorter: by translated name, case-insensitively.
  def sorted = @currencies.sort_by { |item| item.name.to_s.downcase }

  # Upstream's Gtk.CustomFilter: the search text matched case-insensitively
  # against "CODE - Name", as a regular expression, falling back to a literal
  # match while the user is midway through typing something like "(".
  def filtered(search)
    sorted.select { |item| matcher(search).match?("#{item} - #{item.name}") }
  end

  def on_items_changed(&listener)
    @listeners << listener
    listener
  end

  private

    def items_changed(position, removed, added)
      @listeners.each { |listener| listener.call(position, removed, added) }
    end

    def matcher(search)
      Regexp.new(search.to_s, Regexp::IGNORECASE)
    rescue RegexpError
      Regexp.new(Regexp.escape(search.to_s), Regexp::IGNORECASE)
    end
end
