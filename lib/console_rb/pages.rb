# frozen_string_literal: true

module ConsoleRb
  # Owns the AdwTabView and the mapping from tab pages back to Tab objects.
  # Everything about closing a tab — the "still running" prompt, the detach and
  # the "last tab closed so close the window" rule — lives here.
  class Pages
    include I18n

    attr_reader :settings

    def initialize(settings:, watcher:, on_zoom:, on_status_change:, on_bell:,
                   on_empty:, on_create_tearoff_host:, on_search_change:)
      @settings = settings
      @watcher = watcher
      @on_zoom = on_zoom
      @on_status_change = on_status_change
      @on_bell = on_bell
      @on_empty = on_empty
      @on_create_tearoff_host = on_create_tearoff_host
      @on_search_change = on_search_change
      @tabs = {}
    end

    def build
      tab_view.tap do |view|
        view.signal_connect('close-page') { |_view, page| close_page_requested(page) }
        view.signal_connect('create-window') { create_tearoff_host }
        view.signal_connect('notify::selected-page') { selection_changed }
        view.signal_connect('page-attached') { |_view, _page, _pos| selection_changed }
        view.signal_connect('page-detached') { |_view, _page, _pos| pages_changed }
        view.signal_connect('setup-menu') { |_view, page| @action_page = page }
      end
    end

    def tab_view
      @tab_view ||= Adwaita::TabView.new.tap do |view|
        view.menu_model = tab_menu
        view.default_icon = Gio::ThemedIcon.new('status-regular-symbolic')
      end
    end

    # kgx-pages.ui's `tab-menu`: the context menu AdwTabView opens for a
    # right-clicked tab, acting on whichever page `setup-menu` just recorded.
    def tab_menu
      @tab_menu ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, Gio::Menu.new.tap { |s| s.append(_('_Detach Tab'), 'tab.detach') })
        menu.append_section(nil, Gio::Menu.new.tap { |s| s.append(_('_Close'), 'tab.close') })
      end
    end

    # --- Adding and removing -------------------------------------------------

    def add(tab)
      tab.build.then do |widget|
        tab_view.append(widget).tap do |page|
          @tabs[widget] = { tab: tab, page: page }
          tab.on_change { refresh(tab) }
          tab.on_bell = -> { rang(tab, page) }
          tab.on_search_change = ->(enabled) { @on_search_change.call(enabled) }
          tab.on_died = ->(dead, should_close) { tab_died(dead, should_close) }
          refresh(tab)
          tab_view.selected_page = page
          tab.start
          tab.focus
        end
      end
    end

    def tab_for(page) = page && @tabs.dig(page.child, :tab)

    def page_for(tab) = @tabs.dig(tab.root, :page)

    def selected_tab = tab_for(tab_view.selected_page)

    def focus(tab)
      page_for(tab)&.then { |page| tab_view.selected_page = page }
      tab.focus
    end

    def tab_count = tab_view.n_pages

    def tabs = @tabs.each_value.map { |entry| entry[:tab] }

    def refresh(tab)
      page_for(tab)&.then do |page|
        # Neither string setter accepts nil in the bindings.
        page.title = tab.display_title.to_s
        page.tooltip = tab.tooltip.to_s
        page.keyword = keyword_for(tab).to_s
        page.loading = tab.working?
        page.icon = status_icon_for(tab)
        page.indicator_icon = ringing_icon_for(tab)
      end
      @on_status_change.call
    end

    # A remote, sandboxed or privileged session gets a badge on its tab so it is
    # recognisable in the overview even when the header bar colour is not shown.
    # The icons and the order they are tested in are upstream's kgx_status_as_icon.
    STATUS_ICONS = { remote: 'status-remote-symbolic',
                     playbox: 'status-playbox-symbolic',
                     privileged: 'status-privileged-symbolic' }.freeze

    def status_icon_for(tab)
      STATUS_ICONS.find { |flag, _icon| tab.status.include?(flag) }
                  &.then { |_flag, icon| Gio::ThemedIcon.new(icon) }
    end

    # kgx_ringing_as_icon: the bell flash that briefly replaces the tab's
    # indicator while Tab#ringing? is true (see Tab#bell).
    def ringing_icon_for(tab)
      Gio::ThemedIcon.new('bell-outline-symbolic') if tab.ringing?
    end

    # kgx_file_as_display: the local path only, nil (never the URI) for a
    # remote cwd — what makes the tab overview's search find a tab by directory.
    def keyword_for(tab)
      tab.path&.path
    end

    # A shell that exited on its own takes its tab with it, matching upstream.
    # A tab opened for an explicit command stays, showing the read-only banner.
    def tab_died(tab, should_close)
      page_for(tab)&.then { |page| tab_view.close_page(page) if should_close }
    end

    def rang(_tab, page)
      page.needs_attention = true unless tab_view.selected_page == page
      @on_bell.call
    end

    def selection_changed
      pages_changed
      @on_status_change.call
      tab_view.selected_page&.needs_attention = false
      @on_search_change.call(selected_tab&.search_mode_enabled || false)
      selected_tab&.focus unless selected_tab&.search_mode_enabled
    end

    def pages_changed
      @on_empty.call(tab_count.zero?)
    end

    # --- Status --------------------------------------------------------------

    def current_status = selected_tab&.status || []

    def current_path = selected_tab&.path

    def current_title = selected_tab&.display_title

    def working_directory = current_path

    # --- Closing -------------------------------------------------------------

    def close_selected_page
      tab_view.selected_page&.then { |page| tab_view.close_page(page) }
    end

    def detach_selected_page
      selected_tab&.then { |tab| detach_page(tab) }
    end

    # win.detach-tab and the `tab.detach` action group (tab overview context
    # menu) both move a tab to a brand-new window; this is the shared move
    # itself, whichever tab the caller names.
    def detach_page(tab)
      page_for(tab)&.then do |page|
        @on_create_tearoff_host.call.then do |host|
          tab_view.transfer_page(page, host.tab_view, 0)
        end
      end
    end

    # kgx_pages_close_page / kgx_pages_detach_page: act on `action_page`,
    # falling back to the selected page when no context menu set it.
    def close_action_page
      (@action_page || tab_view.selected_page)&.then { |page| tab_view.close_page(page) }
    end

    def detach_action_page
      tab_for(@action_page || tab_view.selected_page)&.then { |tab| detach_page(tab) }
    end

    # AdwTabView expects an async confirmation: returning true here defers the
    # close until close_page_finish is called with the user's answer.
    def close_page_requested(page)
      tab_for(page).then do |tab|
        if tab.nil? || tab.close_safely? || @settings.always_stop_train?
          finish_close(page, tab, true)
        else
          confirm_close(page, tab)
        end
      end
      true
    end

    def confirm_close(page, tab)
      CloseDialog.new(
        context: :tab,
        commands: tab.running_commands,
        on_close: -> { finish_close(page, tab, true) }
      ).tap do |dialog|
        dialog.dialog.signal_connect('response') do |_dialog, response|
          finish_close(page, tab, false) if response != 'close'
        end
        dialog.present(tab_view)
      end
    end

    def finish_close(page, tab, confirmed)
      tab&.close if confirmed
      @tabs.delete(page.child) if confirmed
      tab_view.close_page_finish(page, confirmed)
      pages_changed
    end

    # Closing a window means confirming once for every tab that is still busy,
    # rather than once per tab in sequence.
    def busy_commands = tabs.flat_map(&:running_commands)

    def close_all
      tabs.each(&:close)
    end
  end
end
