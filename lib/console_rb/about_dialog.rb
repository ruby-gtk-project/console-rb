# frozen_string_literal: true

module ConsoleRb
  # The About window, plus the --version and --about console output.
  class AboutDialog
    include I18n

    LOGO = <<~ART
         ______
        / ____/___  ____  _________  / /__
       / /   / __ \\/ __ \\/ ___/ __ \\/ / _ \\
      / /___/ /_/ / / / (__  ) /_/ / /  __/
      \\____/\\____/_/ /_/____/\\____/_/\\___/
    ART

    def initialize(root: nil)
      @root = root
    end

    def present(parent) = dialog.present(parent)

    def dialog
      @dialog ||= Adwaita::AboutDialog.new.tap do |about|
        about.debug_info = SystemInfo.report(@root)
        about.debug_info_filename = 'console-rb-info.txt'
        about.translator_credits = _('translator-credits')
        about.application_name = 'Console'
        about.application_icon = 'utilities-terminal'
        about.version = VERSION
        about.developer_name = 'The Ruby GTK Project'
        about.website = HOMEPAGE_URL
        about.issue_url = "#{HOMEPAGE_URL}/issues"
        about.license_type = Gtk::License::GPL_3_0
        about.comments = _('A Ruby GTK4 port of GNOME Console (KGX).')
        about.developers = ['Zander Brown (original C implementation)']
        about.copyright = '© 2019-2024 Zander Brown'
      end
    end

    def self.print_version = puts("console-rb #{VERSION}")

    def self.print_logo
      puts LOGO
      puts "console-rb #{VERSION} — a Ruby GTK4 port of GNOME Console"
      puts HOMEPAGE_URL
      puts
      puts SystemInfo.report
    end
  end
end
