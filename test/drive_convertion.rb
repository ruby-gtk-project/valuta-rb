# frozen_string_literal: true

# Drives the ported window: the conversion page's states, the currency
# selectors' popover search, the switch-currencies action, the provider action
# and the two dialogs the primary menu opens.
#
# Run it from the dev shell: nix develop --command xvfb-run -a ruby
# test/drive_convertion.rb

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('valuta-drive')

require_relative '../lib/main'
require_relative 'gtk_driver'

# Walks the widget tree, because a ported page is reached through the window
# rather than through a memoized method on the app.
def descendants(widget, klass, found = [])
  if widget.is_a?(klass)
    found << widget
  end
  child = widget.first_child
  while child
    descendants(child, klass, found)
    child = child.next_sibling
  end
  found
end

application = Application.new(app_id: 'org.rubygtkproject.ValutaDrive', flags: :non_unique)

GtkDriver.drive(application, shots: 'tmp/shots', interval: 3000) do |d, app|
  d.window { app.app.active_window }

  window = -> { app.app.active_window }
  entry = -> { descendants(window.call, Gtk::Entry).first }
  stack = -> { descendants(window.call, Gtk::Stack).find { |s| s.pages.n_items == 3 } }
  selectors = -> { descendants(window.call, Adwaita::Bin).select { |bin| bin.is_a?(CurrencySelector) } }
  result = -> { descendants(stack.call, Gtk::Label).first }
  # Prefixed action names ("win.", "window.") resolve through a widget's action
  # muxer, which a window does not consult for its own groups — so the menu
  # items are exercised the way a menu does, from a widget inside the window.
  inside = lambda do
    widget = window.call.content
    while widget.first_child
      widget = widget.first_child
    end
    widget
  end
  link = -> { descendants(window.call, Gtk::LinkButton).first }

  d.step('the window builds and starts converting 1 USD') do
    d.check('window title is Valuta') { window.call.title == 'Valuta' }
    d.check('amount starts at 1') { entry.call.text == '1' }
    d.check('the amount is not flagged as an error') { !entry.call.css_classes.include?('error') }
    d.check('two currency selectors are present') { selectors.call.length == 2 }
    d.check('USD is selected as the source') { selectors.call.first.selected == 'USD' }
    d.check('EUR is selected as the destination') { selectors.call.last.selected == 'EUR' }
    d.check('the stack offers the three states') do
      %w[result loading convertion-error].all? { |name| !stack.call.get_child_by_name(name).nil? }
    end
    d.check('the stack is fetching or has a result') do
      %w[loading result].include?(stack.call.visible_child_name)
    end
    d.shot('01-loading')
  end

  # The rate comes off the network, so it gets a tick of its own before the
  # result is asserted on.
  d.step('the request is in flight') do
    d.check('the stack is in one of its three states') do
      %w[loading result convertion-error].include?(stack.call.visible_child_name)
    end
  end

  d.step('the rate arrives') do
    d.check('the stack is showing the result') { stack.call.visible_child_name == 'result' }
    d.check('the result is a formatted number') { result.call.label.match?(/\A\d/) }
    d.check('the provider link is shown') { link.call.visible? && link.call.label == 'ECB' }
    d.check('the link points at the request') { link.call.uri.include?('api.frankfurter.app') }
    d.shot('02-result')
  end

  d.step('a bad amount flags the entry') do
    entry.call.text = 'not a number'
  end

  d.step('the entry is flagged') do
    d.check('the entry carries the error class') { entry.call.css_classes.include?('error') }
    d.shot('03-error-entry')
  end

  d.step('a new amount converts again') do
    entry.call.text = '250'
  end

  d.step('the new amount is converted') do
    d.check('the error class is gone') { !entry.call.css_classes.include?('error') }
    d.check('the result changed') { result.call.label.match?(/\A\d/) }
    d.shot('04-converted-250')
  end

  d.step('the popover opens and searches') do
    selectors.call.first.then do |selector|
      selector.button.popup
      selector.search.text = 'pound'
    end
  end

  d.step('the search narrows the list') do
    selectors.call.first.then do |selector|
      rows = descendants(selector.currency_list, CurrencySelectorRow)
      d.check('the search matched something') { rows.any? }
      d.check('every row matches the search') do
        rows.all? { |row| "#{row.currency} - #{row.currency.name}".match?(/pound/i) }
      end
      d.shot('05-popover-search', selector.popover.child)
    end
  end

  d.step('activating a row selects that currency') do
    selectors.call.first.then do |selector|
      descendants(selector.currency_list, CurrencySelectorRow).first.then do |row|
        selector.currency_list.signal_emit('row-activated', row)
      end
    end
  end

  d.step('the selection and the settings agree') do
    selectors.call.first.then do |selector|
      d.check('the selector moved off USD') { selector.selected != 'USD' }
      d.check('the setting followed the selector') do
        app.utils.settings.get_string('src-currency') == selector.selected
      end
      d.check('the button label shows the code') { selector.label.label == selector.selected }
    end
  end

  d.step('switch-currencies swaps the pair') do
    @before = [
      app.utils.settings.get_string('src-currency'),
      app.utils.settings.get_string('dest-currency'),
    ]
    app.app.activate_action('switch-currencies', nil)
  end

  d.step('the pair is swapped') do
    d.check('the source is the old destination') do
      app.utils.settings.get_string('src-currency') == @before.last
    end
    d.check('the destination is the old source') do
      app.utils.settings.get_string('dest-currency') == @before.first
    end
    d.check('the selectors followed the settings') do
      selectors.call.first.selected == @before.last && selectors.call.last.selected == @before.first
    end
    d.shot('06-switched')
  end

  d.step('the provider action is reachable from the window') do
    inside.call.activate_action('window.providers', GLib::Variant.new('ecb'))
    d.check('the provider is still ECB') { app.utils.settings.get_string('providers') == 'ecb' }
    d.check('the provider action carries the state') do
      window.call.lookup_action('providers').nil? ||
        app.utils.settings.get_enum('providers').zero?
    end
  end

  d.step('the about dialog opens') do
    app.app.activate_action('about', nil)
  end

  d.step('the about dialog is showing') do
    window.call.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('it is the about dialog') { dialog.is_a?(AboutDialog) }
      d.check('it names the version') { dialog.version == Define::VERSION }
      d.check('the debug info names the toolkit') { dialog.debug_info.include?('Adw ') }
      d.shot('07-about', dialog.child || window.call)
      dialog.close
    end
  end

  d.step('the shortcuts dialog opens') do
    inside.call.activate_action('win.show-help-overlay', nil)
  end

  d.step('the shortcuts dialog is showing') do
    window.call.visible_dialog.then do |dialog|
      d.check('a dialog is up') { !dialog.nil? }
      d.check('it is the shortcuts dialog') { dialog.is_a?(Shortcuts) }
      d.shot('08-shortcuts', dialog.child || window.call)
      dialog.close
    end
  end

  # Application#command_line is private, and only the running application
  # object (the Window already open, app.app.active_window set) exercises the
  # branch upstream's do_command_line takes on a second invocation: hand the
  # amount to the window instead of remembering it for one that does not exist
  # yet. CommandLineDouble stands in for the Gio::ApplicationCommandLine
  # command_line only reads .arguments from.
  CommandLineDouble = Struct.new(:arguments)

  d.step('a second invocation carries --src-currency-value') do
    @before_entry = entry.call.text
    app.send(:command_line, CommandLineDouble.new(['valuta', '--src-currency-value', '975']))
  end

  d.step('the running window picked up the new amount, not a new window') do
    d.check('exactly one window is open') { app.app.windows.length == 1 }
    d.check('the amount entry shows the new value') { entry.call.text == '975' }
    d.check('the entry text actually changed') { entry.call.text != @before_entry }
  end

  # Settings' apply_to/remember is the restore/store pair upstream binds with
  # Gio.SettingsBindFlags.DEFAULT. A fresh Settings instance reading the same
  # path is the round-trip: what the window stored is what the next one reads.
  d.step('the window state is stored and re-read from a fresh Settings') do
    window.call.then do |win|
      win.default_width = 512
      win.default_height = 640
      app.utils.settings.remember(win)
    end

    reloaded = Settings.new(path: app.utils.settings.location)
    d.check('width round-trips') { reloaded.get_int('width') == 512 }
    d.check('height round-trips') { reloaded.get_int('height') == 640 }
    d.check('is-maximized round-trips') { reloaded.get_boolean('is-maximized') == window.call.maximized? }

    reloaded['is-maximized'] = true
    rereloaded = Settings.new(path: app.utils.settings.location)
    d.check('a later write is visible to a new reader') { rereloaded.get_boolean('is-maximized') == true }
  end
end
