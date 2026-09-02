# frozen_string_literal: true

module ConsoleRb
  # Wires everything together: the shared settings and watcher, the app-level
  # actions and accelerators, and the command line.
  class Application
    ACCELERATORS = {
      'win.new-window' => ['<shift><primary>n', 'New'],
      'win.new-tab' => ['<shift><primary>t', '<shift>New'],
      'win.close-tab' => ['<shift><primary>w'],
      'term.copy' => ['<shift><primary>c', 'Copy'],
      'term.paste' => ['<shift><primary>v', 'Paste'],
      'win.find' => ['<shift><primary>f', 'Find'],
      'app.zoom-in' => ['<primary>plus', '<primary>equal', 'ZoomIn'],
      'app.zoom-out' => ['<primary>minus', 'ZoomOut'],
      'app.zoom-normal' => ['<primary>0'],
      'win.show-tabs' => ['<shift><primary>o'],
      'win.show-tabs-desktop' => ['<shift><primary>o'],
      'win.fullscreen' => ['<shift><primary>F11'],
      'win.unfullscreen' => ['<shift><primary>F11']
    }.freeze

    attr_reader :windows

    def initialize
      @windows = []
    end

    def build
      app.tap do |a|
        a.signal_connect('startup') { startup }
        a.signal_connect('activate') { activate }
        a.signal_connect('command-line') { |_app, command_line| handle_command_line(command_line) }
        a.signal_connect('shutdown') { save_window_state }
      end
    end

    def run(argv = []) = app.run(argv)

    # Single-instance: a second `console-rb --tab` hands its arguments to the
    # running process over D-Bus rather than starting a second application.
    def app
      @app ||= Gtk::Application.new(APPLICATION_ID, :handles_command_line)
    end

    def settings = @settings ||= Settings.new

    def watcher = @watcher ||= Watcher.new

    # --- Lifecycle -----------------------------------------------------------

    def startup
      Adwaita.init
      # GtkApplication is the authority on which windows still exist; hooking
      # each window's own destroy signal misses windows torn down with the app.
      app.signal_connect('window-removed') { |_app, gtk_window| forget(gtk_window) }
      apply_color_scheme
      settings.on_change { |key| apply_color_scheme if key == 'theme' }

      load_style
      install_actions
      install_accelerators
      watcher.start
    end

    def activate
      @windows.empty? ? add_terminal : @windows.last.present
    end

    # --- Command line --------------------------------------------------------

    def handle_command_line(command_line)
      CLI.new(command_line.arguments.drop(1)).parse.then do |cli|
        if cli.handle_immediate { settings }
          cli.options[:error] ? 1 : 0
        else
          open_for(cli.options, command_line.cwd).then do |tabs|
            wait_for(command_line, tabs) if cli.options[:wait]
          end
          0
        end
      end
    end

    # `--wait` keeps the application alive until the tabs this invocation
    # started have exited, which is what lets `console-rb --wait -e vi file`
    # serve as an $EDITOR. Gio::ApplicationCommandLine exposes no hold/release
    # in Ruby, so the hold is taken on the application itself and the command
    # line's exit status is set when the last tab goes.
    def wait_for(command_line, tabs)
      tabs.compact.then do |pending|
        if pending.empty?
          command_line.exit_status = 0
        else
          app.hold
          pending.each { |tab| tab.on_exit { finish_wait(command_line, pending, tab) } }
        end
      end
    end

    def finish_wait(command_line, pending, tab)
      pending.delete(tab)
      pending.empty?.then do |done|
        if done
          command_line.exit_status = 0
          app.release
        end
      end
    end

    # Positional paths each get their own tab; the first one creates the window
    # unless --tab asked to join the existing one. Returns the tabs it opened so
    # --wait has something to wait on.
    def open_for(options, cwd)
      host = options[:tab] ? @windows.last : nil

      directories(options, cwd).map do |directory|
        add_terminal(window: host,
                     working_directory: directory,
                     command: options[:command],
                     title: options[:title]).tap { host = @windows.last }
      end
    end

    def directories(options, cwd)
      options[:paths].then do |paths|
        paths.empty? ? [options[:working_directory] || cwd] : paths
      end
    end

    def apply_color_scheme
      Adwaita::StyleManager.default.color_scheme = settings.color_scheme
    end

    def load_style
      Gtk::CssProvider.new.tap do |provider|
        provider.load_from_path(File.join(__dir__, '..', '..', 'data', 'style.css'))
        Gtk::StyleContext.add_provider_for_display(
          Gdk::Display.default, provider, Gtk::StyleProvider::PRIORITY_APPLICATION
        )
      end
    rescue StandardError => e
      warn "console-rb: could not load stylesheet: #{e.message}"
    end

    # --- Actions -------------------------------------------------------------

    def install_actions
      {
        'new-window' => -> { add_terminal },
        'new-tab' => -> { add_terminal(window: @windows.last) },
        'zoom-in' => -> { settings.increase_scale },
        'zoom-out' => -> { settings.decrease_scale },
        'zoom-normal' => -> { settings.reset_scale },
        'shortcuts' => -> { ShortcutsDialog.new.present(@windows.last&.window) },
        'quit' => -> { app.quit }
      }.each do |name, handler|
        app.add_action(
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect('activate') { handler.call }
          end
        )
      end

      app.add_action(theme_action)
      app.add_action(focus_page_action)
      settings.on_change do |key|
        refresh_zoom_actions
        sync_theme_action if key == 'theme'
      end
      refresh_zoom_actions
    end

    # Keeps the zoom buttons greyed out at the ends of the scale.
    def refresh_zoom_actions
      { 'zoom-in' => settings.scale_can_increase?,
        'zoom-out' => settings.scale_can_decrease?,
        'zoom-normal' => settings.scale_can_reset? }.each do |name, enabled|
        app.lookup_action(name)&.enabled = enabled
      end
    end

    # No change-state handler: calling set_state from inside one re-enters
    # through the bindings and segfaults, and without a handler GLib updates the
    # state itself, which notify::state then reports back to us.
    # `app.focus-page` takes a tab id and raises the window holding it. Upstream
    # keeps a GTree of live pages for this; a lookup across the open windows is
    # the same thing without the weak-reference bookkeeping.
    def focus_page_action
      @focus_page_action ||= Gio::SimpleAction.new('focus-page', GLib::VariantType.new('u')).tap do |action|
        action.signal_connect('activate') { |_act, parameter| focus_page(unwrap(parameter)) }
      end
    end

    # The activate signal hands back a plain Ruby value for simple types, while
    # Action#activate still wants a GLib::Variant going the other way. See
    # FINDINGS.md — an exception here would unwind through GObject's signal
    # emission and abort the process rather than raise.
    def unwrap(parameter)
      parameter.is_a?(GLib::Variant) ? parameter.value : parameter
    end

    def focus_page(id)
      @windows.each do |window|
        window.pages.tabs.find { |tab| tab.id == id }&.then do |tab|
          window.pages.focus(tab)
          window.present
        end
      end
    end

    def theme_action
      @theme_action ||= Gio::SimpleAction.new(
        'theme', GLib::VariantType.new('s'), GLib::Variant.new(settings.theme.to_s)
      ).tap do |action|
        action.signal_connect('notify::state') do
          settings.theme = state_string(action) unless @syncing_theme
        end
      end
    end

    def state_string(action) = unwrap(action.state).to_s

    # Keeps the menu's radio selection right when the theme changes elsewhere,
    # such as from the theme switcher.
    def sync_theme_action
      @syncing_theme = true
      theme_action.state = GLib::Variant.new(settings.theme.to_s) unless
        state_string(theme_action) == settings.theme.to_s
      @syncing_theme = false
    end

    def install_accelerators
      ACCELERATORS.each { |action, accels| app.set_accels_for_action(action, accels) }
    end

    # --- Windows and tabs ----------------------------------------------------

    def add_terminal(window: nil, working_directory: nil, command: nil, title: nil)
      (window || new_window).then do |host|
        Tab.new(
          settings: settings,
          watcher: watcher,
          initial_work_dir: working_directory || host.pages.working_directory&.path,
          command: command,
          tab_title: title,
          close_on_quit: command.nil?
        ).tap do |tab|
          host.pages.add(tab)
          host.present
        end
      end
    end

    def new_window
      Window.new(
        application: app,
        settings: settings,
        watcher: watcher,
        on_new_window: ->(_source) { new_window.tap(&:present) },
        on_new_tab: ->(source) { add_terminal(window: source) }
      ).tap do |window|
        window.build
        restore_geometry(window)
        @windows << window
        window.window.signal_connect('notify::is-active') { refresh_background_state }
      end
    end

    def restore_geometry(window)
      settings.restore_size?.then do |restore|
        next unless restore

        settings.window_size.then do |(width, height)|
          window.window.set_default_size(width, height) if width.positive? && height.positive?
        end
        window.window.maximize if settings.window_maximised?
        window.window.fullscreen if settings.window_fullscreen?
      end
    end

    def forget(gtk_window)
      @windows.reject! { |window| window.window == gtk_window }
      refresh_background_state
    end

    # Polling backs off whenever no window has focus, which is what upstream
    # uses its in-background property for.
    def refresh_background_state
      watcher.in_background = @windows.none? { |window| window.window.active? }
    end

    def save_window_state
      @windows.last&.then do |window|
        window.window.default_size.then do |(width, height)|
          settings.save_window_state(width: width, height: height,
                                     maximised: window.window.maximized?,
                                     fullscreen: window.window.fullscreened?)
        end
      end
    end
  end
end
