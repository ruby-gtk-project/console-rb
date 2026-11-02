# frozen_string_literal: true

module ConsoleRb
  # Ported from src/kgx-watcher.c.
  #
  # One timer drives every train, so the /proc scan happens once per tick no
  # matter how many tabs are open. Upstream keeps two GTrees — the shells it is
  # watching and the processes it has seen under them — and pushes each child
  # into the owning train as it walks the process list; Train here recomputes
  # its own descendants from the same snapshot, which needs no second table.
  #
  # Polling slows down rather than stopping while the app is in the background,
  # exactly as upstream's in-background property does.
  class Watcher
    FOREGROUND_INTERVAL = 500
    BACKGROUND_INTERVAL = 2000

    def initialize
      @trains = []
      @in_background = false
    end

    attr_reader :in_background, :trains

    # Changing this swaps the poll interval, which means tearing the timeout
    # down and putting a new one up; a value that has not actually changed must
    # not do that, or a burst of focus changes would reset the clock each time.
    def in_background=(value)
      !!value == @in_background || begin
        @in_background = !!value
        restart
      end
    end

    def interval = in_background ? BACKGROUND_INTERVAL : FOREGROUND_INTERVAL

    # Registers a shell with the watcher. Upstream takes the pid off the train
    # and keys its table by it; the train is the key here because that is what
    # the tick has to call back into.
    def watch(train) = @trains << train

    def unwatch(train) = @trains.delete(train)

    def watching?(train) = @trains.include?(train)

    def start = timeout

    def timeout = @timeout ||= install_timeout

    def stop
      @timeout&.then do |id|
        GLib::Source.remove(id)
        @timeout = nil
      end
    end

    # Only restarts a timer that is already running: the interval the next
    # #start picks up is derived from in_background anyway.
    def restart
      @timeout&.then do
        stop
        start
      end
    end

    def install_timeout
      GLib::Timeout.add(interval) do
        tick
        GLib::Source::CONTINUE
      end
    end

    # With no trains there is nothing to attribute processes to, so the scan —
    # by far the expensive part — is skipped entirely.
    def tick
      @trains.empty? ||
        ProcessInfo.all.then { |processes| @trains.each { |train| train.refresh(processes) } }
    end
  end
end
