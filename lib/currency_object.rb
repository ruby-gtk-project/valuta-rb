# frozen_string_literal: true

# CurrencyObject is one row's worth of currency: its ISO code, its translated
# name, and whether it is the selection.
#
# Ported from the CurrencyObject class in upstream's src/utils.py, a
# GObject.Object with code/name/selected properties. Upstream needs it to be a
# GObject so the row can bind_property its `selected` to an image's
# `visible`; this port notifies listeners instead, which the row uses to the
# same effect and which keeps the object usable without a GType registration.
#
class CurrencyObject
  attr_reader :code, :name, :selected

  def initialize(code, name, selected: false)
    @code = code
    @name = name
    @selected = selected
    @listeners = []
  end

  def selected=(value)
    (@selected == value).then do |unchanged|
      unless unchanged
        @selected = value
        @listeners.each { |listener| listener.call(value) }
      end
    end
    value
  end

  # Mirrors GObject.BindingFlags.SYNC_CREATE: the listener is called straight
  # away with the current value, then on every change.
  def on_selected_changed(&listener)
    @listeners << listener
    listener.call(@selected)
    listener
  end

  # Upstream's __str__, which its row and filter both lean on to get the code.
  def to_s = @code
end
