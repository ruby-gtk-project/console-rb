# frozen_string_literal: true

module ConsoleRb
  # Ported from src/kgx-simple-tab.c and src/kgx-simple-tab.ui.
  #
  # The only kind of tab Console has: one that starts a process on a local pty.
  # It holds the three things that decide what that process is — the working
  # directory from --working-directory, the command from -e, and an explicit
  # environment — and hands them to the depot, which does the spawning.
  #
  # The .ui file contributes the scrolled window wrapping the terminal and the
  # tooltip binding; both live in Tab in this port, because Tab's search bar,
  # drop target and focus handling all reach the terminal directly and a Ruby
  # subclass has no template to inject it through.
  class SimpleTab < Tab
    include I18n

    def initialize(settings:, watcher:, depot:, despatcher: Despatcher.new,
                   initial_work_dir: nil, command: nil, environ: nil, tab_title: nil,
                   close_on_quit: true)
      super(settings: settings, watcher: watcher, despatcher: despatcher,
            tab_title: tab_title, close_on_quit: close_on_quit)
      @depot = depot
      @initial_work_dir = initial_work_dir
      @command = command
      @environ = environ
    end

    attr_reader :initial_work_dir, :command, :environ, :depot

    # Upstream carries a GCancellable so a tab torn down mid-spawn abandons its
    # process; the Ruby spawn callback fires inline on the main loop and the tab
    # cannot be disposed between the two, so the flag below is all that is
    # needed to recognise a tab that has already given up.
    def start
      @starting = true
      Vte::Pty.new(Vte::PtyFlags::DEFAULT, nil).then do |pty|
        depot.spawn(
          settings: @settings,
          terminal: terminal.terminal,
          pty: pty,
          working_directory: initial_work_dir,
          argv: command,
          env: environ
        ) { |train, error| spawned(train, error) }
      end
    rescue StandardError => e
      failed_to_start(e)
    end

    def spawned(train, error)
      @starting = false
      if error.nil?
        started(train)
      else
        failed_to_start(error)
      end
    end

    # Translators note: <b> </b> marks the text as bold, and upstream's msgid
    # keeps them, so the markup is part of the translated string.
    def failed_to_start(error)
      @starting = false
      died(:error,
           format(_('<b>Failed to start</b> — %s'), error.message),
           success: false)
    end

    def starting? = @starting ? true : false
  end
end
