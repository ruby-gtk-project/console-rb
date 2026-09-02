# frozen_string_literal: true

module ConsoleRb
  # Dropping files onto the terminal types their shell-quoted paths at the
  # prompt; dropping text types the text. A file that has no local path (a
  # remote URI) is typed as its URI instead.
  class DropTarget
    def initialize(on_drop:)
      @on_drop = on_drop
    end

    def build
      target.tap do |drop|
        drop.signal_connect('drop') { |_target, value, _x, _y| dropped(value) }
        drop.signal_connect('enter') { highlight(true) }
        drop.signal_connect('leave') { highlight(false) }
      end
    end

    def controller = build

    # Accepts a file list, a single file, or plain text, in that order of
    # preference — the same set upstream registers.
    def target
      @target ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy).tap do |drop|
        drop.set_gtypes([Gdk::FileList.gtype, Gio::File.gtype, GLib::Type::STRING])
      end
    end

    attr_accessor :widget

    def highlight(active)
      widget&.then do |target_widget|
        if active
          target_widget.add_css_class('drop-highlight')
        else
          target_widget.remove_css_class('drop-highlight')
        end
      end
      false
    end

    def dropped(value)
      text_for(value).then do |text|
        highlight(false)
        text.nil? ? false : (@on_drop.call(text) || true)
      end
    end

    def text_for(value)
      case value
      when Gdk::FileList then join(value.files)
      when Gio::File then join([value])
      when String then value
      end
    rescue StandardError => e
      warn "console-rb: could not handle drop: #{e.message}"
      nil
    end

    def join(files) = files.map { |file| quote(file) }.join(' ')

    # A local path is shell-quoted so spaces and quotes survive; anything
    # without a local path is typed as its URI.
    def quote(file)
      file.path.then { |path| path ? Shellwords.escape(path) : file.uri }
    end
  end
end
