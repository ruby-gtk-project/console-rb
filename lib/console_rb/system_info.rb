# frozen_string_literal: true

module ConsoleRb
  # The debug-info block attached to bug reports and shown in the About dialog:
  # library versions, the renderer in use, and the environment variables that
  # most often explain odd behaviour. Mirrors `kgx_about_append_sys_info`.
  module SystemInfo
    ENVIRONMENT_KEYS = {
      'Adw' => %w[ADW_DISABLE_PORTAL],
      'Gtk' => %w[GTK_DEBUG GTK_THEME GTK_USE_PORTAL],
      'GLib' => %w[G_DEBUG],
      'OS' => %w[XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE LANG]
    }.freeze

    module_function

    def report(root = nil)
      lines(root).compact.join("\n")
    end

    def lines(root)
      [].tap do |out|
        out << "console-rb: #{VERSION}"

        out << library('Adw', Adwaita::VERSION_S, runtime(Adwaita))
        environment(out, 'Adw')

        out << library('Vte', safe { Vte::Version::STRING }, runtime(Vte))
        out << "  Features: #{safe { Vte.features }}"

        out << library('Gtk', safe { Gtk::Version::STRING }, runtime(Gtk))
        renderer(out, root)
        environment(out, 'Gtk')

        out << library('GLib', safe { GLib::BUILD_VERSION.join('.') }, safe { GLib::Version::STRING })
        out << "  Bindings: ruby-gnome #{safe { GLib::BINDING_VERSION.join('.') }}"
        environment(out, 'GLib')

        out << "Ruby: #{RUBY_VERSION} (#{RUBY_PLATFORM})"
        out << "OS: #{os_name} (#{os_version})"
        environment(out, 'OS')
      end
    end

    # Upstream prints the running version in brackets only when it differs from
    # the one the binary was built against.
    def library(name, built, running)
      "#{name}: #{built}#{" (#{running})" if running && running != built}"
    end

    def runtime(mod)
      safe { [mod.major_version, mod.minor_version, mod.micro_version].join('.') }
    end

    def environment(out, group)
      ENVIRONMENT_KEYS.fetch(group, []).each do |key|
        ENV.fetch(key, nil).then { |value| out << "  #{key}: #{value}" if value }
      end
    end

    def renderer(out, root)
      root&.then do |window|
        out << "  Display: #{safe { window.display.class }}"
        out << "  Surface: #{safe { window.surface.class }}"
        out << "  Renderer: #{safe { window.renderer.class }}"
      end
    end

    def os_name = os_release.fetch('NAME', 'Unknown')

    def os_version = os_release.fetch('VERSION', os_release.fetch('VERSION_ID', 'Unknown'))

    def os_release
      @os_release ||= File.readlines('/etc/os-release').filter_map do |line|
        line.strip.split('=', 2).then { |(key, value)| [key, value.to_s.delete('"')] if value }
      end.to_h
    rescue StandardError
      {}
    end

    def safe
      yield
    rescue StandardError
      nil
    end
  end
end
