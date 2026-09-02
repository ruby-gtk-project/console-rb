# frozen_string_literal: true

module ConsoleRb
  # The "Error Details" dialog — upstream's KgxSpad. Errors surface first as a
  # toast with a "Details" button; pressing it opens this, which shows the
  # explanation, the copyable raw message, optionally the system info, and
  # optionally a button to file the bug.
  #
  # Flags mirror KgxSpadFlags: :show_report adds the report button, :show_sys_info
  # appends the debug block to the copyable message.
  class Spad
    include I18n

    COPY_ICON = 'edit-copy-symbolic'
    COPIED_ICON = 'object-select-symbolic'
    COPIED_RESET_DELAY = 2000

    def initialize(title:, body:, content: nil, error: nil, flags: [])
      @title = title
      @body = body
      @content = content
      @error = error
      @flags = flags
    end

    def present(parent)
      @parent = parent
      build.present(parent)
    end

    def build
      dialog.tap do |d|
        d.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = page
          view.add_bottom_bar(report_button) if @flags.include?(:show_report)

          page.tap do |p|
            p.add(explanation_group)
            p.add(message_group)

            message_group.tap do |group|
              group.header_suffix = copy_button
              group.add(message_frame)
            end
          end
        end

        copy_button.signal_connect('clicked') { copy_message }
        report_button.signal_connect('clicked') { open_issues }
      end
    end

    # The raw text the user can copy: the underlying error, plus the system
    # info block when the caller asked for it.
    def message_text
      [error_text, (SystemInfo.report(@parent&.root) if @flags.include?(:show_sys_info))]
        .compact
        .reject(&:empty?)
        .join("\n\n——————————\n")
    end

    def error_text = [@content, @error].compact.map(&:to_s).reject(&:empty?).join("\n")

    def copy_message
      dialog.clipboard.set(message_text)
      copy_button.icon_name = COPIED_ICON
      GLib::Timeout.add(COPIED_RESET_DELAY) do
        copy_button.icon_name = COPY_ICON
        GLib::Source::REMOVE
      end
    end

    def open_issues
      Gtk::UriLauncher.new("#{HOMEPAGE_URL}/issues").launch(@parent&.root, nil) do |launcher, result|
        launcher.launch_finish(result)
      rescue StandardError
        nil
      end
    end

    # --- Widgets -------------------------------------------------------------

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |d|
        d.title = _('Error Details')
        d.content_width = 550
        d.content_height = 400
        d.add_css_class('error-details')
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def page = @page ||= Adwaita::PreferencesPage.new

    def explanation_group
      @explanation_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.description = @body.to_s
      end
    end

    def message_group
      @message_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _('Error Message')
        group.visible = !message_text.empty?
      end
    end

    def copy_button
      @copy_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = COPY_ICON
        button.tooltip_text = _('Copy Error Message')
        button.add_css_class('flat')
      end
    end

    def message_frame
      @message_frame ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.vexpand = true
        scroller.overflow = :hidden
        scroller.add_css_class('card')
        scroller.child = message_view
      end
    end

    def message_view
      @message_view ||= Gtk::TextView.new.tap do |view|
        view.editable = false
        view.wrap_mode = :word_char
        view.top_margin = 12
        view.bottom_margin = 12
        view.left_margin = 12
        view.right_margin = 12
        view.buffer.text = message_text
        view.add_css_class('error-message')
        view.add_css_class('monospace')
      end
    end

    def report_button
      @report_button ||= Gtk::Button.new.tap do |button|
        button.halign = :center
        button.margin_bottom = 24
        button.add_css_class('suggested-action')
        button.add_css_class('pill')
        button.child = report_content
      end
    end

    def report_content
      @report_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = 'external-link-symbolic'
        content.label = _('Report _Issue')
        content.use_underline = true
      end
    end
  end
end
