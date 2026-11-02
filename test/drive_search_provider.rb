# frozen_string_literal: true

# Drives the ported GNOME Shell search provider: the bare-amount query, the
# four-term "100 USD to GBP" form, the metas the shell renders, the clipboard
# row, and the queries that must answer nothing at all.
#
# The provider is a D-Bus service, so this drives it the way the shell does —
# from the outside, over the session bus, with the service in its own process.
# It needs a session bus to itself and re-executes under one when it has none,
# so either of these works from the dev shell:
#
#   nix develop --command ruby test/drive_search_provider.rb
#   nix develop --command dbus-run-session -- ruby test/drive_search_provider.rb
#
# No display is needed: the provider process loads Gio alone.
#
# The rates come off the network, as they do in the app.

require 'json'
require 'rbconfig'
require 'shellwords'
require 'tmpdir'

BUS_NAME = 'io.github.idevecore.Valuta.SearchProvider'
OBJECT_PATH = '/io/github/idevecore/Valuta/SearchProvider'
INTERFACE = 'org.gnome.Shell.SearchProvider2'
PROVIDER = File.expand_path('../exe/valuta-search-provider', __dir__)

# Drives one provider process: starts it, calls it, and reports.
class ProviderDriver
  STARTUP_TRIES = 40
  STARTUP_WAIT = 0.5

  def self.drive(&block) = new.run(&block)

  def initialize
    @config_home = Dir.mktmpdir('valuta-search-provider-drive')
    @checks = 0
    @failed_checks = []
    @errored_steps = []
    @steps = []
    @index = 0
  end

  # --- Registered from inside the block -----------------------------------

  def step(name, &block)
    @steps << [name, block]
  end

  # --- Called from inside a step ------------------------------------------

  def check(description)
    @checks += 1
    yield.then do |ok|
      puts(ok ? "    ok   #{description}" : "    FAIL #{description}")
      unless ok
        @failed_checks << description
      end
      ok
    end
  rescue StandardError => e
    puts "    FAIL #{description} (#{e.class}: #{e.message})"
    @failed_checks << description
    false
  end

  # One method call, as the shell makes it. The reply comes back in GVariant
  # text form, which is what gdbus prints.
  def call(method, *arguments)
    [
      'gdbus', 'call', '--session',
      '--dest', BUS_NAME,
      '--object-path', OBJECT_PATH,
      '--method', "#{INTERFACE}.#{method}",
      *arguments,
    ].then { |command| run_command(command) }
  end

  # The ids a query answers, lifted out of the "(['a', 'b'],)" reply.
  def ids(reply)
    reply.scan(/'((?:[^'\\]|\\.)*)'/).flatten
  end

  # The settings the provider writes, read back from the file it keeps them in.
  def settings
    File.join(@config_home, 'valuta-rb', 'settings.json').then do |path|
      if File.exist?(path)
        JSON.parse(File.read(path))
      else
        {}
      end
    end
  end

  # --- Running -------------------------------------------------------------

  def run
    yield(self)
    start
    @steps.each { |step| run_step(step) }
    report
  ensure
    stop
  end

  private

    def start
      Process.spawn(
        { 'XDG_CONFIG_HOME' => @config_home, 'DISPLAY' => nil, 'WAYLAND_DISPLAY' => nil },
        RbConfig.ruby,
        PROVIDER,
      ).then do |pid|
        @pid = pid
        await
      end
    end

  # The service owns its bus name a moment after it is spawned; the first call
  # that gets an answer is the signal that it is up.
    def await
      STARTUP_TRIES.times.find do
        sleep(STARTUP_WAIT)
        answered?
      end
    end

    def answered?
      !call('GetInitialResultSet', "['valuta']").nil?
    rescue StandardError
      false
    end

    def stop
      if @pid
        Process.kill('TERM', @pid)
        Process.wait(@pid)
      end
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end

    def run_command(command)
      IO.popen(command, err: %i[child out], &:read).then do |output|
        if $?&.success?
          output.strip
        else
          raise "#{command.shelljoin} failed: #{output.strip}"
        end
      end
    end

    def run_step((name, block))
      puts "[#{@index}] #{name}"
      @index += 1
      block.call
    rescue StandardError => e
      puts "    ERROR #{e.class}: #{e.message}"
      @errored_steps << "#{name} (#{e.class}: #{e.message})"
    end

    def report
      puts
      if @checks.positive?
        puts "#{@checks - @failed_checks.length} of #{@checks} checks passed"
      end
      @failed_checks.each { |check| puts "  failed check: #{check}" }
      @errored_steps.each { |step| puts "  errored step: #{step}" }

      (@failed_checks + @errored_steps).length.then do |total|
        puts(total.zero? ? 'DRIVE OK' : "DRIVE FAILED (#{total})")
        exit(total.zero? ? 0 : 1)
      end
    end
