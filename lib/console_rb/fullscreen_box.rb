# frozen_string_literal: true

module ConsoleRb
  # A toolbar view whose top bars hide themselves in fullscreen and slide back
  # in when the pointer approaches the top edge — upstream's KgxFullscreenBox.
  class FullscreenBox
    REVEAL_ZONE = 5
    HIDE_DELAY = 500

    def initialize
      @fullscreen = false
      @autohide = true
      @is_touch = false
    end

    def build
      toolbar_view.tap do |view|
        view.add_controller(motion)
        view.add_controller(touch)

        motion.signal_connect('motion') { |_controller, _x, y| pointer_moved(y) }
        motion.signal_connect('enter') { |_controller, _x, y| pointer_moved(y) }
        motion.signal_connect('leave') { schedule_hide }
        touch.signal_connect('pressed') { |gesture, _n_press, _x, y| touch_pressed(gesture, y) }
      end
    end

    def add_top_bar(widget) = toolbar_view.add_top_bar(widget)

    def content=(widget)
      toolbar_view.content = widget
    end

    def fullscreen=(value)
      @fullscreen = value
      toolbar_view.reveal_top_bars = !value
    end

    # While a popover is open the bars must stay put, otherwise the menu would
    # be yanked out from under the pointer.
    attr_writer :autohide

    def pointer_moved(y)
      @is_touch = false
      return_to_hidden = @fullscreen && @autohide
      toolbar_view.reveal_top_bars = true if return_to_hidden && y <= reveal_threshold
      schedule_hide if return_to_hidden && y > reveal_threshold
    end

    # Touch devices never fire the motion controller above, so fullscreen
    # header bars could never be recovered or re-hidden by touch — upstream's
    # `pressed` on a plain GtkGestureClick (button 0, every button reaches it)
    # fills the same role: it never claims the sequence, so the tap still
    # reaches whatever is underneath, and it only schedules a hide when the
    # tap lands below the titlebar area, leaving a tap on a shown header bar
    # alone.
    def touch_pressed(gesture, y)
      gesture.set_state(:denied)
      @is_touch = true
      schedule_hide if @fullscreen && @autohide && y > reveal_threshold
    end

    def reveal_threshold
      toolbar_view.reveal_top_bars? ? toolbar_view.top_bar_height + REVEAL_ZONE : REVEAL_ZONE
    end

    def schedule_hide
      GLib::Source.remove(@hide_source) if @hide_source
      @hide_source =
        if @fullscreen && @autohide
          GLib::Timeout.add(HIDE_DELAY) do
            toolbar_view.reveal_top_bars = false
            @hide_source = nil
            GLib::Source::REMOVE
          end
        end
    end

    # `top-bar-style: raised` (kgx-fullscreen-box.ui:12) puts the `.raised`
    # class on the top-bar area, which is what every status-colour header-bar
    # rule in data/style.css is keyed on; left at the default `flat` those
    # rules never match. `main-box` (kgx-fullscreen-box.ui:15-17) is a bare
    # styling hook upstream ships alongside it.
    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
        view.top_bar_style = :raised
        view.add_css_class('main-box')
      end
    end

    def motion = @motion ||= Gtk::EventControllerMotion.new

    def touch
      @touch ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = 0
      end
    end
  end
end
