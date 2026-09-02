# frozen_string_literal: true

# Drives every app.* and win.* action and opens every dialog, which is the part
# of the UI the pty smoke test never touches. Needs a display; Xvfb is fine.
#   ruby test/actions_test.rb

require_relative '../lib/console_rb'

class ActionsTest
  def initialize
    @failures = []
    @checks = 0
    @steps = []
  end

  def check(name, condition)
    @checks += 1
    if condition
      puts "ok   #{name}"
    else
      @failures << name
      puts "FAIL #{name}"
    end
  end

  # Each step runs on its own turn of the main loop so widgets have a chance to
  # settle (and so a crash names the step that caused it).
  def step(name, &block)
    @steps << [name, block]
  end

  def run
    $stdout.sync = true
    application.build
    GLib::Timeout.add(1200) { run_steps }
    application.app.run([$PROGRAM_NAME])
    report
  end

  def run_steps
    define_steps
    pump
    GLib::Source::REMOVE
  end

  def pump
    @steps.shift.then do |entry|
      if entry.nil?
        application.app.quit
      else
        begin
          entry[1].call
          check(entry[0], true)
        rescue StandardError => e
          check("#{entry[0]} — #{e.class}: #{e.message}", false)
        end
        GLib::Timeout.add(250) { pump }
      end
    end
  end

  def application = @application ||= ConsoleRb::Application.new

  def window = application.windows.first

  def pages = window.pages

  def settings = application.settings

  def activate(scope, name, parameter = nil)
    (scope == :app ? application.app : window.actions).lookup_action(name).activate(parameter)
  end

  def define_steps
    define_zoom_steps
    define_tab_steps
    define_search_steps
    define_dialog_steps
    define_theme_steps
    define_window_steps
    define_cli_steps
  end

  # --- Zoom ----------------------------------------------------------------

  def define_zoom_steps
    step('app.zoom-in raises the font scale') do
      settings.reset_scale
      activate(:app, 'zoom-in')
      raise "scale did not rise: #{settings.font_scale}" unless settings.font_scale > 1.0
    end

    step('app.zoom-out lowers the font scale') do
      activate(:app, 'zoom-out')
      raise 'scale did not fall' unless (settings.font_scale - 1.0).abs < 0.001
    end

    step('app.zoom-normal resets the font scale') do
      activate(:app, 'zoom-in')
      activate(:app, 'zoom-normal')
      raise 'scale did not reset' unless (settings.font_scale - 1.0).abs < 0.001
    end

    step('zoom-normal is disabled at the default scale') do
      raise 'still enabled' if application.app.lookup_action('zoom-normal').enabled?
    end

    step('the zoom label tracks the scale') do
      settings.font_scale = 1.5
      raise "label reads #{window.zoom_label.label}" unless window.zoom_label.label == '150%'

      settings.reset_scale
    end
  end

  # --- Tabs ----------------------------------------------------------------

  def define_tab_steps
    step('win.new-tab adds a second tab') do
      activate(:win, 'new-tab')
      raise "#{pages.tab_count} tabs" unless pages.tab_count == 2
    end

    step('the new tab becomes the selected one') do
      raise 'not selected' unless pages.selected_tab.equal?(pages.tabs.last)
    end

    step('win.close-tab removes it again') do
      activate(:win, 'close-tab')
      raise "#{pages.tab_count} tabs" unless pages.tab_count == 1
    end

    step('win.new-window opens a second window') do
      activate(:win, 'new-window')
      raise "#{application.windows.length} windows" unless application.windows.length == 2
    end

    step('the second window is asked to close') do
      application.windows.last.window.destroy
    end

    step('the closed window is forgotten') do
      raise "#{application.windows.length} windows" unless application.windows.one?
    end
  end

  # --- Search --------------------------------------------------------------

  def define_search_steps
    step('win.find opens the search bar') do
      activate(:win, 'find')
      raise 'search bar closed' unless pages.selected_tab.search_mode_enabled
    end

    step('typing a query sets a VTE search regex') do
      pages.selected_tab.search_entry.text = 'needle'
      pages.selected_tab.search_changed
      raise 'no regex set' if pages.selected_tab.terminal.terminal.search_get_regex.nil?
    end

    step('a regex-special query does not raise') do
      pages.selected_tab.search_entry.text = 'a[b('
      pages.selected_tab.search_changed
    end

    step('clearing the query clears the regex') do
      pages.selected_tab.search_entry.text = ''
      pages.selected_tab.search_changed
      raise 'regex still set' unless pages.selected_tab.terminal.terminal.search_get_regex.nil?
    end

    step('win.find closes the search bar again') do
      activate(:win, 'find')
      raise 'search bar still open' if pages.selected_tab.search_mode_enabled
    end
  end

  # --- Dialogs -------------------------------------------------------------

  def define_dialog_steps
    step('the preferences dialog builds and presents') do
      ConsoleRb::PreferencesDialog.new(settings: settings).tap do |prefs|
        prefs.present(window.window)
        prefs.dialog.close
      end
    end

    step('the preferences dialog reflects current settings') do
      ConsoleRb::PreferencesDialog.new(settings: settings).tap do |prefs|
        prefs.build
        raise 'bell row out of sync' unless prefs.audible_bell_row.active? == settings.audible_bell?
        raise 'scrollback out of sync' unless prefs.scrollback_row.value.to_i == settings.scrollback_limit
      end
    end

    step('the shortcuts dialog builds and presents') do
      ConsoleRb::ShortcutsDialog.new.tap do |dialog|
        dialog.present(window.window)
        dialog.dialog.close
      end
    end

    step('the about dialog builds and presents') do
      ConsoleRb::AboutDialog.new.tap do |dialog|
        dialog.present(window.window)
        dialog.dialog.close
      end
    end

    step('the close dialog builds with a process list') do
      ConsoleRb::CloseDialog.new(
        context: :window,
        commands: [ConsoleRb::ProcessInfo.read(Process.pid)],
        on_close: -> {}
      ).tap do |dialog|
        dialog.present(window.window)
        dialog.dialog.close
      end
    end
  end

  # --- Theme ---------------------------------------------------------------

  def define_theme_steps
    step('the theme switcher builds') do
      ConsoleRb::ThemeSwitcher.new(settings: settings).build
    end

    step('the theme action switches to day') do
      activate(:app, 'theme', GLib::Variant.new('day'))
      raise "theme is #{settings.theme}" unless settings.theme == :day
    end

    step('a day theme resolves to day regardless of the system') do
      raise 'not day' unless settings.resolve_theme(true) == :day
    end

    step('the theme action switches back to night') do
      activate(:app, 'theme', GLib::Variant.new('night'))
      raise "theme is #{settings.theme}" unless settings.theme == :night
    end

    step('an auto theme follows the system') do
      settings.theme = :auto
      raise 'auto ignored the system' unless settings.resolve_theme(true) == :night &&
                                             settings.resolve_theme(false) == :day

      settings.theme = :night
    end

    step('the terminal palette survives a theme change') do
      pages.selected_tab.terminal.apply_palette
    end
  end

  # --- Window state --------------------------------------------------------

  def define_window_steps
    step('win.show-tabs opens the overview') do
      activate(:win, 'show-tabs')
      raise 'overview closed' unless window.tab_overview.open?
    end

    step('the overview closes again') do
      window.tab_overview.open = false
      raise 'overview still open' if window.tab_overview.open?
    end

    step('win.fullscreen and win.unfullscreen do not raise') do
      activate(:win, 'fullscreen')
      activate(:win, 'unfullscreen')
    end

    step('a privileged status adds the root style class') do
      pages.selected_tab.status_changed([:privileged])
      raise 'no root class' unless window.window.css_classes.include?('root')
    end

    step('clearing the status removes it again') do
      pages.selected_tab.status_changed([])
      raise 'root class stuck' if window.window.css_classes.include?('root')
    end

    step('the bell flashes the window') do
      window.ring
      raise 'no bell class' unless window.window.css_classes.include?('bell')
    end

    step('window geometry round-trips through GSettings') do
      settings.save_window_state(width: 900, height: 700, maximised: false, fullscreen: false)
      raise "got #{settings.window_size}" unless settings.window_size == [900, 700]
    end
  end

  # --- Command line --------------------------------------------------------

  def define_cli_steps
    step('--title is parsed') do
      ConsoleRb::CLI.new(['--title', 'Hello']).parse.options.then do |options|
        raise "got #{options[:title].inspect}" unless options[:title] == 'Hello'
      end
    end

    step('-e splits a command into argv') do
      ConsoleRb::CLI.new(['-e', 'ls -la']).parse.options.then do |options|
        raise "got #{options[:command].inspect}" unless options[:command] == %w[ls -la]
      end
    end

    step('-- takes the remainder verbatim') do
      ConsoleRb::CLI.new(['--', 'sh', '-c', 'echo hi']).parse.options.then do |options|
        raise "got #{options[:command].inspect}" unless options[:command] == ['sh', '-c', 'echo hi']
      end
    end

    step('positional paths are collected') do
      ConsoleRb::CLI.new(['/tmp', '/var']).parse.options.then do |options|
        raise "got #{options[:paths].inspect}" unless options[:paths] == ['/tmp', '/var']
      end
    end

    step('--working-directory with paths is rejected') do
      raise 'not rejected' unless ConsoleRb::CLI.new(['--working-directory', '/tmp',
                                                      '/var']).parse.conflicting?
    end

    step('an unknown option is reported, not raised') do
      ConsoleRb::CLI.new(['--nonsense']).parse.options.then do |options|
        raise 'no error recorded' if options[:error].nil?
      end
    end

    step('--tab is parsed') do
      raise 'not set' unless ConsoleRb::CLI.new(['--tab']).parse.options[:tab]
    end
  end

  def report
    puts
    puts "#{@checks - @failures.length}/#{@checks} checks passed"
    @failures.each { |name| puts "  failed: #{name}" }
    exit(@failures.empty? ? 0 : 1)
  end
end

ActionsTest.new.run
