# frozen_string_literal: true

# Covers the non-widget halves of the port — the spad-source contract, the
# livery manager, the process watcher, the depot's spawn arguments, the
# despatcher's bus call and the paste confirmation — plus the status icons the
# tab indicators look up by name.
# Needs a display; Xvfb is fine. Run it directly:
#   ruby test/services_test.rb

require_relative '../lib/console_rb'

class ServicesTest
  # Anything can be a spad source; this is the smallest thing that is one.
  class Thrower
    include ConsoleRb::SpadSource
  end

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
    Adwaita.init
    check_spad_source
    check_livery_manager
    check_watcher
    check_paste_dialog
    check_despatcher
    check_depot
    check_icons
    check_tab_badge_precedence
    report
  end

  def report
    puts
    puts "#{@checks - @failures.length}/#{@checks} checks passed"
    @failures.each { |failure| puts "  failed: #{failure}" }
    @failures.empty?
  end

  # --- SpadSource ----------------------------------------------------------

  def check_spad_source
    Thrower.new.then do |thrower|
      check('an unhandled spad reports false', thrower.throw_spad(title: 'T', body: 'B') == false)
      seen = nil
      thrower.on_spad_thrown do |title, bundle|
        seen = [title, bundle]
        true
      end
      check('a handled spad reports true',
            thrower.throw_spad(title: 'T2', body: 'B2', content: 'C', flags: %i[show_report]))
      check('the handler is given the title', seen[0] == 'T2')
      check('the bundle is the Spad keyword set', ConsoleRb::Spad.new(**seen[1]).is_a?(ConsoleRb::Spad))
      check('a spad without a body is refused', refuses_empty_body?(thrower))
    end
  end

  def refuses_empty_body?(thrower)
    thrower.throw_spad(title: 'x', body: '  ')
    false
  rescue ArgumentError
    true
  end

  # --- LiveryManager -------------------------------------------------------

  def check_livery_manager
    ConsoleRb::LiveryManager.new.then do |manager|
      check('the manager resolves a built-in uuid',
            manager.resolve(ConsoleRb::Liveries::KGX_UUID).equal?(ConsoleRb::Liveries.standard))
      check('an unknown uuid resolves to nil', manager.resolve('nope').nil?)
      check('an unknown uuid finds the fallback',
            manager.find('nope').uuid == ConsoleRb::Liveries::KGX_UUID)
      check('the three built-ins are listed', manager.all.length == 3)
      check_custom_liveries(manager)
    end
  end

  def check_custom_liveries(manager)
    manager.custom_liveries = [custom_livery('mine')]
    check('a custom livery resolves', manager.resolve('mine').name == 'Custom')
    check('a custom livery is listed', manager.all.length == 4)
    manager.custom_liveries = [custom_livery(ConsoleRb::Liveries::KGX_UUID)]
    check('a custom livery shadows a built-in',
          manager.resolve(ConsoleRb::Liveries::KGX_UUID).name == 'Custom')
    check('shadowing does not grow the list', manager.all.length == 3)
    manager.custom_liveries = []
    check('clearing restores the built-in',
          manager.resolve(ConsoleRb::Liveries::KGX_UUID).equal?(ConsoleRb::Liveries.standard))
  end

  def custom_livery(uuid)
    ConsoleRb::Livery.new(uuid: uuid, name: 'Custom', night: ConsoleRb::Liveries.linux.night)
  end

  # --- Watcher -------------------------------------------------------------

  def check_watcher
    ConsoleRb::Watcher.new.then do |watcher|
      check('the watcher polls fast in the foreground',
            watcher.interval == ConsoleRb::Watcher::FOREGROUND_INTERVAL)
      watcher.in_background = true
      check('the watcher slows down in the background',
            watcher.interval == ConsoleRb::Watcher::BACKGROUND_INTERVAL)
      watcher.in_background = false
      check_watcher_trains(watcher)
      check_watcher_timeout(watcher)
    end
  end

  def check_watcher_trains(watcher)
    ConsoleRb::Train.new(Process.pid).then do |train|
      watcher.watch(train)
      check('the watcher tracks a train', watcher.watching?(train))
      watcher.tick
      check('a tick refreshes the train', train.children.any? { |process| process.pid == Process.pid })
      watcher.unwatch(train)
      check('the watcher drops a train', !watcher.watching?(train))
    end
  end

  def check_watcher_timeout(watcher)
    watcher.start
    check('starting installs a timeout', !watcher.timeout.nil?)
    watcher.in_background = true
    check('a background switch keeps a timeout', !watcher.timeout.nil?)
    watcher.stop
    check('stopping clears it', watcher.instance_variable_get(:@timeout).nil?)
  end

  # --- PasteDialog ---------------------------------------------------------

  def check_paste_dialog
    ConsoleRb::PasteDialog.new(content: "sudo rm -rf /\n").then do |dialog|
      check('the paste dialog is an alert', dialog.dialog.is_a?(Adwaita::AlertDialog))
      check('it offers both responses',
            dialog.dialog.has_response?('paste') && dialog.dialog.has_response?('cancel'))
      check('cancelling is the default way out', dialog.dialog.close_response == 'cancel')
      check('the body quotes the command', dialog.body.include?('sudo rm -rf /'))
    end
    check_paste_truncation
  end

  def check_paste_truncation
    ConsoleRb::PasteDialog.new(content: 'x' * 20_000).constrained_content.then do |text|
      check('a huge paste is truncated',
            text.bytesize <= ConsoleRb::PasteDialog::MAX_CONTENT + '…'.bytesize)
      check('the truncation is marked', text.end_with?('…'))
    end
    ConsoleRb::PasteDialog.new(content: '✓' * 5000).constrained_content.then do |text|
      check('truncation does not split a character', text.valid_encoding?)
    end
  end

  # --- Despatcher ----------------------------------------------------------

  def check_despatcher
    ConsoleRb::Despatcher.new.then do |despatcher|
      check('the FileManager1 arguments are a (ass) tuple',
            despatcher.arguments('file:///tmp/a b').to_s == "(['file:///tmp/a b'], '')")
      check('a quote in a uri is percent-encoded',
            despatcher.escape("file:///it's") == 'file:///it%27s')
      check('a backslash in a uri is percent-encoded',
            despatcher.escape('file:///a\\b') == 'file:///a%5Cb')
      check('the session bus is reachable', !despatcher.connection.nil?)
      check_despatcher_call(despatcher)
    end
  end

  # There is no file manager on the bus under Xvfb, so what is being checked is
  # that the call completes and reports its failure rather than hanging or
  # raising out of the callback.
  def check_despatcher_call(despatcher)
    result = :pending
    despatcher.show_folder('file:///tmp', nil) { |error| result = error }
    pump
    check('show_folder reports a result', result != :pending)
  end

  def pump
    GLib::MainContext.default.then do |context|
      60.times do
        context.iteration(false)
        sleep 0.02
      end
    end
  end

  # --- Depot ---------------------------------------------------------------

  def check_depot
    ConsoleRb::Settings.new.then do |settings|
      ConsoleRb::Depot.new(watcher: ConsoleRb::Watcher.new).then do |depot|
        check('the depot falls back to the home directory',
              depot.resolve_working_directory(nil) == Dir.home)
        check('the depot falls back to the configured shell',
              depot.resolve_argv(nil, settings) == settings.shell)
        check('an explicit command wins', depot.resolve_argv(%w[true], settings) == %w[true])
        check_depot_environment(depot)
      end
    end
  end

  def check_depot_environment(depot)
    depot.resolve_environment(nil).then do |env|
      check('TERM is forced', env.include?('TERM=xterm-256color'))
      check('TERM_PROGRAM names the port', env.include?('TERM_PROGRAM=console-rb'))
      check('the version is exported', env.include?("TERM_PROGRAM_VERSION=#{ConsoleRb::VERSION}"))
    end
    depot.resolve_environment(['FOO=bar']).then do |env|
      check('an explicit environment is honoured', env.include?('FOO=bar'))
      check('an explicit environment still gets TERM', env.include?('TERM=xterm-256color'))
    end
  end

  # --- Icons ---------------------------------------------------------------

  STATUS_ICONS = %w[
    status-remote-symbolic status-privileged-symbolic status-playbox-symbolic
    status-regular-symbolic bell-outline-symbolic emblem-ok-symbolic
    external-link-symbolic theme-check-symbolic
  ].freeze

  def check_icons
    ConsoleRb::Application.new.then do |application|
      application.load_icons
      Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
        STATUS_ICONS.each do |name|
          check("the #{name} icon is installed", theme.has_icon?(name))
        end
      end
    end
  end

  # --- Tab badge precedence -------------------------------------------------

  # Ported from upstream's tests/test-icon-closures.c status_as_icon_cases:
  # Pages::STATUS_ICONS must be walked in this exact order, so a tab that is
  # both remote and privileged shows the remote badge, not the privileged one.
  TabDouble = Struct.new(:status)

  def check_tab_badge_precedence
    pages = ConsoleRb::Pages.new(
      settings: nil, watcher: nil, on_zoom: -> {}, on_status_change: -> {},
      on_bell: -> {}, on_empty: -> {}, on_create_tearoff_host: -> {},
      on_search_change: ->(_enabled) {}
    )
    check('remote alone shows the remote icon',
          names(pages.indicator_for(TabDouble.new([:remote]))).include?('status-remote-symbolic'))
    check('playbox alone shows the playbox icon',
          names(pages.indicator_for(TabDouble.new([:playbox]))).include?('status-playbox-symbolic'))
    check('privileged alone shows the privileged icon',
          names(pages.indicator_for(TabDouble.new([:privileged]))).include?('status-privileged-symbolic'))
    check('remote and privileged together still show the remote icon',
          names(pages.indicator_for(TabDouble.new(%i[remote privileged]))).include?('status-remote-symbolic'))
    check('no status flags show no icon', pages.indicator_for(TabDouble.new([])).nil?)
  end

  def names(icon)
    icon&.names || []
  end
end

exit(ServicesTest.new.run ? 0 : 1)
