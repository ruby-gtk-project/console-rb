# frozen_string_literal: true

module ConsoleRb
  # A terminal colour scheme: a foreground, a background, a transparency
  # fraction and the sixteen ANSI colours.
  class Palette
    COLOUR_COUNT = 16

    attr_reader :foreground, :background, :transparency, :colours

    def initialize(foreground:, background:, transparency:, colours:)
      @foreground = foreground
      @background = background
      @transparency = transparency
      @colours = colours
    end

    # VTE takes the alpha of the background colour as the window transparency,
    # so an opaque variant is just the same palette with alpha forced to 1.
    def opaque
      Palette.new(foreground: foreground,
                  background: rgba(background.red, background.green, background.blue, 1.0),
                  transparency: 0.0,
                  colours: colours)
    end

    def background_with_transparency
      rgba(background.red, background.green, background.blue, 1.0 - transparency)
    end

    def self.from_hex(foreground:, background:, transparency:, colours:)
      new(foreground: parse(foreground),
          background: parse(background),
          transparency: transparency,
          colours: colours.map { |colour| parse(colour) })
    end

    # --- Serialised form, as stored in the `custom-liveries` setting ---------
    #
    # Upstream stores liveries as a GVariant `a{sv}`. The Ruby GLib::Variant
    # binding cannot read a vardict at all — `value`, `to_s` and `inspect` all
    # raise NotImplementedError, and the struct exposes no pointer to reach
    # g_variant_get_child_value through Fiddle — so this port stores the same
    # data as JSON in a string key instead. Nothing is lost: the dconf path is
    # this app's own, and the format users actually exchange liveries in is the
    # key file below, which is byte-compatible with upstream.

    def to_h
      {
        'foreground' => triple(foreground),
        'background' => triple(background),
        'transparency' => transparency * 100,
        'colours' => colours.map { |colour| triple(colour) }
      }
    end

    def self.from_h(hash)
      new(foreground: rgba_from(hash['foreground'], [1.0, 1.0, 1.0]),
          background: rgba_from(hash['background'], [0.12, 0.12, 0.12]),
          transparency: (hash['transparency'] || 0.0) / 100.0,
          colours: (hash['colours'] || []).map { |triple| rgba_from(triple, [0.0, 0.0, 0.0]) })
    end

    def self.rgba_from(triple, fallback)
      (triple || fallback).to_a.then do |(red, green, blue)|
        Gdk::RGBA.new(red || 0.0, green || 0.0, blue || 0.0, 1.0)
      end
    end

    def triple(colour) = [colour.red, colour.green, colour.blue]

    # --- Key file, as used by livery import/export ---------------------------
    #
    # Byte-compatible with kgx_palette_new_from_group / export_to_group.

    KEY_FILE_KEYS = { foreground: 'Foreground', background: 'Background',
                      transparency: 'Transparency', colours: 'Colours' }.freeze

    def self.from_key_file(key_file, group)
      new(foreground: parse(key_file.get_string(group, KEY_FILE_KEYS[:foreground])),
          background: parse(key_file.get_string(group, KEY_FILE_KEYS[:background])),
          transparency: transparency_from(key_file, group),
          colours: key_file.get_string_list(group, KEY_FILE_KEYS[:colours]).map { |c| parse(c) })
    end

    def self.transparency_from(key_file, group)
      key_file.get_double(group, KEY_FILE_KEYS[:transparency]) / 100.0
    rescue StandardError
      0.0
    end

    def export_to_key_file(key_file, group)
      key_file.set_string(group, KEY_FILE_KEYS[:foreground], hex(foreground))
      key_file.set_string(group, KEY_FILE_KEYS[:background], hex(background))
      key_file.set_double(group, KEY_FILE_KEYS[:transparency], transparency * 100)
      key_file.set_string_list(group, KEY_FILE_KEYS[:colours], colours.map { |c| hex(c) })
    end

    def hex(colour)
      format('%<r>02x%<g>02x%<b>02x',
             r: (colour.red * 255).round, g: (colour.green * 255).round,
             b: (colour.blue * 255).round)
    end

    def self.parse(spec)
      (spec.start_with?('#') ? spec : "##{spec}").then do |normalised|
        Gdk::RGBA.parse(normalised) ||
          raise(ArgumentError, "unparsable colour #{spec.inspect}")
      end
    end

    private

    def rgba(red, green, blue, alpha)
      Gdk::RGBA.new(red, green, blue, alpha)
    end
  end
end
