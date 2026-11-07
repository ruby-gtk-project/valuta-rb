# frozen_string_literal: true

require 'gettext'

# I18n is the port's translation binding: upstream's `gettext.install('valuta',
# '@localedir@')` / `_ = gettext.gettext` from src/define.in, as a mixin every
# file with a translatable string can `include`.
#
# The domain is upstream's own meson project/package name ("valuta",
# `meson.build:1`, `po/meson.build:1`, `gettext.install('valuta', ...)` in
# src/define.in), not the app id and not the port's gem name — a `.mo` is
# found at `<path>/<lang>/LC_MESSAGES/<domain>.mo`, so a domain that does not
# match upstream's would orphan every one of upstream's 33 donated catalogues
# against any tooling that expects the installed `.mo` to be named
# `valuta.mo` (a system package, a Flatpak manifest mirroring upstream).
# `LOCALE_DIR` is `locale/`, the `rake gettext:mo` build output
# (`.gitignore`d); `po/` itself holds the human-edited `.po` sources that
# `GetText::Tools::Task` compiles into it.
#
module I18n
  DOMAIN = 'valuta'
  LOCALE_DIR = File.expand_path('../locale', __dir__)

  def self.included(other)
    other.include(GetText)
    other.bindtextdomain(DOMAIN, path: LOCALE_DIR)
  end

  def self.extended(other)
    other.extend(GetText)
    other.bindtextdomain(DOMAIN, path: LOCALE_DIR)
  end
end
