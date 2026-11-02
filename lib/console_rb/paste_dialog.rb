# frozen_string_literal: true

module ConsoleRb
  # Ported from src/kgx-paste-dialog.c.
  #
  # Pasting a multi-line command that mentions sudo is the classic
  # clipboard-hijack shape — the newline runs it before the user can read it —
  # so the paste is held behind this confirmation. The destructive appearance is
  # on "Paste", not "Cancel", because pasting is the dangerous answer here.
  #
  # The body is truncated to MAX_CONTENT bytes so a clipboard holding a
  # megabyte of text cannot stretch the dialog off the screen, while the text
  # actually pasted is always the full original.
  class PasteDialog
    include I18n

    MAX_CONTENT = 8000
    CANCEL = 'cancel'
    PASTE = 'paste'

    attr_reader :content

    def initialize(content:)
      @content = content
    end

    # Yields :paste or :cancelled, matching upstream's KgxPasteDialogResult.
    # Closing the dialog any other way is a cancel, which is what the
    # close-response is for.
    def run(parent, &block)
      dialog.tap do |d|
        d.signal_connect('response') do |_dialog, response|
          block&.call(response == PASTE ? :paste : :cancelled)
        end
        d.present(parent)
      end
    end

    def body
      format(
        # Translators: %s is the (possibly truncated) command being pasted
        _("Make sure you know what the command does:\n%s"), constrained_content
      )
    end

    # Upstream's kgx_str_constrained_dup: cut at a byte budget on a character
    # boundary, then mark the cut with an ellipsis.
    def constrained_content
      content.to_s.then do |text|
        text.bytesize <= MAX_CONTENT ? text : "#{truncate(text)}…"
      end
    end

    def truncate(text)
      text.byteslice(0, MAX_CONTENT).then do |cut|
        cut.force_encoding(text.encoding).scrub('')
      end
    end

    # --- Widgets -------------------------------------------------------------

    def dialog
      @dialog ||= Adwaita::AlertDialog.new(
        _('You are pasting a command that runs as an administrator'), body
      ).tap do |d|
        d.add_response(CANCEL, _('_Cancel'))
        d.add_response(PASTE, _('_Paste'))
        d.set_response_appearance(PASTE, :destructive)
        d.close_response = CANCEL
        d.add_css_class('numeric')
      end
    end
  end
end
