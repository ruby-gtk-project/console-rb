# frozen_string_literal: true

module ConsoleRb
  # A named pair of palettes — one for the dark theme, one for the light one.
  # A livery without a day palette reuses its night palette in both.
  class Livery
    attr_reader :uuid, :name, :night, :day

    def initialize(uuid:, name:, night:, day: nil)
      @uuid = uuid
      @name = name
      @night = night
      @day = day
    end

    def palette_for(theme)
      theme == :day ? (day || night) : night
    end
  end

  # The built-in liveries. Upstream also persists user-defined liveries into the
  # `custom-liveries` key; there is no UI to create one, so this port ships the
  # three built-ins only.
  module Liveries
    KGX_UUID = '9f1374fd-f199-429f-bae6-9cf1260f6e3e'
    LINUX_UUID = '131b4aac-399b-4ee4-a8e1-f22e5c3c7bdd'
    XTERM_UUID = '54156855-4a0d-454a-9d5a-7d3e2c9f26f5'

    KGX_COLOURS = %w[
      241f31 c01c28 2ec27e f5c211 1e78e4 9841bb 0ab9dc c0bfbc
      5e5c64 ed333b 57e389 f8e45c 51a1ff c061cb 4fd2fd f6f5f4
    ].freeze

    LINUX_COLOURS = %w[
      000000 aa0000 00aa00 aa5500 0000aa aa00aa 00aaaa aaaaaa
      555555 ff5555 55ff55 ffff55 5555ff ff55ff 55ffff ffffff
    ].freeze

    XTERM_COLOURS = %w[
      000000 cd0000 00cd00 cdcd00 0000ee cd00cd 00cdcd e5e5e5
      7f7f7f ff0000 00ff00 ffff00 5c5cff ff00ff 00ffff ffffff
    ].freeze

    module_function

    # Memoized: the palettes are immutable, and settings changes re-read the
    # current livery often enough that rebuilding them each time is waste.
    def standard
      @standard ||= Livery.new(
        uuid: KGX_UUID,
        name: nil,
        night: Palette.from_hex(foreground: '#ffffff', background: '#1c1c1f',
                                transparency: 0.04, colours: KGX_COLOURS),
        # Upstream has a "TODO: Have some day colours" here and reuses the night
        # ANSI colours for the light palette; this port matches that.
        day: Palette.from_hex(foreground: '#000000', background: '#ffffff',
                              transparency: 0.01, colours: KGX_COLOURS)
      )
    end

    def linux
      @linux ||= Livery.new(
        uuid: LINUX_UUID,
        name: 'Linux',
        night: Palette.from_hex(foreground: '#ffffff', background: '#000000',
                                transparency: 0.0, colours: LINUX_COLOURS)
      )
    end

    def xterm
      @xterm ||= Livery.new(
        uuid: XTERM_UUID,
        name: 'XTerm',
        night: Palette.from_hex(foreground: '#ffffff', background: '#000000',
                                transparency: 0.0, colours: XTERM_COLOURS)
      )
    end

    def all = @all ||= [standard, linux, xterm]

    def fallback = standard

    def find(uuid) = all.find { |livery| livery.uuid == uuid } || fallback
  end
end