end

# A session bus of its own, so the service's name is free and nothing else on
# the machine's bus is disturbed.
if ENV['DBUS_SESSION_BUS_ADDRESS'].to_s.empty?
  exec(
    'dbus-run-session',
    '--',
    RbConfig.ruby,
    __FILE__,
  )
end

ProviderDriver.drive do |d|
  d.step('a bare amount converts with the stored pair') do
    d.call('GetInitialResultSet', "['5']").then do |reply|
      d.check('the conversion and its clipboard row are offered') do
        d.ids(reply) == ['5', 'copy-to-clipboard5']
      end
      d.check('no result is flagged as an error') do
        d.ids(reply).none? { |id| id.start_with?('translation-error') }
      end
    end
  end

  d.step('the metas carry the conversion the shell renders') do
    d.call('GetResultMetas', "['5', 'copy-to-clipboard5']").then do |reply|
      d.check('the conversion reads "5 USD = <amount> EUR"') do
        reply.match?(/'name': <'5 USD = [\d., ]+ EUR'>/)
      end
      d.check('the provider is named') { reply.include?("'According to ECB'") }
      d.check('the clipboard row is labelled Copy') { reply.include?("'Copy'") }
      d.check('the clipboard row explains itself') do
        reply.include?("'Copy convertion to clipboard'")
      end
      d.check('the clipboard row carries the amount') do
        reply.match?(/'clipboardText': <'[\d., ]+'>/)
      end
    end
  end

  d.step('an id the provider knows nothing about is echoed back') do
    d.call('GetResultMetas', "['nothing-was-converted-for-this']").then do |reply|
      d.check('the id is its own name') do
        reply.scan(/'nothing-was-converted-for-this'/).length == 2
      end
    end
  end

  d.step('narrowing the search converts the new amount') do
    d.call('GetSubsearchResultSet', "['5']", "['12']").then do |reply|
      d.check('the new amount is the result') do
        d.ids(reply) == ['12', 'copy-to-clipboard12']
      end
    end
  end

  d.step('the four-term form stores the pair it names') do
    d.call('GetInitialResultSet', "['100', 'USD', 'to', 'GBP']").then do |reply|
      d.check('the query is the result id') do
        d.ids(reply) == ['100 USD to GBP', 'copy-to-clipboard100 USD to GBP']
      end
      d.check('the source currency was stored') { d.settings['src-currency'] == 'USD' }
      d.check('the destination currency was stored') { d.settings['dest-currency'] == 'GBP' }
    end

    d.call('GetResultMetas', "['100 USD to GBP', 'copy-to-clipboard100 USD to GBP']")
     .then do |reply|
      d.check('the conversion reads "100 USD = <amount> GBP"') do
        reply.match?(/'name': <'100 USD = [\d., ]+ GBP'>/)
      end
    end
  end

  d.step('a currency converted into itself answers nothing') do
    d.call('GetInitialResultSet', "['5', 'GBP', 'to', 'GBP']").then do |reply|
      d.check('no result is offered') { d.ids(reply).empty? }
      d.check('the pair was still stored') do
        d.settings['src-currency'] == 'GBP' && d.settings['dest-currency'] == 'GBP'
      end
    end
  end

  d.step('text that is not an amount answers nothing') do
    d.call('GetInitialResultSet', "['hello', 'world']").then do |reply|
      d.check('no result is offered') { d.ids(reply).empty? }
    end

    d.call('GetInitialResultSet', "['100', 'XYZ', 'to', 'ABC']").then do |reply|
      d.check('an unquoted currency code offers nothing') { d.ids(reply).empty? }
    end
  end

  d.step('activating the clipboard row only copies') do
    d.check('the call is answered') do
      d.call(
        'ActivateResult',
        'copy-to-clipboard5',
        "['5']",
        '0',
      ) == '()'
    end
  end
end
