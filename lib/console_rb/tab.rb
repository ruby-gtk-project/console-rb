# frozen_string_literal: true

module ConsoleRb
  # One terminal session: the search bar, the terminal itself, and the banner
  # that appears when the child process exits and the tab goes read-only.
  class Tab
    include I18n

    @next_id = 0

    class << self
      attr_accessor :next_id

      def allocate_id = self.next_id += 1
    end

    attr_reader :id, :title, :path, :train, :status

    def initialize(settings:, watcher:, initial_work_dir: nil, command: nil,
                   tab_title: nil, close_on_quit: true)
      @id = self.class.allocate_id
      @settings = settings
      @watcher = watcher
      @initial_work_dir = initial_work_dir
      @command = command
      @title = tab_title
      @explicit_title = !tab_title.nil?
      @close_on_quit = close_on_quit
      @status = []
      @listeners = []
      @working = true
    end

    def on_change(&block) = @listeners << block

    def notify = @listeners.each { |listener| listener.call(self) }

    def build
      root.tap do |bin|
        bin.child = toast_overlay

        toast_overlay.tap do |overlay|
          overlay.child = column

          column.tap do |box|
            box.append(toolbar_view)
            box.append(exit_revealer)

            toolbar_view.tap do |view|
              view.add_top_bar(search_bar)
              view.content = stack

              stack.tap do |s|
                s.add_child(empty.build)
                s.add_child(terminal_scroller)
              end
            end
          end
        end
      end

      connect_search
      terminal.build
      terminal_scroller.child = terminal.terminal

      drop_target.tap do |drop|
        drop.widget = root
        terminal.terminal.add_controller(drop.build)
      end

      root
    end

    # --- Lifecycle -----------------------------------------------------------

    def start
      terminal.terminal.pty = Vte::Pty.new(Vte::PtyFlags::DEFAULT, nil)
      spawn
    end

    def spawn
      terminal.terminal.spawn_async(
        Vte::PtyFlags::DEFAULT,
        working_directory,
        argv,
        environment,
        GLib::Spawn::SEARCH_PATH,
        -1,
        nil
      ) do |_term, pid, _error|
        # The bindings hand back a bogus GError object even on success, so a
        # valid pid is the only reliable success signal here.
        pid.to_i.positive? ? started(pid.to_i) : failed_to_start
      end
    end

    def started(pid)
      @working = false
      empty.working = false
      stack.visible_child = terminal_scroller
      @train = Train.new(pid).tap do |train|
        train.on_change { |flags| status_changed(flags) }
        @watcher.add(train)
      end
      notify
    end

    def failed_to_start
      died(:error, format(_('<b>Failed to start</b> — %s'), _('the shell could not be spawned')))
    end

    def working_directory = @initial_work_dir || Dir.home

    def argv = @command && !@command.empty? ? @command : @settings.shell

    # TERM_PROGRAM lets scripts recognise the terminal; TERM is what actually
    # drives terminfo lookups in the child.
    def environment
      ENV.to_h.merge(
        'TERM_PROGRAM' => 'console-rb',
        'TERM_PROGRAM_VERSION' => VERSION,
        'TERM' => 'xterm-256color'
      ).map { |key, value| "#{key}=#{value}" }
    end

    def status_changed(flags)
      @status = flags
      notify
    end

    def died(type, message)
      exit_message.markup = message
      type == :error ? exit_revealer.add_css_class('error') : exit_revealer.remove_css_class('error')
      exit_revealer.reveal_child = true
      @train&.then { |train| @watcher.remove(train) }
      @train = nil
      notify
    end

    def child_exited(status)
      died(*(if status.zero?
               [:info, _('<b>Read Only</b> — Command exited')]
             else
               [:error, format(_('<b>Read Only</b> — Command exited with code %i'), status)]
             end))
    end

    # A tab with no train left, or one whose train is idle, closes silently.
    def close_safely? = @train.nil? || @train.running_commands.empty?

    def running_commands = @train&.running_commands || []

    def close = @train&.then { |train| @watcher.remove(train) }

    # --- Search --------------------------------------------------------------

    def connect_search
      search_bar.signal_connect('notify::search-mode-enabled') do
        @on_search_change&.call(search_mode_enabled)
      end
      search_entry.signal_connect('search-changed') { search_changed }
      search_entry.signal_connect('next-match') { terminal.terminal.search_find_next }
      search_entry.signal_connect('previous-match') { terminal.terminal.search_find_previous }
      next_button.signal_connect('clicked') { terminal.terminal.search_find_next }
      previous_button.signal_connect('clicked') { terminal.terminal.search_find_previous }
    end

    def search_changed
      search_entry.text.then do |text|
        terminal.terminal.search_set_regex(
          text.empty? ? nil : Regex.for_search(::Regexp.escape(text)), 0
        )
        terminal.terminal.search_set_wrap_around(true)
      end
    end

    def search_mode_enabled = search_bar.search_mode_enabled?

    def search_mode_enabled=(value)
      search_bar.search_mode_enabled = value
      value ? search_entry.grab_focus : focus
    end

    # Without this the window's first focusable widget — the header bar's find
    # button — takes the focus, and typing toggles it instead of reaching the
    # shell.
    def focus = terminal.terminal.grab_focus

    # --- Widgets -------------------------------------------------------------

    def root
      @root ||= Adwaita::Bin.new.tap do |bin|
        bin.add_css_class('console-rb-tab')
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    # Dropped paths are typed at the prompt rather than executed, so the user
    # still has to press Return.
    def drop_target
      @drop_target ||= DropTarget.new(
        on_drop: ->(text) { terminal.terminal.feed_child(text) },
        on_error: lambda { |title, body, content: nil, flags: []|
          throw_spad(title: title, body: body, content: content, flags: flags)
        }
      )
    end

    def column = @column ||= Gtk::Box.new(:vertical, 0)

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def stack
      @stack ||= Gtk::Stack.new.tap do |s|
        s.transition_type = :crossfade
        s.transition_duration = 10
      end
    end

    def empty = @empty ||= Empty.new(working: true)

    def terminal_scroller
      @terminal_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.vexpand = true
        scroller.propagate_natural_width = true
        scroller.propagate_natural_height = true
        scroller.hscrollbar_policy = :never
        scroller.add_css_class('terminal')
      end
    end

    def terminal
      @terminal ||= Terminal.new(
        settings: @settings,
        on_zoom: ->(direction) { zoom(direction) },
        on_bell: -> { bell },
        on_child_exit: ->(status) { child_exited(status) },
        on_path_change: ->(path) { path_changed(path) },
        on_notify: lambda { |title, body, content: nil, flags: []|
          throw_spad(title: title, body: body, content: content, flags: flags)
        }
      )
    end

    def search_bar
      @search_bar ||= Gtk::SearchBar.new.tap do |bar|
        bar.add_css_class('view')
        bar.child = search_clamp
      end
    end

    def search_clamp
      @search_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.hexpand = true
        clamp.maximum_size = 500
        clamp.child = search_box
      end
    end

    def search_box
      @search_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.append(search_entry)
        box.append(previous_button)
        box.append(next_button)
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = _('Find text')
        entry.hexpand = true
      end
    end

    def previous_button
      @previous_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'go-up-symbolic'
        button.tooltip_text = _('Previous Match')
        button.receives_default = true
      end
    end

    def next_button
      @next_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'go-down-symbolic'
        button.tooltip_text = _('Next Match')
        button.receives_default = true
      end
    end

    def exit_revealer
      @exit_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.can_focus = false
        revealer.transition_type = :slide_up
        revealer.add_css_class('background')
        revealer.child = exit_message
      end
    end

    def exit_message
      @exit_message ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.wrap = true
        label.xalign = 0
        label.add_css_class('exit-info')
      end
    end

    # --- Presentation --------------------------------------------------------

    # A non-file URI (an sftp:// cwd from a remote shell, say) has no local
    # path, so the tab keeps whatever title it already had.
    def path_changed(path)
      @path = path
      path&.path&.then { |local| @title = File.basename(local) unless @explicit_title }
      notify
    end

    def display_title
      @title || terminal.terminal.window_title || _('Console')
    end

    def tooltip = @path&.path

    def toast(message) = toast_overlay.add_toast(Adwaita::Toast.new(message))

    # Errors surface as a toast carrying a "Details" button; pressing it opens
    # the full error dialog. This is upstream's spad-thrown path.
    def throw_spad(title:, body:, content: nil, error: nil, flags: [])
      Adwaita::Toast.new(title).tap do |t|
        t.button_label = p_('toast-button', '_Details')
        t.signal_connect('button-clicked') do
          Spad.new(title: title, body: body, content: content,
                   error: error, flags: flags).present(root)
        end
        toast_overlay.add_toast(t)
      end
    end

    def zoom(direction)
      direction == :in ? @settings.increase_scale : @settings.decrease_scale
    end

    # Pages installs a listener here so it can flash the header bar and mark the
    # tab as needing attention when it is not the visible one.
    attr_writer :on_bell

    # Window listens here to keep its find button in step with the search bar.
    attr_writer :on_search_change

    def bell = @on_bell&.call
  end
end
