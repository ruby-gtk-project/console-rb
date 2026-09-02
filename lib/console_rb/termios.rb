# frozen_string_literal: true

require 'fiddle'

module ConsoleRb
  # Upstream clears IXON/IXOFF in a `child_setup` callback that runs between
  # fork and exec. The Ruby binding for `Vte::Terminal#spawn_async` exposes no
  # child_setup hook, so the same thing is done here through termios on the pty
  # master, which Linux propagates to the slave's line discipline.
  #
  # See FINDINGS.md.
  module Termios
    # struct termios on Linux: four 32-bit flag words, c_line, c_cc[32],
    # then c_ispeed and c_ospeed.
    IFLAG_OFFSET = 0
    STRUCT_SIZE = 60
    TCSANOW = 0

    IXON = 0x0400
    IXANY = 0x0800
    IXOFF = 0x1000
    FLOW_CONTROL_BITS = IXON | IXANY | IXOFF

    module_function

    # Returns true when the change was applied, false when it could not be —
    # a terminal that will not take these settings is not worth failing over.
    def set_flow_control(file_descriptor, enabled)
      Fiddle::Pointer.malloc(STRUCT_SIZE, Fiddle::RUBY_FREE).then do |buffer|
        next false unless tcgetattr.call(file_descriptor, buffer).zero?

        input_flags(buffer).then do |flags|
          write_input_flags(buffer, enabled ? flags | IXON | IXOFF : flags & ~FLOW_CONTROL_BITS)
        end

        tcsetattr.call(file_descriptor, TCSANOW, buffer).zero?
      end
    rescue StandardError => e
      warn "console-rb: could not set flow control: #{e.message}"
      false
    end

    def input_flags(buffer) = buffer[IFLAG_OFFSET, 4].unpack1('L')

    def write_input_flags(buffer, flags)
      buffer[IFLAG_OFFSET, 4] = [flags].pack('L')
    end

    def libc = @libc ||= Fiddle.dlopen(nil)

    def tcgetattr
      @tcgetattr ||= Fiddle::Function.new(
        libc['tcgetattr'], [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT
      )
    end

    def tcsetattr
      @tcsetattr ||= Fiddle::Function.new(
        libc['tcsetattr'], [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT
      )
    end
  end
end
