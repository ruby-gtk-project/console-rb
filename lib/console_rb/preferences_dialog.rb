# frozen_string_literal: true

module ConsoleRb
  # Font, scrollback and bell preferences — the same three groups upstream ships.
  class PreferencesDialog
    def initialize(settings:)
      @settings = settings
    end

    def build
      dialog.tap do |d|
        d.add(page)

        page.tap do |p|
          p.add(font_group)
          p.add(behavior_group)
          p.add(bell_group)

          font_group.tap do |group|
            group.add(use_system_font_row)
            group.add(custom_font_row)
          end

          behavior_group.tap do |group|
            group.add(unlimited_scrollback_row)
            group.add(scrollback_row)
          end

          bell_group.tap do |group|
            group.add(audible_bell_row)
            group.add(visual_bell_row)
          end
        end
      end

      connect
      sync
      dialog
    end

    def present(parent) = build.present(parent)

    def connect
      use_system_font_row.signal_connect('notify::active') do
        apply { @settings.use_system_font = use_system_font_row.active? }
      end
      unlimited_scrollback_row.signal_connect('notify::active') do
        apply { @settings.ignore_scrollback_limit = unlimited_scrollback_row.active? }
      end
      scrollback_row.signal_connect('notify::value') do
        apply { @settings.scrollback_limit = scrollback_row.value.to_i }
      end
      audible_bell_row.signal_connect('notify::active') do
        apply { @settings.audible_bell = audible_bell_row.active? }
      end
      visual_bell_row.signal_connect('notify::active') do
        apply { @settings.visual_bell = visual_bell_row.active? }
      end
      custom_font_row.signal_connect('activated') { choose_font }
    end

    # Writing a setting fires the change signal, which calls back into sync;
    # this guard stops that becoming a loop.
    def apply
      yield unless @syncing
    end

    def sync
      @syncing = true
      use_system_font_row.active = @settings.use_system_font?
      unlimited_scrollback_row.active = @settings.ignore_scrollback_limit?
      scrollback_row.value = @settings.scrollback_limit.to_f
      scrollback_row.sensitive = !@settings.ignore_scrollback_limit?
      audible_bell_row.active = @settings.audible_bell?
      visual_bell_row.active = @settings.visual_bell?
      custom_font_label.label = font_label
      @syncing = false
    end

    def font_label
      @settings.custom_font_string.empty? ? @settings.system_monospace_font : @settings.custom_font_string
    end

    def choose_font
      Gtk::FontDialog.new.tap do |chooser|
        chooser.title = _('Custom Font')
        chooser.choose_font(dialog.root, initial_font, nil) do |source, result|
          source.choose_font_finish(result)&.then do |chosen|
            @settings.custom_font_string = chosen.to_s
            @settings.use_system_font = false
            sync
          end
        rescue StandardError
          nil
        end
      end
    end

    def initial_font = Pango::FontDescription.new(font_label)

    # --- Widgets -------------------------------------------------------------

    def dialog = @dialog ||= Adwaita::PreferencesDialog.new

    def page
      @page ||= Adwaita::PreferencesPage.new.tap do |p|
        p.title = _('General')
      end
    end

    def font_group
      @font_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _('Font')
      end
    end

    def behavior_group
      @behavior_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _('Behavior')
      end
    end

    def bell_group
      @bell_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _('Terminal Bell')
        group.description = _('Control how alerts are indicated')
      end
    end

    def use_system_font_row
      @use_system_font_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = _('Use _System Default')
        row.use_underline = true
      end
    end

    def custom_font_row
      @custom_font_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = _('Custom _Font')
        row.use_underline = true
        row.activatable = true
        row.add_suffix(custom_font_label)
        row.add_suffix(custom_font_arrow)
      end
    end

    def custom_font_label
      @custom_font_label ||= Gtk::Label.new.tap do |label|
        label.ellipsize = :middle
        label.add_css_class('dim-label')
      end
    end

    def custom_font_arrow
      @custom_font_arrow ||= Gtk::Image.new.tap do |image|
        image.icon_name = 'go-next-symbolic'
      end
    end

    def unlimited_scrollback_row
      @unlimited_scrollback_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = _('_Unlimited Scrollback')
        row.use_underline = true
      end
    end

    def scrollback_row
      @scrollback_row ||= Adwaita::SpinRow.new(scrollback_adjustment, 1.0, 0).tap do |row|
        row.title = _('_Scrollback Lines')
        row.use_underline = true
        row.numeric = true
      end
    end

    def scrollback_adjustment
      @scrollback_adjustment ||= Gtk::Adjustment.new(10_000, 0, 800_000, 1_000, 1_000, 0)
    end

    def audible_bell_row
      @audible_bell_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = _('Play _Sound')
        row.use_underline = true
      end
    end

    def visual_bell_row
      @visual_bell_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = _('_Visual Effects')
        row.use_underline = true
      end
    end

    def _(text) = text
  end
end
