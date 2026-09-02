# frozen_string_literal: true

module ConsoleRb
  # The three-way light/system/dark selector that sits at the top of the primary
  # menu. The "system" option is hidden when the desktop cannot report a
  # preference, since following it would then be meaningless.
  class ThemeSwitcher
    THEMES = { system: :auto, light: :day, dark: :night }.freeze

    def initialize(settings:)
      @settings = settings
    end

    def build
      box.tap do |b|
        THEMES.each_key { |name| b.append(overlay_for(name)) }
      end

      system_overlay.visible = Adwaita::StyleManager.default.system_supports_color_schemes?
      sync_from_settings
      @settings.on_change { |key| sync_from_settings if key == 'theme' }

      selectors.each do |name, button|
        button.signal_connect('notify::active') do
          checks.fetch(name).visible = button.active?
          @settings.theme = THEMES.fetch(name) if button.active? && !@syncing
        end
        checks.fetch(name).visible = button.active?
      end

      box
    end

    def sync_from_settings
      @syncing = true
      THEMES.each { |name, theme| selectors.fetch(name).active = (@settings.theme == theme) }
      @syncing = false
    end

    def box
      @box ||= Gtk::Box.new(:horizontal, 18).tap do |b|
        b.homogeneous = true
        b.add_css_class('themeswitcher')
      end
    end

    def overlay_for(name)
      overlays.fetch(name)
    end

    def overlays
      @overlays ||= THEMES.each_key.to_h do |name|
        [name, Gtk::Overlay.new.tap do |overlay|
          overlay.halign = :center
          overlay.child = selectors.fetch(name)
          overlay.add_overlay(checks.fetch(name))
        end]
      end
    end

    def system_overlay = overlays.fetch(:system)

    TOOLTIPS = {
      system: 'Follow System Style',
      light: 'Light Style',
      dark: 'Dark Style'
    }.freeze

    # The three buttons share a group so they behave as radio buttons. The first
    # one is the group leader — grouping a check button with itself trips a
    # GTK assertion.
    def selectors
      @selectors ||= THEMES.each_key.to_h do |name|
        [name, Gtk::CheckButton.new.tap do |button|
          button.tooltip_text = TOOLTIPS.fetch(name)
          button.halign = :center
          button.add_css_class(name.to_s)
        end]
      end.tap do |buttons|
        buttons.values.drop(1).each { |button| button.group = buttons.values.first }
      end
    end

    def checks
      @checks ||= THEMES.each_key.to_h do |name|
        [name, Gtk::Image.new.tap do |image|
          image.icon_name = 'object-select-symbolic'
          image.pixel_size = 13
          image.halign = :end
          image.valign = :end
          image.add_css_class('check')
          image.visible = false
        end]
      end
    end
  end
end
