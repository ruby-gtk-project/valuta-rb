require_relative "rb/version"

# frozen_string_literal: true

# The part of Valuta that loads without a display.
#
# Unlike the pilot port (tally), valuta-rb has no models that are worth
# isolating from its widgets yet — currency conversion, settings and the
# search provider all sit behind files that `require "adwaita"`, which
# initialises GTK at require time and raises Gtk::InitError with no display
# server. So, for now, this file carries only the gem's version constant: the
# one thing spec/spec_helper.rb needs that is safe to load anywhere. The specs
# that drive widgets ask for "main" (or "valuta") themselves, the way
# test/drive_*.rb does.
