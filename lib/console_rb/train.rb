# frozen_string_literal: true

module ConsoleRb
  # Tracks the processes running under one tab's shell and derives the tab's
  # status flags from them. Upstream names this a "train" — the leader process
  # plus everything it is pulling along.
  class Train
    attr_reader :pid, :children, :status

    def initialize(pid)
      @pid = pid
      @children = []
      @status = []
      @listeners = []
    end

    def on_change(&block) = @listeners << block

    def remote? = @status.include?(:remote)

    def privileged? = @status.include?(:privileged)

    def playbox? = @status.include?(:playbox)

    # Everything except the shell itself. An empty list means the tab is idle
    # and can be closed without warning.
    def running_commands = children.reject { |process| process.pid == pid }

    def refresh(processes)
      ProcessInfo.descendants_of(pid, processes).then do |found|
        @children = found
        recompute_status(found)
      end
    end

    def recompute_status(found)
      found.each_with_object([]) do |process, flags|
        flags << :remote if process.remote?
        flags << :privileged if process.root?
        flags << :playbox if process.playbox?
      end.uniq.then do |flags|
        if flags.sort != @status.sort
          @status = flags
          @listeners.each { |listener| listener.call(flags) }
        end
      end
    end
  end
end
