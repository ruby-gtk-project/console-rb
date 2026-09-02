# frozen_string_literal: true

module ConsoleRb
  # The keyboard shortcuts reference. Built from the same table the application
  # registers its accelerators from, so the two cannot drift apart.
  class ShortcutsDialog
    SECTIONS = {
      'Application' => [['New Window', '<Shift><Primary>n']],
      'Terminal' => [
        ['Find', '<Shift><Primary>f'],
        ['Copy', '<Shift><Primary>c'],
        ['Paste', '<Shift><Primary>v'],
        ['Enlarge Text', '<Primary>plus'],
        ['Shrink Text', '<Primary>minus'],
        ['Reset Size', '<Primary>0']
      ],
      'Tabs' => [
        ['New Tab', '<Shift><Primary>t'],
        ['Close Tab', '<Shift><Primary>w'],
        ['Show All Tabs', '<Shift><Primary>o'],
        ['Next Tab', '<Primary>Page_Down'],
        ['Previous Tab', '<Primary>Page_Up'],
        ['Move Tab Left', '<Shift><Primary>Page_Up'],
        ['Move Tab Right', '<Shift><Primary>Page_Down'],
        ['Switch to Tab 1–9', '<Alt>1...9'],
        ['Switch to Tab 10', '<Alt>0']
      ],
      'Window' => [['Fullscreen', '<Shift><Primary>F11']]
    }.freeze

    def present(parent) = build.present(parent)

    def build
      dialog.tap do |d|
        d.add(page)

        page.tap do |p|
          groups.each { |group| p.add(group) }
        end
      end
    end

    def dialog
      @dialog ||= Adwaita::PreferencesDialog.new.tap do |d|
        d.title = _('Keyboard Shortcuts')
      end
    end

    def page = @page ||= Adwaita::PreferencesPage.new

    def groups
      @groups ||= SECTIONS.map do |section, shortcuts|
        Adwaita::PreferencesGroup.new.tap do |group|
          group.title = _(section)
          shortcuts.each { |title, accelerator| group.add(row_for(title, accelerator)) }
        end
      end
    end

    def row_for(title, accelerator)
      Adwaita::ActionRow.new.tap do |row|
        row.title = _(title)
        row.add_suffix(accelerator_label(accelerator))
      end
    end

    def accelerator_label(accelerator)
      Gtk::Label.new(pretty(accelerator)).tap do |label|
        label.add_css_class('dim-label')
        label.add_css_class('numeric')
      end
    end

    # Turn `<Shift><Primary>n` into something a human reads as Ctrl+Shift+N.
    def pretty(accelerator)
      accelerator
        .gsub('<Primary>', 'Ctrl+')
        .gsub('<Shift>', 'Shift+')
        .gsub('<Alt>', 'Alt+')
        .gsub('plus', '+')
        .gsub('minus', '−')
        .gsub('Page_Down', 'Page Down')
        .gsub('Page_Up', 'Page Up')
    end

    def _(text) = text
  end
end
