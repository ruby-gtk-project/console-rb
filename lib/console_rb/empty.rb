# frozen_string_literal: true

module ConsoleRb
  # What a window shows before its first terminal has drawn anything: the app
  # logo, crossfading to a spinner while the shell is still starting.
  class Empty
    def initialize(working: false)
      @working = working
    end

    def build
      box.tap do |b|
        b.append(logo_revealer)
        b.append(spinner_revealer)
      end
    end

    def working=(value)
      @working = value
      logo_revealer.reveal_child = !value
      spinner_revealer.reveal_child = value
    end

    def box
      @box ||= Gtk::Box.new(:vertical, 16).tap do |b|
        b.add_css_class('console-rb-empty')
      end
    end

    def logo_revealer
      @logo_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :crossfade
        revealer.transition_duration = 1000
        revealer.reveal_child = !@working
        revealer.child = logo
      end
    end

    def logo
      @logo ||= Gtk::Image.new.tap do |image|
        image.icon_name = 'utilities-terminal-symbolic'
        image.pixel_size = 128
        image.vexpand = true
        image.valign = :end
      end
    end

    def spinner_revealer
      @spinner_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :crossfade
        revealer.transition_duration = 1000
        revealer.vexpand = true
        revealer.valign = :start
        revealer.reveal_child = @working
        revealer.child = spinner
      end
    end

    def spinner
      @spinner ||= Adwaita::Spinner.new.tap do |s|
        s.valign = :center
        s.halign = :center
        s.width_request = 32
        s.height_request = 32
      end
    end
  end
end
