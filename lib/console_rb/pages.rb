# frozen_string_literal: true

module ConsoleRb
  # Owns the AdwTabView and the mapping from tab pages back to Tab objects.
  # Everything about closing a tab — the "still running" prompt, the detach and
  # the "last tab closed so close the window" rule — lives here.
  class Pages
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
      end
    end

    def tab_view = @tab_view ||= Adwaita::TabView.new

    # --- Adding and removing -------------------------------------------------

    def add(tab)
      tab.build.then do |widget|
        tab_view.append(widget).tap do |page|
          @tabs[widget] = { tab: tab, page: page }
          tab.on_change { refresh(tab) }
          tab.on_bell = -> { rang(tab, page) }
          tab.on_search_change = ->(enabled) { @on_search_change.call(enabled) }
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

    def tab_count = tab_view.n_pages

    def tabs = @tabs.each_value.map { |entry| entry[:tab] }

    def refresh(tab)
      page_for(tab)&.then do |page|
        # Neither setter accepts nil in the bindings.
        page.title = tab.display_title.to_s
        page.tooltip = tab.tooltip.to_s
        page.indicator_icon = indicator_for(tab)
      end
      @on_status_change.call
    end

    # A remote or privileged session gets a badge on its tab so it is
    # recognisable in the overview even when the header bar colour is not shown.
    def indicator_for(tab)
      icon_name =
        if tab.status.include?(:privileged) then 'channel-secure-symbolic'
        elsif tab.status.include?(:remote) then 'network-server-symbolic'
        end
      icon_name && Gio::ThemedIcon.new(icon_name)
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
      tab_view.selected_page&.then do |page|
        @on_create_tearoff_host.call.then do |host|
          tab_view.transfer_page(page, host.tab_view, 0)
        end
      end
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
