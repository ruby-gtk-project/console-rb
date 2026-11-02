# frozen_string_literal: true

module ConsoleRb
  # Ported from src/kgx-depot.c.
  #
  # The one place a shell is started. A tab hands over its pty and says where
  # and what to run; the depot resolves the gaps from settings, assembles the
  # child's environment, spawns, and — on success — builds the Train for the new
  # process and registers it with the watcher before handing it back.
  #
  # Keeping this out of the tab is what lets every kind of tab spawn the same
  # way, and it is why the proxy environment and the TERM variables cannot drift
  # between them.
  class Depot
    include I18n

    def initialize(watcher:, proxy_info: ProxyInfo.new)
      @watcher = watcher
      @proxy_info = proxy_info
    end

    attr_reader :watcher, :proxy_info

    # Yields (train, error): exactly one of the two is nil. +argv+ and +env+ may
    # be nil, in which case the configured shell and this process's environment
    # are used, as upstream's resolved_argv/resolved_envv do.
    def spawn(settings:, terminal:, pty:, working_directory: nil, argv: nil, env: nil, &block)
      prepare(pty, settings)
      terminal.pty = pty
      terminal.spawn_async(
        Vte::PtyFlags::DEFAULT,
        resolve_working_directory(working_directory),
        resolve_argv(argv, settings),
        resolve_environment(env),
        GLib::Spawn::SEARCH_PATH,
        -1,
        nil
      ) do |_term, pid, _error|
        # The bindings hand back a bogus GError object even on success, so a
        # valid pid is the only reliable success signal here.
        pid.to_i.positive? ? started(pid.to_i, &block) : failed(&block)
      end
    end

    # Upstream clears IXON/IXOFF in a child_setup callback between fork and
    # exec. The Ruby binding exposes no child_setup, so the same flags are set
    # on the pty master instead; see Termios.
    def prepare(pty, settings)
      Termios.set_flow_control(pty.fd, settings.software_flow_control?)
    end

    def started(pid, &block)
      Train.new(pid).tap do |train|
        watcher.watch(train)
        block&.call(train, nil)
      end
    end

    def failed(&block)
      block&.call(nil, RuntimeError.new(_('the shell could not be spawned')))
    end

    def resolve_working_directory(working_directory)
      working_directory.to_s.empty? ? Dir.home : working_directory
    end

    def resolve_argv(argv, settings)
      argv && !argv.empty? ? argv : settings.shell
    end

    # TERM_PROGRAM lets scripts recognise the terminal and TERM is what drives
    # terminfo lookups in the child. The desktop's proxy settings are folded in
    # first so command-line tools inherit them, then the terminal's own
    # variables are forced on top — upstream sets all three with overwrite.
    def resolve_environment(env)
      (env && !env.empty? ? env.to_h { |entry| entry.split('=', 2) } : ENV.to_h)
        .merge(proxy_info.environment)
        .merge('TERM_PROGRAM' => 'console-rb',
               'TERM_PROGRAM_VERSION' => VERSION,
               'TERM' => 'xterm-256color')
        .map { |key, value| "#{key}=#{value}" }
    end
  end
end
