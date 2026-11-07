# frozen_string_literal: true

require 'gettext'

# I18n is the port's translation binding: upstream's `gettext.install('valuta',
# '@localedir@')` / `_ = gettext.gettext` from src/define.in, as a mixin every
# file with a translatable string can `include`.
#
# The domain is upstream's own meson project/package name, not the port's gem
# name — a `.mo` is found at `<path>/<lang>/LC_MESSAGES/<domain>.mo`, so
# renaming the domain would orphan every one of upstream's 33 donated
# catalogues. `LOCALE_DIR` is `locale/`, the `rake gettext:mo` build output
# (`.gitignore`d); `po/` itself holds the human-edited `.po` sources that
# `GetText::Tools::Task` compiles into it.
#
module I18n
  DOMAIN = 'io.github.idevecore.Valuta'
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
