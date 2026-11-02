# frozen_string_literal: true

module ConsoleRb
  # Ported from src/kgx-despatcher.c.
  #
  # Everything the terminal hands to the rest of the desktop goes through here:
  # opening a hyperlink with the default handler, and revealing the current
  # directory or file in the file manager.
  #
  # Two things make this more than a one-liner, and both are upstream's doing:
  #
  #  * #open retries once after mounting. A `file://` under an unmounted gvfs
  #    share fails with NOT_MOUNTED; upstream mounts the enclosing volume with a
  #    GtkMountOperation parented on the window, then opens again.
  #  * #show_item and #show_folder talk to org.freedesktop.FileManager1 rather
  #    than launching a file manager, so the file is selected rather than opened.
  #    Upstream uses a gdbus-codegen proxy; the generated wrapper has no Ruby
  #    equivalent, so the two methods are called straight down the session bus.
  #    The connection is cached for the same reason upstream caches its proxy.
  class Despatcher
    BUS_NAME = 'org.freedesktop.FileManager1'
    OBJECT_PATH = '/org/freedesktop/FileManager1'
    INTERFACE = 'org.freedesktop.FileManager1'
    CALL_TIMEOUT = -1

    # Each method takes the window so the mount prompt and the file manager's
    # own window can be parented correctly, and yields once with nil on success
    # or the error that stopped it.
    def open(uri, window, &block)
      Gio::AppInfo.launch_default_for_uri_async(uri.to_s, launch_context(window), nil) do |_source, result|
        Gio::AppInfo.launch_default_for_uri_finish(result)
        block&.call(nil)
      rescue Gio::IOError::NotMounted
        mount_then_open(uri, window, &block)
      rescue StandardError => e
        block&.call(e)
      end
    end

    # One retry only: the second attempt reports whatever it hits rather than
    # looping back into the mount, which is upstream's did_open_after_mount.
    def mount_then_open(uri, window, &block)
      Gio::File.new_for_uri(uri.to_s)
               .mount_enclosing_volume(:none, Gtk::MountOperation.new(window), nil) do |file, result|
        file.mount_enclosing_volume_finish(result)
        open_after_mount(uri, window, &block)
      rescue StandardError => e
        block&.call(e)
      end
    end

    def open_after_mount(uri, window, &block)
      Gio::AppInfo.launch_default_for_uri_async(uri.to_s, launch_context(window), nil) do |_source, result|
        Gio::AppInfo.launch_default_for_uri_finish(result)
        block&.call(nil)
      rescue StandardError => e
        block&.call(e)
      end
    end

    # A launch context carries the window's startup notification id, so the
    # opened app gets focus instead of demanding attention.
    def launch_context(window)
      window&.display&.app_launch_context
    rescue StandardError
      nil
    end

    def show_item(uri, _window, &) = call_file_manager('ShowItems', uri, &)

    def show_folder(uri, _window, &) = call_file_manager('ShowFolders', uri, &)

    # Both FileManager1 methods take (as uris, s startup_id). GLib::Variant.new
    # cannot build a tuple in the Ruby bindings, so the arguments are parsed
    # from text — see Settings#save_window_state for the same workaround.
    def arguments(uri)
      GLib::Variant.parse("(['#{escape(uri)}'], '')", '(ass)')
    end

    # The two characters that would end the string literal the variant is
    # parsed from. Both are legal in a uri only percent-encoded, and
    # percent-encoding them here leaves the uri meaning exactly the same.
    URI_ESCAPES = { '\\' => '%5C', "'" => '%27' }.freeze

    def escape(uri) = uri.to_s.gsub(/[\\']/, URI_ESCAPES)

    def call_file_manager(method, uri, &block)
      connection.then do |bus|
        if bus.nil?
          block&.call(bus_error)
        else
          bus.call(
            BUS_NAME,
            OBJECT_PATH,
            INTERFACE,
            method,
            arguments(uri),
            nil,
            :none,
            CALL_TIMEOUT,
            nil
          ) do |_source, result|
            bus.call_finish(result)
            block&.call(nil)
          rescue StandardError => e
            block&.call(e)
          end
        end
      end
    end

    # A desktop with no session bus is a normal situation, not a crash; the
    # caller turns the error into a toast.
    def bus_error = RuntimeError.new('no session bus is available')

    def connection
      @connection ||= Gio.bus_get_sync(:session)
    rescue StandardError => e
      warn "console-rb: despatcher: no session bus: #{e.message}"
      nil
    end
  end
end
