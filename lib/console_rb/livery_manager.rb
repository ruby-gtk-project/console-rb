# frozen_string_literal: true

module ConsoleRb
  # Ported from src/kgx-livery-manager.c.
  #
  # Holds two tables of liveries — the three built-ins (whose palettes live in
  # Liveries, since they are plain data) and the user's own, read out of the
  # `custom-liveries` setting. A uuid is resolved against the custom table
  # first, so a user can retheme a built-in by reusing its uuid.
  #
  # Upstream exposes the custom table as a GVariant vardict property. The Ruby
  # GLib::Variant binding cannot read a vardict at all, so Settings stores the
  # same data as JSON and hands this class deserialised Livery objects instead;
  # see Palette for the detail. The manager's own contract is unchanged.
  class LiveryManager
    def initialize(custom: [])
      @custom = {}
      self.custom_liveries = custom
    end

    # The livery every lookup falls back to, and the one the `kgx` uuid names.
    def fallback = Liveries.fallback

    def builtin_liveries = @builtin_liveries ||= index(Liveries.built_in)

    def custom_liveries = @custom.values

    # Replaces the whole custom table, as upstream's setter does. A livery
    # whose uuid disagrees with the key it was stored under is upstream's
    # "conflicted uuid" case; here the uuid inside the livery is the only key
    # there is, so the equivalent defect is two liveries claiming one uuid.
    def custom_liveries=(liveries)
      @custom = {}
      Array(liveries).each { |livery| add(livery) }
      notify
    end

    def add(livery)
      if @custom.key?(livery.uuid)
        warn "console-rb: livery-manager: duplicated uuid: #{livery.uuid.inspect}"
      else
        @custom[livery.uuid] = livery
      end
    end

    def remove(uuid) = @custom.delete(uuid)

    # Nil for an unknown uuid, matching upstream — callers that need a usable
    # palette regardless ask for #find.
    def resolve(uuid) = @custom[uuid] || builtin_liveries[uuid]

    def find(uuid) = resolve(uuid) || fallback

    # Custom liveries shadow built-ins of the same uuid, and the built-ins keep
    # their order so the preferences list does not reshuffle itself.
    def all = builtin_liveries.merge(@custom).values

    def on_change(&block) = listeners << block

    def listeners = @listeners ||= []

    def notify = listeners.each { |listener| listener.call(self) }

    def index(liveries) = liveries.to_h { |livery| [livery.uuid, livery] }
  end
end
