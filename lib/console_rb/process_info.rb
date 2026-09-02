# frozen_string_literal: true

module ConsoleRb
  # A snapshot of one process read out of /proc. Upstream reads the same fields
  # through libgtop when it is available; /proc alone is enough on Linux and
  # keeps the port dependency-free.
  class ProcessInfo
    MAX_TITLE_LENGTH = 100

    attr_reader :pid, :ppid, :argv, :euid

    def initialize(pid:, ppid:, argv:, euid:)
      @pid = pid
      @ppid = ppid
      @argv = argv
      @euid = euid
    end

    def root? = euid.zero?

    def program = File.basename(argv.first || '')

    # The close dialog shows the command name as a title and its arguments as a
    # subtitle, both truncated so a pathological command line cannot stretch the
    # dialog off screen.
    def title = truncate(argv.first || program)

    def subtitle = truncate(argv.drop(1).join(' '))

    def truncate(text)
      text.length > MAX_TITLE_LENGTH ? "#{text[0, MAX_TITLE_LENGTH]}…" : text
    end

    REMOTE_PROGRAMS = %w[ssh telnet mosh-client mosh et].freeze

    def remote?
      return true if REMOTE_PROGRAMS.include?(program)

      program == 'waypipe' && argv.drop(1).any? { |arg| %w[ssh telnet].include?(arg) }
    end

    # Upstream calls these "playbox" sessions — a shell inside a container or
    # sandbox, which gets its own header bar colour.
    PLAYBOX_PROGRAMS = %w[flatpak toolbox distrobox podman docker].freeze

    def playbox? = PLAYBOX_PROGRAMS.include?(program)

    def self.read(pid)
      new(pid: pid,
          ppid: read_ppid(pid),
          argv: read_argv(pid),
          euid: read_euid(pid))
    rescue SystemCallError, Errno::ENOENT
      nil
    end

    def self.read_argv(pid)
      File.read("/proc/#{pid}/cmdline").split("\0").reject(&:empty?).then do |argv|
        argv.empty? ? [File.read("/proc/#{pid}/comm").strip] : argv
      end
    end

    def self.read_ppid(pid)
      # The comm field can contain spaces and parentheses, so parse after the
      # final ')' rather than splitting the whole line.
      File.read("/proc/#{pid}/stat").then do |stat|
        stat[(stat.rindex(')') + 2)..].split(' ')[1].to_i
      end
    end

    def self.read_euid(pid)
      File.read("/proc/#{pid}/status")[/^Uid:\s+\d+\s+(\d+)/, 1].to_i
    end

    # All processes whose ancestry leads back to +root_pid+, the leader
    # included. This is what tells a tab whether something is still running.
    # +processes+ is a pid-keyed snapshot so one /proc scan can serve every tab.
    def self.descendants_of(root_pid, processes = all)
      processes.each_value.select do |process|
        ancestry(process, processes).any? { |parent| parent.pid == root_pid }
      end
    end

    def self.all
      Dir.children('/proc')
         .select { |entry| entry.match?(/\A\d+\z/) }
         .filter_map { |entry| read(entry.to_i) }
         .each_with_object({}) { |process, table| table[process.pid] = process }
    end

    # Walks pid -> ppid, guarding against the cycle a re-used pid could create.
    def self.ancestry(process, processes)
      Enumerator.new do |yielder|
        seen = {}
        current = process
        while current && !seen[current.pid]
          seen[current.pid] = true
          yielder << current
          current = processes[current.ppid]
        end
      end
    end
  end
end
