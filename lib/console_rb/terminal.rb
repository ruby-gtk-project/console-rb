# frozen_string_literal: true

module ConsoleRb
  # The VTE widget plus everything bolted onto it: link matching, the context
  # menu, the term.* action group, zoom-on-ctrl-scroll and palette application.
  class Terminal
    # Link regexes adapted, as upstream's are, from Pantheon Terminal.
    USERCHARS = '-[:alnum:]'
    USERCHARS_CLASS = "[#{USERCHARS}]".freeze
    PASSCHARS_CLASS = '[-[:alnum:]\\Q,?;.:/!%$^*&~"#\'\\E]'
    HOSTCHARS_CLASS = '[-[:alnum:]]'
    HOST = "#{HOSTCHARS_CLASS}+(\\.#{HOSTCHARS_CLASS}+)*".freeze
    PORT = '(?:\\:[[:digit:]]{1,5})?'
    PATHCHARS_CLASS = '[-[:alnum:]\\Q_$.+!*,;:@&=?/~#%\\E]'
    PATHTERM_CLASS = '[^\\Q]\'.}>) \t\r\n,"\\E]'
    SCHEME = '(?:news:|telnet:|nntp:|file:\\/|https?:|ftps?:|sftp:|webcal:' \
             '|irc:|sftp:|ldaps?:|nfs:|smb:|rsync:|' \
             'ssh:|rlogin:|telnet:|git:' \
             '|git\\+ssh:|bzr:|bzr\\+ssh:|svn:|svn\\+ssh:|hg:|mailto:|magnet:)'
    USERPASS = "#{USERCHARS_CLASS}+(?:#{PASSCHARS_CLASS}+)?".freeze
    URLPATH = "(?:(/#{PATHCHARS_CLASS}+(?:[(]#{PATHCHARS_CLASS}*[)])*" \
              "#{PATHCHARS_CLASS}*)*#{PATHTERM_CLASS})?".freeze

    LINK_REGEXES = [
      "#{SCHEME}//(?:#{USERPASS}\\@)?#{HOST}#{PORT}#{URLPATH}",
      "(?:www|ftp)#{HOSTCHARS_CLASS}*\\.#{HOST}#{PORT}#{URLPATH}",
      "(?:callto:|h323:|sip:)#{USERCHARS_CLASS}[#{USERCHARS}.]*(?:#{PORT}/[a-z0-9]+)?\\@#{HOST}",
      "(?:mailto:)?#{USERCHARS_CLASS}[#{USERCHARS}.]*\\@#{HOSTCHARS_CLASS}+\\.#{HOST}",
      '(?:news:|man:|info:)[-[:alnum:]\\Q^_{|}~!"#$%&\'()*+,./;:=?`\\E]+'
    ].freeze

    attr_reader :current_url, :path

    def initialize(settings:, on_zoom:, on_bell:, on_child_exit:, on_path_change:, on_notify:)
      @settings = settings
      @on_zoom = on_zoom
      @on_bell = on_bell
      @on_child_exit = on_child_exit
      @on_path_change = on_path_change
      @on_notify = on_notify
      @match_tags = []
    end

    def build
      terminal.tap do |term|
        term.insert_action_group('term', actions)
        term.context_menu_model = context_menu
        term.add_controller(shortcuts)
        term.add_controller(scroll_controller)

        add_link_matchers
        connect_zoom

        term.signal_connect('bell') { @on_bell.call }
        term.signal_connect('child-exited') { |_term, status| @on_child_exit.call(status) }
        term.signal_connect('selection-changed') { refresh_action_state }
        term.signal_connect('termprop-changed::vte.cwd') { location_changed }
        term.signal_connect('termprop-changed::vte.cwf') { location_changed }
        term.signal_connect('setup-context-menu') { |_term, context| prepare_context_menu(context) }
      end

      apply_settings
      @settings.on_change { apply_settings }
      refresh_action_state

      terminal
    end

    # --- Widgets -------------------------------------------------------------

    def terminal
      @terminal ||= Vte::Terminal.new.tap do |term|
        term.vexpand = true
        term.allow_hyperlink = true
        term.enable_fallback_scrolling = false
        term.scroll_unit_is_pixels = true
        term.has_tooltip = true
      end
    end

    TERMINAL_SHORTCUTS = {
      '<Shift><Primary>c' => 'term.copy',
      '<Shift><Primary>v' => 'term.paste',
      'Copy' => 'term.copy',
      'Paste' => 'term.paste'
    }.freeze

    # Capture phase, so these win over VTE's own key handling — the same reason
    # upstream attaches a controller here as well as app-level accelerators.
    def shortcuts
      @shortcuts ||= Gtk::ShortcutController.new.tap do |controller|
        controller.name = 'console-rb-terminal-shortcuts'
        controller.propagation_phase = :capture

        TERMINAL_SHORTCUTS.each do |accelerator, action|
          Shortcuts.trigger(accelerator)&.then do |trigger|
            controller.add_shortcut(Gtk::Shortcut.new(trigger, Gtk::NamedAction.new(action)))
          end
        end
      end
    end

    def scroll_controller
      @scroll_controller ||= Gtk::EventControllerScroll.new(%i[vertical discrete]).tap do |controller|
        controller.propagation_phase = :capture
      end
    end

    def context_menu
      @context_menu ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, link_section)
        menu.append_section(nil, clipboard_section)
        menu.append_section(nil, fullscreen_section)
        menu.append_section(nil, files_section)
      end
    end

    def link_section
      @link_section ||= Gio::Menu.new.tap do |section|
        section.append(_('_Open Link'), 'term.open-link')
        section.append(_('Copy _Link Address'), 'term.copy-link')
      end
    end

    def clipboard_section
      @clipboard_section ||= Gio::Menu.new.tap do |section|
        section.append(_('_Copy'), 'term.copy')
        section.append(_('_Paste'), 'term.paste')
        section.append(_('_Select All'), 'term.select-all')
      end
    end

    def fullscreen_section
      @fullscreen_section ||= Gio::Menu.new.tap do |section|
        section.append(_('Leave _Fullscreen'), 'win.unfullscreen')
      end
    end

    def files_section
      @files_section ||= Gio::Menu.new.tap do |section|
        section.append(_('Show in _Files'), 'term.show-in-files')
      end
    end

    def actions
      @actions ||= Gio::SimpleActionGroup.new.tap do |group|
        {
          'open-link' => -> { open_link },
          'copy-link' => -> { copy_link },
          'copy' => -> { copy },
          'paste' => -> { paste },
          'select-all' => -> { terminal.select_all },
          'show-in-files' => -> { show_in_files }
        }.each do |name, handler|
          group.add_action(
            Gio::SimpleAction.new(name).tap do |action|
              action.signal_connect('activate') { handler.call }
            end
          )
        end
      end
    end

    # --- Behaviour -----------------------------------------------------------

    # The zoom gesture is ctrl+scroll; without ctrl the event falls through to
    # VTE so the scrollback still scrolls.
    def connect_zoom
      scroll_controller.signal_connect('scroll') do |controller, _dx, dy|
        if controller.current_event_state.control_mask?
          @on_zoom.call(dy.negative? ? :in : :out)
          true
        else
          false
        end
      end
    end

    def add_link_matchers
      @match_tags = LINK_REGEXES.filter_map do |pattern|
        Regex.for_match(pattern, caseless: true)&.then do |regex|
          terminal.match_add_regex(regex, 0).tap do |tag|
            terminal.match_set_cursor_name(tag, 'pointer')
          end
        end
      end
    end

    def location_changed
      terminal.ref_termprop_uri(Vte::TERMPROP_CURRENT_FILE_URI).then do |file_uri|
        file_uri || terminal.ref_termprop_uri(Vte::TERMPROP_CURRENT_DIRECTORY_URI)
      end.then do |uri|
        @path = uri && Gio::File.new_for_uri(uri.to_s)
        @on_path_change.call(@path)
      end
    end

    # The link under the pointer decides whether the link menu items are shown,
    # so it has to be resolved before the menu is built.
    def prepare_context_menu(context)
      @current_url = url_at(context)
      refresh_action_state
      false
    end

    def url_at(context)
      context.coordinates.then do |ok, x, y|
        ok ? terminal.check_match_at(x, y)&.first : nil
      end
    rescue StandardError
      nil
    end

    def refresh_action_state
      { 'open-link' => !@current_url.nil?,
        'copy-link' => !@current_url.nil?,
        'copy' => terminal.has_selection?,
        'paste' => true,
        'select-all' => true,
        'show-in-files' => !@path.nil? }.each do |name, enabled|
        actions.lookup(name)&.enabled = enabled
      end
    end

    def copy
      terminal.copy_clipboard_format(Vte::Format::TEXT)
    end

    def copy_link
      @current_url.then { |url| terminal.clipboard.set(url) if url }
    end

    def paste
      terminal.clipboard.read_text_async(nil) do |clipboard, result|
        accept_paste(clipboard.read_text_finish(result))
      rescue StandardError => e
        @on_notify.call(_('Couldn’t Paste Text'), e.message)
      end
    end

    # Pasting a multi-line command that mentions sudo is the classic
    # clipboard-hijack shape, so it gets a confirmation first.
    def accept_paste(text)
      text.to_s.then do |content|
        if content.strip.empty?
          nil
        elsif content.include?('sudo') && content.include?("\n")
          confirm_paste(content)
        else
          terminal.paste_text(content)
        end
      end
    end

    def confirm_paste(text)
      Adwaita::AlertDialog.new(
        _('You are pasting a command that runs as an administrator'),
        format(_("Make sure you know what the command does:\n%s"), text.strip)
      ).tap do |dialog|
        dialog.add_response('cancel', _('_Cancel'))
        dialog.add_response('paste', _('_Paste'))
        dialog.set_response_appearance('paste', :destructive)
        dialog.close_response = 'cancel'
        dialog.signal_connect('response') do |_dialog, response|
          terminal.paste_text(text) if response == 'paste'
        end
        dialog.present(terminal)
      end
    end

    def open_link
      @current_url.then { |url| launch(url) if url }
    end

    def show_in_files
      @path.then { |file| launch(file.uri) if file }
    end

    def launch(uri)
      Gtk::UriLauncher.new(uri).launch(terminal.root, nil) do |launcher, result|
        launcher.launch_finish(result)
      rescue StandardError => e
        @on_notify.call(_('Couldn’t Open Link'), e.message)
      end
    end

    # --- Appearance ----------------------------------------------------------

    def apply_settings
      terminal.font_desc = @settings.font
      terminal.font_scale = @settings.font_scale
      terminal.scrollback_lines = @settings.scrollback_lines
      terminal.audible_bell = @settings.audible_bell?
      apply_palette
    end

    def apply_palette
      palette.then do |colours|
        terminal.set_colors(colours.foreground,
                            colours.background_with_transparency,
                            colours.colours)
      end
    end

    def palette
      @settings.livery.palette_for(resolved_theme).then do |colours|
        translucent? ? colours : colours.opaque
      end
    end

    def resolved_theme
      @settings.resolve_theme(Adwaita::StyleManager.default.dark?)
    end

    def translucent?
      @settings.transparency? && !terminal.root.nil?
    end

    def _(text) = text
  end
end
