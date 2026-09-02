# frozen_string_literal: true

module ConsoleRb
  # Asks before killing still-running commands, listing what would die.
  class CloseDialog
    def initialize(context:, commands:, on_close:)
      @context = context
      @commands = commands
      @on_close = on_close
    end

    def build
      dialog.tap do |d|
        d.extra_child = list_frame

        list.tap do |box|
          @commands.each { |command| box.append(row_for(command)) }
        end

        d.signal_connect('response') { |_dialog, response| @on_close.call if response == 'close' }
      end
    end

    def present(parent) = build.present(parent)

    def dialog
      @dialog ||= Adwaita::AlertDialog.new(heading, body).tap do |d|
        d.add_response('cancel', _('_Cancel'))
        d.add_response('close', _('C_lose'))
        d.set_response_appearance('close', :destructive)
        d.default_response = 'cancel'
        d.close_response = 'cancel'
      end
    end

    def heading
      @context == :window ? _('Close Window?') : _('Close Tab?')
    end

    def body
      subject = @context == :window ? _('window') : _('tab')

      if @commands.length == 1
        format(_('A command is still running, closing this %s will kill it and ' \
                 'may lead to unexpected outcomes'), subject)
      else
        format(_('Some commands are still running, closing this %s will kill them ' \
                 'and may lead to unexpected outcomes'), subject)
      end
    end

    # AdwActionRow renders its title as Pango markup and GLib's escape helper is
    # not bound, so command lines are escaped here before they reach the row.
    ESCAPES = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&#39;' }.freeze

    def row_for(command)
      Adwaita::ActionRow.new.tap do |row|
        row.title = escape(command.title)
        row.subtitle = escape(command.subtitle)
      end
    end

    def escape(text) = text.to_s.gsub(/[&<>"']/, ESCAPES)

    def list_frame
      @list_frame ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.max_content_height = 200
        scroller.propagate_natural_height = true
        scroller.child = list
      end
    end

    def list
      @list ||= Gtk::ListBox.new.tap do |box|
        box.selection_mode = :none
        box.add_css_class('boxed-list')
        box.add_css_class('process-list')
      end
    end

    def _(text) = text
  end
end
