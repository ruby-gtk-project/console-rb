# frozen_string_literal: true

module ConsoleRb
  # The terminal window: header bar, tab bar, tab overview and the win.* actions.
  class Window
    include I18n

    STATUS_CLASSES = { privileged: 'root', remote: 'remote', playbox: 'playbox' }.freeze

    def initialize(application:, settings:, watcher:, on_new_window:, on_new_tab:)
      @application = application
      @settings = settings
      @watcher = watcher
      @on_new_window = on_new_window
      @on_new_tab = on_new_tab
    end

    def build
      window.tap do |win|
        win.insert_action_group('win', actions)
        win.content = tab_overview

        tab_overview.tap do |overview|
          overview.view = pages.tab_view
          overview.child = fullscreen_box_widget
          overview.signal_connect('create-tab') { create_tab }
        end

        fullscreen_box_widget.tap do |box|
          box.content = content_stack
          box.add_top_bar(header_bar)
          box.add_top_bar(tab_bar)

          content_stack.tap do |stack|
            stack.add_named(pages.build, 'content')
            stack.add_named(empty.build, 'empty')
          end

          header_bar.tap do |bar|
            bar.title_widget = window_title
            bar.pack_start(find_button)
            bar.pack_end(menu_button)
            bar.pack_end(tab_button)
            bar.pack_end(new_tab_button)
            bar.pack_end(unfullscreen_button)
          end

          tab_bar.view = pages.tab_view
          wire_extra_drop_targets
          track_decoration_layout
        end

        find_button.signal_connect('toggled') do
          pages.selected_tab&.search_mode_enabled = find_button.active? unless @syncing_find
        end

        win.insert_action_group('tab', tab_actions)
        win.add_breakpoint(narrow_breakpoint)
        win.signal_connect('notify::fullscreened') { fullscreened_changed }
        win.signal_connect('close-request') { close_requested }
        win.signal_connect('realize') { track_floating_state }
        # `devel` (kgx-window.c:672-674) is gated on an `IS_DEVEL` compile-time
        # flag that only exists for upstream's separate Devel build profile
        # (app id `org.gnome.Console.Devel`). This port ships a single
        # profile under `org.gnome.Console.Rb` with no devel counterpart, so
        # there is no condition to key the class off without inventing a
        # second profile — left out rather than hard-coded to a constant
        # value, which would just be a dead `add_css_class` call.
      end

      # kgx-window.c:kgx_window_init binds self into a GtkWindowGroup so this
      # window's modal dialogs (the close confirmation, the paste prompt) do
      # not block input to any other window in the application.
      Gtk::WindowGroup.new.add_window(window)

      menu_popover.add_child(theme_switcher.build, 'theme-switcher')
      menu_popover.add_child(zoom_controls, 'zoom-controls')

      @settings.on_change { refresh_zoom_label }
      refresh_zoom_label
      refresh_title
      window
    end

    def present = window.present

    # --- Actions -------------------------------------------------------------

    def actions
      @actions ||= Gio::SimpleActionGroup.new.tap do |group|
        {
          'find' => -> { toggle_search },
          'new-window' => -> { @on_new_window.call(self) },
          'new-tab' => -> { @on_new_tab.call(self) },
          'close-tab' => -> { pages.close_selected_page },
          'about' => -> { AboutDialog.new(root: window).present(window) },
          'show-tabs' => -> { tab_overview.open = true },
          'show-tabs-desktop' => -> { tab_overview.open = true },
          'show-preferences-window' => -> { PreferencesDialog.new(settings: @settings).present(window) },
          'fullscreen' => -> { window.fullscreen },
          'unfullscreen' => -> { window.unfullscreen },
          'detach-tab' => -> { pages.detach_selected_page }
        }.each do |name, handler|
          group.add_action(
            Gio::SimpleAction.new(name).tap do |action|
              action.signal_connect('activate') { handler.call }
            end
          )
        end
      end
    end

    # kgx-window.c:678-685 — a file (or text) dragged over the tab bar or the
    # tab overview, not onto the terminal itself, is still accepted: it is
    # typed at the prompt of whichever tab it lands on. Only the tab bar's
    # drop is actually routed anywhere (kgx-window.ui:265, `extra_drag_drop`
    # -> `kgx_tab_extra_drop`); the overview's own `setup_extra_drop_target`
    # call registers the accepted types without a handler to route the drop
    # to, upstream's own documented limitation ("this unfortunately doesn't
    # allow us to workaround the portal situation") rather than a gap this
    # port introduced.
    EXTRA_DROP_TYPES = [Gdk::FileList.gtype, Gio::File.gtype, GLib::Type::STRING].freeze

    def wire_extra_drop_targets
      tab_bar.setup_extra_drop_target(:copy, EXTRA_DROP_TYPES)
      tab_bar.signal_connect('extra-drag-drop') { |_bar, page, value| extra_drag_drop(page, value) }
      tab_overview.setup_extra_drop_target(:copy, EXTRA_DROP_TYPES)
    end

    # kgx-window.ui:256-264 + kgx-utils.c's kgx_decoration_layout_is_inverted:
    # the tab bar (and the tab overview, bound to it) mirror onto whichever
    # side the window controls actually render — "close" appearing more times
    # on the left half of `gtk-decoration-layout` than the right means the
    # window is left-handed, so the tabs flip too.
    def track_decoration_layout
      gtk_settings = Gtk::Settings.get_for_display(window.display)
      gtk_settings.signal_connect('notify::gtk-decoration-layout') { sync_tab_bar_inverted(gtk_settings) }
      sync_tab_bar_inverted(gtk_settings)
    end

    def sync_tab_bar_inverted(gtk_settings)
      tab_bar.inverted = decoration_layout_inverted?(gtk_settings.gtk_decoration_layout)
      tab_overview.inverted = tab_bar.inverted?
    end

    def decoration_layout_inverted?(layout)
      if layout.to_s.empty?
        false
      else
        left, right = layout.split(':', 2)
        left.to_s.scan('close').size > right.to_s.scan('close').size
      end
    end

    def extra_drag_drop(page, value)
      pages.tab_for(page)&.then do |tab|
        tab.extra_drop(value.value)
      end
      true
    end

    # kgx-window.c installs `tab.close`/`tab.detach` as parameterless widget
    # actions (kgx-window.c:590-591) that act on `Pages#action_page` — the page
    # a context menu was last opened against, set from AdwTabView's
    # `setup-menu` signal — falling back to the selected page when nothing set
    # it (kgx-pages.c:901-916, 922-937). Building the tab overview's own
    # context menu for these is left for next round (see PORTING.md); the
    # action group and the fallback-to-selected behaviour, which is exactly
    # what upstream falls back to before any menu has ever been opened, are
    # implemented here.
    def tab_actions
      @tab_actions ||= Gio::SimpleActionGroup.new.tap do |group|
        {
          'close' => -> { pages.close_action_page },
          'detach' => -> { pages.detach_action_page }
        }.each do |name, handler|
          group.add_action(
            Gio::SimpleAction.new(name).tap do |action|
              action.signal_connect('activate') { handler.call }
            end
          )
        end
      end
    end

    # kgx-window.ui:55-62 binds `translucent` to `settings.transparency AND
    # self.floating`, where "floating" is GDK's own name for "not maximized,
    # not tiled to an edge, not fullscreen" (state_to_floating,
    # kgx-window.c:634-651). `notify::fullscreened` already exists; this adds
    # the maximized/tiled half via the realized surface's own state, which is
    # the only place GTK exposes tiling.
    def track_floating_state
      window.surface.signal_connect('notify::state') { refresh_translucent }
      window.signal_connect('notify::fullscreened') { refresh_translucent }
      window.signal_connect('notify::maximized') { refresh_translucent }
      refresh_translucent
    end

    # The surface goes away on unrealize (e.g. while the window is being
    # destroyed) before the `notify::state` handler that reads it has been
    # disconnected, so this has to tolerate a nil surface rather than assume
    # the realize->unrealize pairing already took the handler with it.
    def floating?
      window.surface&.state&.then do |state|
        !(state.maximized? || state.fullscreen? || state.tiled? ||
          state.top_tiled? || state.right_tiled? || state.bottom_tiled? || state.left_tiled?)
      end || false
    end

    def refresh_translucent
      if @settings.transparency? && floating?
        window.add_css_class('translucent')
      else
        window.remove_css_class('translucent')
      end
    end

    # Upstream makes `win.find` a property action bound to the window's
    # search-mode-enabled property. A stateful GSimpleAction is the closest
    # equivalent here, but calling set_state from inside its own change-state
    # handler re-enters through the bindings and crashes, so the action stays
    # stateless and the toggle button carries the state instead.
    def toggle_search
      pages.selected_tab.then do |tab|
        tab && (tab.search_mode_enabled = !tab.search_mode_enabled)
      end
    end

    # Fired when the search bar opens or closes by any route — the action, the
    # button, or Escape inside the bar — so the button never drifts out of sync.
    def search_mode_changed(enabled)
      @syncing_find = true
      find_button.active = enabled
      @syncing_find = false
    end

    def create_tab
      @on_new_tab.call(self)
      pages.tab_view.selected_page
    end

    def close_requested
      if pages.busy_commands.empty? || @settings.always_stop_train?
        pages.close_all
        false
      else
        confirm_close
        true
      end
    end

    def confirm_close
      CloseDialog.new(
        context: :window,
        commands: pages.busy_commands,
        on_close: -> { force_close }
      ).present(window)
    end

    def force_close
      pages.close_all
      @force_close = true
      window.destroy
    end

    # --- State ---------------------------------------------------------------

    def fullscreened_changed
      window.fullscreened?.then do |fullscreen|
        header_bar.show_start_title_buttons = !fullscreen
        header_bar.show_end_title_buttons = !fullscreen
        tab_overview.show_start_title_buttons = !fullscreen
        tab_overview.show_end_title_buttons = !fullscreen
        unfullscreen_button.visible = fullscreen
        fullscreen_box.fullscreen = fullscreen
      end
    end

    def status_changed
      refresh_title
      STATUS_CLASSES.each do |flag, css_class|
        if pages.current_status.include?(flag)
          window.add_css_class(css_class)
        else
          window.remove_css_class(css_class)
        end
      end
    end

    # The bell flashes the header bar via a CSS animation; the class has to come
    # back off again or the animation only ever plays once.
    def ring
      window.add_css_class('bell')
      GLib::Timeout.add(600) do
        window.remove_css_class('bell')
        GLib::Source::REMOVE
      end
    end

    def content_empty(empty_now)
      content_stack.visible_child_name = empty_now ? 'empty' : 'content'
      refresh_title
    end

    def refresh_title
      window.title = pages.current_title || _('Console')
      window_title.title = window.title
      window_title.subtitle = pages.current_path&.path.to_s
    end

    def refresh_zoom_label
      zoom_label.label = format('%d%%', (@settings.font_scale * 100).round)
    end

    # --- Widgets -------------------------------------------------------------

    # The skill's quirks reference calls Adwaita::ApplicationWindow broken and
    # says to use Gtk::ApplicationWindow instead. That is out of date for
    # adwaita 4.3.8: it constructs and works here, and it is required — this
    # window needs `content=` and `add_breakpoint`, neither of which
    # Gtk::ApplicationWindow has. See PORTING.md.
    def window
      @window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
        win.width_request = 360
        win.height_request = 294
        win.add_css_class('terminal-window')
      end
    end

    def pages
      @pages ||= Pages.new(
        settings: @settings,
        watcher: @watcher,
        on_zoom: ->(direction) { direction },
        on_status_change: -> { status_changed },
        on_bell: -> { ring if @settings.visual_bell? },
        on_empty: ->(empty_now) { content_empty(empty_now) },
        on_create_tearoff_host: -> { @on_new_window.call(self).pages },
        on_search_change: ->(enabled) { search_mode_changed(enabled) }
      )
    end

    def tab_overview
      @tab_overview ||= Adwaita::TabOverview.new.tap do |overview|
        overview.enable_new_tab = true
        overview.secondary_menu = secondary_menu
      end
    end

    def fullscreen_box = @fullscreen_box ||= FullscreenBox.new

    def fullscreen_box_widget = @fullscreen_box_widget ||= fullscreen_box.build

    def content_stack = @content_stack ||= Gtk::Stack.new

    def empty = @empty ||= Empty.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def tab_bar = @tab_bar ||= Adwaita::TabBar.new

    def window_title = @window_title ||= Adwaita::WindowTitle.new('Console', '')

    def find_button
      @find_button ||= Gtk::ToggleButton.new.tap do |button|
        button.focus_on_click = false
        button.tooltip_text = _('Find in Terminal')
        button.icon_name = 'edit-find-symbolic'
      end
    end

    def unfullscreen_button
      @unfullscreen_button ||= Gtk::Button.new.tap do |button|
        button.visible = false
        button.can_focus = false
        button.receives_default = false
        button.icon_name = 'view-restore-symbolic'
        button.tooltip_text = _('Leave Fullscreen')
        button.action_name = 'win.unfullscreen'
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.focus_on_click = false
        button.tooltip_text = _('Main Menu')
        button.icon_name = 'open-menu-symbolic'
        button.popover = menu_popover
      end
    end

    def menu_popover
      @menu_popover ||= Gtk::PopoverMenu.new(primary_menu).tap do |popover|
        # Upstream binds autohide to this popover's visibility, inverted: the
        # top bars must not slide away in fullscreen while the main menu is
        # open above them (kgx-window.ui:82-83).
        popover.signal_connect('notify::visible') { fullscreen_box.autohide = !popover.visible? }
      end
    end

    def tab_button
      @tab_button ||= Adwaita::TabButton.new.tap do |button|
        button.visible = false
        button.action_name = 'win.show-tabs'
        button.view = pages.tab_view
      end
    end

    def new_tab_button
      @new_tab_button ||= Gtk::Button.new.tap do |button|
        button.focus_on_click = false
        button.action_name = 'win.new-tab'
        button.tooltip_text = _('New Tab')
        button.icon_name = 'tab-new-symbolic'
      end
    end

    def theme_switcher = @theme_switcher ||= ThemeSwitcher.new(settings: @settings)

    def zoom_controls
      @zoom_controls ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.homogeneous = true
        box.margin_top = 3
        box.margin_bottom = 3
        box.append(zoom_out_button)
        box.append(zoom_reset_button)
        box.append(zoom_in_button)
      end
    end

    def zoom_out_button
      @zoom_out_button ||= Gtk::Button.new.tap do |button|
        button.action_name = 'app.zoom-out'
        button.icon_name = 'zoom-out-symbolic'
        button.tooltip_text = _('Shrink Text')
        button.halign = :center
        button.add_css_class('circular')
        button.add_css_class('flat')
      end
    end

    def zoom_in_button
      @zoom_in_button ||= Gtk::Button.new.tap do |button|
        button.action_name = 'app.zoom-in'
        button.icon_name = 'zoom-in-symbolic'
        button.tooltip_text = _('Enlarge Text')
        button.halign = :center
        button.add_css_class('circular')
        button.add_css_class('flat')
      end
    end

    def zoom_reset_button
      @zoom_reset_button ||= Gtk::Button.new.tap do |button|
        button.action_name = 'app.zoom-normal'
        button.tooltip_text = _('Reset Size')
        button.halign = :center
        button.add_css_class('flat')
        button.add_css_class('numeric')
        button.child = zoom_label
      end
    end

    def zoom_label
      @zoom_label ||= Gtk::Label.new.tap do |label|
        label.width_chars = 5
      end
    end

    # Below 400px the tab bar is replaced by the overview button, as upstream's
    # breakpoint does.
    def narrow_breakpoint
      @narrow_breakpoint ||= Adwaita::Breakpoint.new(
        Adwaita::BreakpointCondition.parse('max-width: 400px')
      ).tap do |breakpoint|
        breakpoint.add_setter(tab_button, 'visible', true)
        breakpoint.add_setter(new_tab_button, 'visible', false)
        breakpoint.add_setter(tab_bar, 'visible', false)
        # The setters above cover the property flips a <setter> block does in
        # upstream's .ui. "Show All Tabs" staying in the primary menu while
        # narrow, and the overview failing to close again once the window
        # widens past the breakpoint, are the two behaviours that only run
        # from the `apply`/`unapply` signals, not from a property binding.
        breakpoint.signal_connect('apply') { narrow_breakpoint_applied }
        breakpoint.signal_connect('unapply') { narrow_breakpoint_unapplied }
      end
    end

    def narrow_breakpoint_applied
      actions.lookup_action('show-tabs-desktop').enabled = false
    end

    def narrow_breakpoint_unapplied
      actions.lookup_action('show-tabs-desktop').enabled = true
      tab_overview.open = false
    end

    # --- Menus ---------------------------------------------------------------

    def primary_menu
      @primary_menu ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, Gio::Menu.new.tap { |s| s.append_item(custom_item('theme-switcher')) })
        menu.append_section(nil, Gio::Menu.new.tap { |s| s.append_item(custom_item('zoom-controls')) })
        menu.append_section(nil, Gio::Menu.new.tap { |s| s.append(_('_New Window'), 'win.new-window') })
        menu.append_section(nil, Gio::Menu.new.tap do |section|
          section.append(_('_Show All Tabs'), 'win.show-tabs-desktop')
          section.append(_('_Fullscreen'), 'win.fullscreen')
        end)
        menu.append_section(nil, Gio::Menu.new.tap do |section|
          section.append(_('_Preferences'), 'win.show-preferences-window')
          section.append(_('_Keyboard Shortcuts'), 'app.shortcuts')
          section.append(_('_About Console'), 'win.about')
        end)
      end
    end

    def secondary_menu
      @secondary_menu ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, Gio::Menu.new.tap { |s| s.append(_('_New Window'), 'win.new-window') })
        menu.append_section(nil, Gio::Menu.new.tap do |section|
          section.append(_('_Fullscreen'), 'win.fullscreen')
          section.append(_('Leave _Fullscreen'), 'win.unfullscreen')
        end)
      end
    end

    def custom_item(name)
      Gio::MenuItem.new.tap do |item|
        item.set_attribute_value('custom', GLib::Variant.new(name))
      end
    end
  end
end
