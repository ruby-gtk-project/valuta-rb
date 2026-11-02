# frozen_string_literal: true

require 'adwaita'

require_relative 'define'

# AboutDialog is the application's about dialog.
#
# Ported from upstream's src/about.py: an Adw.AboutDialog carrying the same
# credits, links and licence, and the same multi-line debug info block. The
# block names the toolkit versions this build is actually running against;
# upstream's PyGObject line becomes the ruby-gnome binding version, and its
# Blueprint line is gone because this port builds its widgets in Ruby rather
# than compiling blueprints.
#
class AboutDialog < Adwaita::AboutDialog
  APPLICATION_NAME = 'Valuta'
  DEVELOPER = 'Ideve Core'
  DESIGNER = 'Brage Fuglseth https://bragefuglseth.dev'
  ISSUE_URL = 'https://github.com/ideveCore/valuta/issues'
  COPYRIGHT = '© 2023 Ideve Core'

  OS_RELEASE = '/etc/os-release'
  FLATPAK_INFO = '/.flatpak-info'

  def initialize
    super()
    self.application_name = APPLICATION_NAME
    self.application_icon = Define::APP_ID
    self.developer_name = DEVELOPER
    self.version = Define::VERSION
    self.developers = [DEVELOPER]
    self.designers = [DESIGNER]
    self.issue_url = ISSUE_URL
    self.debug_info = debug_info
    self.license_type = Gtk::License::GPL_3_0
    self.copyright = COPYRIGHT
  end

  def debug_info
    [
      "#{Define::APP_ID} #{Define::VERSION}",
      os_info,
      "ruby-gnome #{GLib::BINDING_VERSION.join('.')}",
      "Ruby #{RUBY_VERSION}",
      "Adw #{Adwaita::MAJOR_VERSION}",
      "Gtk #{Gtk::Version::MAJOR}",
      "GLib #{glib_version}",
      "Flatpak #{flatpak_version}",
    ].join("\n")
  end

  private

    def glib_version
      [GLib::MAJOR_VERSION, GLib::MINOR_VERSION, GLib::MICRO_VERSION].join('.')
    end

  # Upstream reads this out of GLib.get_os_info, which the Ruby bindings do not
  # expose; /etc/os-release is the file GLib itself reads.
    def os_info
      os_release.then do |fields|
        "#{fields['ID']} #{fields['VERSION_ID']}".strip
      end
    end

    def os_release
      File.readlines(OS_RELEASE, chomp: true).filter_map { |line| field(line) }.to_h
    rescue SystemCallError
      {}
    end

    def field(line)
      line.split('=', 2).then do |name, value|
        if value
          [name, value.delete('"')]
        end
      end
    end

  # Upstream's get_flatpak_info: the Instance group's flatpak-version, or
  # nothing at all when the app is not running inside a sandbox.
    def flatpak_version
      GLib::KeyFile.new.then do |key_file|
        key_file.load_from_file(FLATPAK_INFO, :none)
        key_file.get_value('Instance', 'flatpak-version')
      end
    rescue StandardError
      'None'
    end
end
