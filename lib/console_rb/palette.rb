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
