# frozen_string_literal: true

require_relative 'application'

# Main is the port's entry point.
#
# Ported from upstream's src/main.py, which is one lambda handing sys.argv to
# the application. The command line is passed through untouched, because the
# application handles it itself: a second invocation carrying
# --src-currency-value reloads the running window's page rather than starting a
# new process.
#
module Main
  def self.run(argv = ARGV) = Application.new.build.run(argv)
end
