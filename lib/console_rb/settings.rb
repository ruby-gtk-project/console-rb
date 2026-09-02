# frozen_string_literal: true

module ConsoleRb
  # Wraps the GSettings schema and the handful of derived values the rest of the
  # app asks for (resolved shell, resolved theme, the current livery).
  class Settings
    FONT_SCALE_MIN = 0.5
    FONT_SCALE_MAX = 4.0
    FONT_SCALE_DEFAULT = 1.0
    FONT_SCALE_STEP = 0.1

    def initialize
      @listeners = []
      settings.signal_connect('changed') { |_settings, key| notify(key) }
    end

    def settings = @settings ||= Gio::Settings.new(APPLICATION_ID)

    # Callers register here rather than binding GObject properties, which the
    # Ruby bindings make awkward for a plain (non-GObject) wrapper like this.
    def on_change(&block) = @listeners << block

    def notify(key) = @listeners.each { |listener| listener.call(key) }

    # --- Theme ---------------------------------------------------------------

    def theme = settings.get_string('theme').to_sym

    def theme=(value)
      settings.set_string('theme', value.to_s)
    end

    # `hacker` is a deprecated alias for `night`, and `auto` resolves against
    # whatever the system style manager currently reports.
    def resolve_theme(dark_environment)
      case theme
      when :day then :day
      when :night, :hacker then :night
      else dark_environment ? :night : :day
      end
    end

    def color_scheme
      case theme
      when :day then :force_light
      when :auto then :prefer_light
      else :force_dark
      end
    end

    # --- Font ----------------------------------------------------------------

    def font_scale = settings.get_double('font-scale')

    def font_scale=(value)
      settings.set_double('font-scale', value.clamp(FONT_SCALE_MIN, FONT_SCALE_MAX))
    end

    def scale_can_increase? = font_scale < FONT_SCALE_MAX

    def scale_can_decrease? = font_scale > FONT_SCALE_MIN

    def scale_can_reset? = (font_scale - FONT_SCALE_DEFAULT).abs > 0.05

    def increase_scale = self.font_scale = font_scale + FONT_SCALE_STEP

    def decrease_scale = self.font_scale = font_scale - FONT_SCALE_STEP

    def reset_scale = self.font_scale = FONT_SCALE_DEFAULT

    def use_system_font? = settings.get_boolean('use-system-font')

    def use_system_font=(value)
      settings.set_boolean('use-system-font', value)
    end

    def custom_font_string = settings.get_string('custom-font')

    def custom_font_string=(value)
      settings.set_string('custom-font', value.to_s)
    end

    # The system monospace font is the fallback whenever the user has not opted
    # into a custom one, matching upstream's `use-system-font` behaviour.
    def font
      Pango::FontDescription.new(
        if use_system_font? || custom_font_string.empty?
          system_monospace_font
        else
          custom_font_string
        end
      )
    end

    def system_monospace_font
      Gio::Settings.new('org.gnome.desktop.interface').get_string('monospace-font-name')
    rescue StandardError
      'Monospace 11'
    end

    # --- Shell ---------------------------------------------------------------

    def custom_shell = settings.get_strv('shell')

    def custom_shell=(value)
      settings.set_strv('shell', Array(value))
    end

    # Prefer an explicitly configured shell, then the user's login shell, then
    # /bin/sh as a last resort.
    def shell
      custom_shell.then do |configured|
        if configured.empty?
          [Vte.user_shell || '/bin/sh']
        else
          configured
        end
      end
    end

    # --- Scrollback ----------------------------------------------------------

    def ignore_scrollback_limit? = settings.get_boolean('ignore-scrollback-limit')

    def ignore_scrollback_limit=(value)
      settings.set_boolean('ignore-scrollback-limit', value)
    end

    def scrollback_limit = settings.get_int64('scrollback-lines')

    def scrollback_limit=(value)
      settings.set_int64('scrollback-lines', value.to_i)
    end

    # VTE treats a negative line count as "unlimited".
    def scrollback_lines = ignore_scrollback_limit? ? -1 : scrollback_limit

    # --- Bell and terminal behaviour -----------------------------------------

    def audible_bell? = settings.get_boolean('audible-bell')

    def audible_bell=(value)
      settings.set_boolean('audible-bell', value)
    end

    def visual_bell? = settings.get_boolean('visual-bell')

    def visual_bell=(value)
      settings.set_boolean('visual-bell', value)
    end

    def software_flow_control? = settings.get_boolean('software-flow-control')

    def transparency? = settings.get_boolean('transparency')

    def always_stop_train? = settings.get_boolean('always-stop-train')

    # --- Livery --------------------------------------------------------------

    def livery = Liveries.find(settings.get_string('livery'), custom_liveries)

    def livery=(value)
      settings.set_string('livery', value.uuid)
    end

    def liveries = Liveries.all(custom_liveries)

    # `custom-liveries` holds a JSON object keyed by uuid — see Palette for why
    # this is not the GVariant vardict upstream uses. A malformed entry is
    # skipped with a warning rather than taking the whole app down.
    def custom_liveries
      JSON.parse(settings.get_string('custom-liveries')).filter_map do |_uuid, hash|
        Livery.from_h(hash)
      rescue StandardError => e
        warn "console-rb: ignoring malformed custom livery: #{e.message}"
        nil
      end
    rescue JSON::ParserError => e
      warn "console-rb: could not read custom liveries: #{e.message}"
      []
    end

    def add_custom_livery(livery)
      write_custom_liveries(
        custom_liveries.reject { |existing| existing.uuid == livery.uuid }.push(livery)
      )
    end

    def remove_custom_livery(uuid)
      write_custom_liveries(custom_liveries.reject { |livery| livery.uuid == uuid })
    end

    def write_custom_liveries(liveries)
      liveries.to_h { |livery| [livery.uuid, livery.to_h] }
              .then { |table| settings.set_string('custom-liveries', JSON.generate(table)) }
    end

    # --- Window geometry -----------------------------------------------------

    def restore_size? = settings.get_boolean('restore-window-size')

    def window_size
      settings.get_value('last-window-size').to_a.then do |(width, height)|
        [width || -1, height || -1]
      end
    end

    def window_maximised? = settings.get_boolean('last-window-maximised')

    def window_fullscreen? = settings.get_boolean('last-window-fullscreen')

    def save_window_state(width:, height:, maximised:, fullscreen:)
      # GLib::Variant.new cannot build a tuple, and set_value re-converts the
      # Ruby object and then cannot either; parse + set_value_raw is the one
      # path that gets a (ii) into GSettings.
      settings.set_value_raw('last-window-size',
                             GLib::Variant.parse("(#{width.to_i}, #{height.to_i})", '(ii)'))
      settings.set_boolean('last-window-maximised', maximised)
      settings.set_boolean('last-window-fullscreen', fullscreen)
    end
  end
end
