# frozen_string_literal: true

module ConsoleRb
  # Ported from src/kgx-tab.c.
  #
  # The parts of a terminal session that do not depend on how the shell got
  # started: the search bar, the terminal itself, the banner that appears when
  # the child process exits and the tab goes read-only, and the toast overlay
  # errors surface in. Starting a process is a subclass's job — see SimpleTab,
  # which is the only kind of tab this port has, exactly as upstream.
  class Tab
    include I18n
    include SpadSource

    @next_id = 0

    class << self
      attr_accessor :next_id

      # One sequence shared by every kind of tab: app.focus-page addresses tab
      # ids globally, so a subclass must not start counting again from one.
      def allocate_id = Tab.next_id += 1
    end

    attr_reader :id, :title, :path, :train, :status

    def initialize(settings:, watcher:, despatcher: Despatcher.new, tab_title: nil,
                   close_on_quit: true)
      @id = self.class.allocate_id
      @settings = settings
      @watcher = watcher
      @despatcher = despatcher
      @title = tab_title
      @explicit_title = !tab_title.nil?
      @close_on_quit = close_on_quit
      @status = []
      @listeners = []
      @exit_listeners = []
      @working = true
      @ringing = false
    end

    # kgx-tab.c's `working` and `ringing` properties: whether the shell has
    # started yet, and whether the bell flash (bell-outline-symbolic on the
    # tab) is currently showing. Both back Pages#refresh's AdwTabPage bindings.
    def working? = @working

    def ringing? = @ringing

    RINGING_RESET_DELAY = 500

    def on_change(&block) = @listeners << block

    # Fired once when the tab's child process has gone, which is what --wait
    # waits on.
    def on_exit(&block) = @exit_listeners << block

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

      # The terminal is a spad source in its own right; the tab is what has a
      # toast overlay to show one in, so it takes the terminal's errors too.
      terminal.on_spad_thrown { |title, bundle| show_spad(title, bundle) }
      on_spad_thrown { |title, bundle| show_spad(title, bundle) }

      drop_target.tap do |drop|
        drop.widget = root
        terminal.terminal.add_controller(drop.build)
      end

      root
    end

    # --- Lifecycle -----------------------------------------------------------

    # Called by a subclass's #start once the depot has a live process. The train
    # is already registered with the watcher by then.
    def started(train)
      @working = false
      empty.working = false
      stack.visible_child = terminal_scroller
      @train = train.tap do |t|
        t.on_change { |flags| status_changed(flags) }
      end
      notify
    end

    def status_changed(flags)
      @status = flags
      notify
    end

    # `success` distinguishes a child that ran and then exited from one that never
    # started. Only the former closes the tab, and only when this tab was opened
    # for a plain shell rather than for an explicit command.
    def died(type, message, success: true)
      exit_message.markup = message
      mark_exit_error(type == :error)
      exit_revealer.reveal_child = true
      @train&.then { |train| @watcher.unwatch(train) }
      @train = nil
      notify
      @exit_listeners.each(&:call)
      @exit_listeners = []
      @on_died&.call(self, success && @close_on_quit)
    end

    def mark_exit_error(errored)
      if errored
        exit_revealer.add_css_class('error')
      else
        exit_revealer.remove_css_class('error')
      end
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

    def close = @train&.then { |train| @watcher.unwatch(train) }

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
    # kgx_tab_extra_drop (kgx-tab.c:1167-1177): a file dropped on this tab's
    # row in the tab bar, rather than directly on its terminal, is handled
    # exactly the same way — typed at the prompt.
    def extra_drop(value) = drop_target.dropped(value)

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
        despatcher: @despatcher,
        on_zoom: ->(direction) { zoom(direction) },
        on_bell: -> { bell },
        on_child_exit: ->(status) { child_exited(status) },
        on_path_change: ->(path) { path_changed(path) }
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
        entry.add_controller(search_entry_shortcuts)
      end
    end

    # `kgx-tab.ui:47-63`: GtkSearchEntry does not bind Return/Shift+Return to
    # its own next-match/previous-match signals, so a capture-phase
    # GtkShortcutController does it explicitly, same as upstream.
    SEARCH_ENTRY_SHORTCUTS = {
      'Return' => 'next-match',
      '<Shift>Return' => 'previous-match'
    }.freeze

    def search_entry_shortcuts
      @search_entry_shortcuts ||= Gtk::ShortcutController.new.tap do |controller|
        controller.propagation_phase = :capture

        SEARCH_ENTRY_SHORTCUTS.each do |accelerator, signal|
          Shortcuts.trigger(accelerator)&.then do |trigger|
            controller.add_shortcut(Gtk::Shortcut.new(trigger, Gtk::SignalAction.new(signal)))
          end
        end
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
      retitle(path)
      notify
    end

    # An explicit --title is never overwritten by the shell's working directory.
    def retitle(path)
      if @explicit_title
        nil
      else
        path&.path&.then { |local| @title = File.basename(local) }
      end
    end

    def display_title
      @title || terminal.terminal.window_title || _('Console')
    end

    # Upstream binds the tooltip through kgx_file_as_display_or_uri: the local
    # path when there is one, the whole uri when the cwd is remote.
    def tooltip = @path&.then { |file| file.path || file.uri }

    def toast(message) = toast_overlay.add_toast(Adwaita::Toast.new(message))

    # The tab's own handler for the spad-thrown contract: a toast carrying a
    # "Details" button, which opens the full error dialog. Returning true is
    # what tells the thrower the error was taken.
    def show_spad(title, bundle)
      Adwaita::Toast.new(title).tap do |t|
        t.button_label = p_('toast-button', '_Details')
        t.signal_connect('button-clicked') do
          Spad.new(**bundle).present(root)
        end
        toast_overlay.add_toast(t)
      end
      true
    end

    def zoom(direction)
      direction == :in ? @settings.increase_scale : @settings.decrease_scale
    end

    # Pages installs a listener here so it can flash the header bar and mark the
    # tab as needing attention when it is not the visible one.
    attr_writer :on_bell

    # Pages installs this to close the tab once its shell has exited.
    attr_writer :on_died

    # Window listens here to keep its find button in step with the search bar.
    attr_writer :on_search_change

    # kgx_tab_bell: the needs-attention flag is unconditional; the ringing
    # flash (what Pages#refresh turns into the bell-outline indicator icon)
    # only happens when the visual bell setting is on, and clears itself
    # after 500ms same as upstream's own g_timeout_add_once.
    def bell
      if @settings.visual_bell?
        @ringing = true
        notify
        GLib::Timeout.add(RINGING_RESET_DELAY) do
          @ringing = false
          notify
          GLib::Source::REMOVE
        end
      end
      @on_bell&.call
    end
  end
end
