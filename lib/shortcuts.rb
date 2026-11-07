# frozen_string_literal: true

require 'adwaita'

require_relative 'i18n'

# Shortcuts is the keyboard shortcuts window, opened by win.show-help-overlay.
#
# Ported from upstream's src/components/shortcuts/shortcuts.py and
# shortcuts.blp: one "General" group listing the three shortcuts the
# application binds, each named by its action so the accelerators shown are the
# ones actually in force.
#
# Upstream subclasses Gtk.ShortcutsWindow and installs it with
# Gtk.Window.set_help_overlay. Gtk::ShortcutsWindow cannot be constructed from
# these Ruby bindings — `Gtk::ShortcutsWindow.new` raises "GtkWindow is not
# subtype of GtkShortcutsWindow" — so this port uses Adwaita::ShortcutsDialog,
# libadwaita's replacement for it, and the window registers the
# show-help-overlay action itself rather than relying on the help-overlay
# machinery.
#
class Shortcuts < Adwaita::ShortcutsDialog
  extend I18n
  include I18n

  # Upstream's msgctxt, "shortcuts window", is written as a literal at every
  # call site below rather than through a constant: the gettext gem's Ruby
  # extractor (`rxgettext`) can only read a marker whose arguments are literals.
  GROUP_TITLE = p_('shortcuts window', 'General')

  ITEMS = {
    p_('shortcuts window', 'Keyboard shortcuts') => 'win.show-help-overlay',
    p_('shortcuts window', 'Switch currencies')  => 'app.switch-currencies',
    p_('shortcuts window', 'Quit')                => 'app.quit',
  }.freeze

  def initialize
    super()
    self.title = 'Keyboard Shortcuts'
  end

  def build
    tap do |dialog|
      dialog.add(section)

      section.tap do |sec|
        ITEMS.each { |title, action| sec.add(item(title, action)) }
      end
    end
  end

  def section
    @section ||= Adwaita::ShortcutsSection.new.tap do |sec|
      sec.title = GROUP_TITLE
    end
  end

  private

  # Positional, not keyword, arguments — even though the error a no-argument
  # new raises advertises the signatures as "title: utf8, accelerator: utf8".
  # The accelerator is left empty because action_name makes libadwaita look up
  # the accelerator the application actually bound, which is what upstream's
  # action-name-only ShortcutsShortcut does.
    def item(title, action)
      Adwaita::ShortcutsItem.new(title, '').tap do |shortcut|
        shortcut.action_name = action
      end
    end
end
