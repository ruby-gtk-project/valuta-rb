# frozen_string_literal: true

require 'adwaita'

require_relative 'about_dialog'

# Actions installs the application's actions and their accelerators.
#
# Ported from upstream's src/actions.py: quit, about, and switch-currencies,
# which swaps the source and destination currencies in the settings and lets
# the page react to the change.
#
module Actions
  # Upstream calls set_accels_for_action('app.quit', …) twice, once for
  # <primary>q and once for <primary>w, so the second call silently replaces
  # the first and only Ctrl+W quits. Both are bound here, in the one call that
  # keeps them.
  ACCELERATORS = {
    'app.quit'              => ['<primary>q', '<primary>w'],
    'app.switch-currencies' => ['<primary>s'],
    'win.show-help-overlay' => ['<Primary>question'],
  }.freeze

  def self.install(application)
    application.app.tap do |app|
      add(app, 'quit') { app.quit }
      add(app, 'about') { AboutDialog.new.present(app.active_window) }
      add(app, 'switch-currencies') { invert_currencies(application.utils.settings) }

      ACCELERATORS.each { |name, accels| app.set_accels_for_action(name, accels) }
    end
  end

  def self.add(app, name, &activate)
    Gio::SimpleAction.new(name).tap do |action|
      action.signal_connect('activate') { activate.call }
      app.add_action(action)
    end
  end

  def self.invert_currencies(settings)
    from_code = settings.get_string('src-currency')
    to_code = settings.get_string('dest-currency')
    settings.set_string('src-currency', to_code)
    settings.set_string('dest-currency', from_code)
  end
end
