# frozen_string_literal: true

# End-to-end smoke test: builds the real application, opens a tab, drives the
# shell through the pty and reads the result back off the terminal grid.
# Needs a display; Xvfb is fine. Run it with `rake test` or directly:
#   ruby test/integration_test.rb

require_relative '../lib/console_rb'

class IntegrationTest
  MARKER = 'CONSOLE_RB_OK_7Q2'

  def initialize
    @failures = []
    @checks = 0
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

  def run
    $stdout.sync = true
    application.build
    # The application handles its own command line, and that signal stops after
    # the first handler returns — so there is no signal left to hook. A timeout
    # armed before the loop starts fires once the first window is up.
    GLib::Timeout.add(1200) { start_checks }
    application.app.run([$PROGRAM_NAME])
    report
  end

  def application = @application ||= ConsoleRb::Application.new

  def window = application.windows.first

  def tab = window.pages.tabs.first

  def terminal = tab.terminal.terminal

  def start_checks
    check('a window was created', application.windows.one?)
    check('the window has one tab', window.pages.tab_count == 1)
    check('the tab has a terminal', !tab.terminal.terminal.nil?)
    check('a pty was attached', !terminal.pty.nil?)

    # Give the shell a moment to come up before typing at it.
    GLib::Timeout.add(1500) { feed_command }
    GLib::Source::REMOVE
  end

  def feed_command
    check('the shell spawned and has a train', !tab.train.nil?)
    check('the train knows its pid', !tab.train.nil? && tab.train.pid.positive?)

    terminal.feed_child("echo #{MARKER}\n")
    GLib::Timeout.add(2500) { read_back }
    GLib::Source::REMOVE
  end

  def read_back
    terminal.select_all
    terminal.get_text_selected(Vte::Format::TEXT).to_s.then do |text|
      check('the shell ran the command and echoed the marker', text.include?(MARKER))
    end
    terminal.unselect_all

    check_settings
    check_palette
    check_regex
    check_processes
    check_train

    application.app.quit
    GLib::Source::REMOVE
  end

  def check_settings
    application.settings.then do |settings|
      check('a shell is resolvable', !settings.shell.empty?)
      check('the font resolves to a FontDescription', settings.font.is_a?(Pango::FontDescription))
      check('the font scale is within range', settings.font_scale <= ConsoleRb::Settings::FONT_SCALE_MAX)
      check('a theme resolves to day or night', %i[day night].include?(settings.resolve_theme(true)))
    end
  end

  def check_palette
    ConsoleRb::Liveries.standard.night.then do |palette|
      check('the standard palette has 16 colours', palette.colours.length == 16)
      check('the standard palette is translucent', palette.transparency.positive?)
      check('an opaque palette has full alpha', (palette.opaque.background.alpha - 1.0).abs < 0.001)
    end
    check('an unknown livery uuid falls back', ConsoleRb::Liveries.find('nope').uuid == ConsoleRb::Liveries::KGX_UUID)
    check('a livery without day colours reuses night',
          ConsoleRb::Liveries.linux.palette_for(:day).equal?(ConsoleRb::Liveries.linux.night))
  end

  def check_regex
    check('a search regex compiles', !ConsoleRb::Regex.for_search('hello').nil?)
    ConsoleRb::Terminal::LINK_REGEXES.each_with_index do |pattern, index|
      check("link regex #{index} compiles", !ConsoleRb::Regex.for_match(pattern).nil?)
    end
  end

  def check_processes
    ConsoleRb::ProcessInfo.read(Process.pid).then do |info|
      check('this process is readable from /proc', !info.nil?)
      check('its argv is non-empty', !info.nil? && !info.argv.empty?)
      check('it is not mistaken for a remote session', !info.nil? && !info.remote?)
      check('its euid is readable', !info.nil? && info.euid >= 0)
    end
  end

  def check_train
    tab.train.then do |train|
      train.refresh(ConsoleRb::ProcessInfo.all)
      check('the train sees its own shell process', !train.children.empty?)
      check('an idle shell reports no running commands', train.running_commands.empty?)
      check('an idle tab closes without prompting', tab.close_safely?)
    end
  end

  def report
    puts
    puts "#{@checks - @failures.length}/#{@checks} checks passed"
    @failures.each { |name| puts "  failed: #{name}" }
    exit(@failures.empty? ? 0 : 1)
  end
end

IntegrationTest.new.run
