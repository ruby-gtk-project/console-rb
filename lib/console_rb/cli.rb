# frozen_string_literal: true

require 'optparse'
require 'shellwords'

module ConsoleRb
  # Parses the same command line upstream accepts. Everything after `--` (or
  # after `-e`) is the command to run, so it is split off before OptionParser
  # ever sees it.
  class CLI
    OPTIONS = %i[version about tab command working_directory title
                 set_shell set_scrollback colour_table paths].freeze

    attr_reader :options

    def initialize(argv)
      @argv = argv.dup
      @options = { paths: [] }
    end

    def parse
      split_command
      parser.parse!(@argv)
      @options[:paths] = @argv
      self
    rescue OptionParser::ParseError => e
      @options[:error] = e.message
      self
    end

    # `-e foo` and `-- foo bar` both mean "run this instead of the shell"; the
    # remainder after the separator is taken verbatim, not re-parsed.
    def split_command
      @argv.index('--').then do |separator|
        if separator
          @options[:command] = @argv[(separator + 1)..]
          @argv = @argv[0...separator]
        end
      end
    end

    def parser
      @parser ||= OptionParser.new do |parser|
        parser.banner = 'Usage: console-rb [OPTION…] [-e|-- COMMAND [ARGUMENT…]]'
        parser.separator ''
        parser.separator "console-rb #{VERSION} — Terminal Emulator"
        parser.separator ''

        parser.on('--version', 'Print the version and exit') { @options[:version] = true }
        parser.on('--about', 'Print the logo and exit') { @options[:about] = true }
        parser.on('--tab', 'Open a tab in the existing window') { @options[:tab] = true }
        parser.on('--wait', 'Wait until the child exits') { @options[:wait] = true }
        parser.on('-e', '--command COMMAND',
                  'Execute the argument to this option inside the terminal') do |value|
          @options[:command] = Shellwords.split(value)
        end
        parser.on('--working-directory DIRNAME', 'Set the working directory') do |value|
          @options[:working_directory] = value
        end
        parser.on('-T', '--title TITLE', 'Set the initial window title') do |value|
          @options[:title] = value
        end
        parser.on('--set-shell SHELL', 'ADVANCED: Set the shell to launch') do |value|
          @options[:set_shell] = Shellwords.split(value)
        end
        parser.on('--set-scrollback LINES', Integer, 'ADVANCED: Set the scrollback length') do |value|
          @options[:set_scrollback] = value
        end
        parser.on('--colour-table', 'Print the ANSI colour table and exit') do
          @options[:colour_table] = true
        end
        parser.separator ''
        parser.separator HOMEPAGE_URL
      end
    end

    # Anything that prints and exits without ever opening a window. Returns
    # true when it handled the invocation and no window should be opened.
    # `settings` is a block so that --version, --about and --colour-table work
    # even when the GSettings schema is not installed.
    def handle_immediate(&settings)
      if @options[:error]
        warn(@options[:error])
      elsif @options[:version]
        AboutDialog.print_version
      elsif @options[:about]
        AboutDialog.print_logo
      elsif @options[:colour_table]
        print_colour_table
      elsif @options[:set_shell]
        settings.call.custom_shell = @options[:set_shell]
      elsif @options[:set_scrollback]
        settings.call.scrollback_limit = @options[:set_scrollback]
      elsif conflicting?
        warn('Cannot use both --working-directory and positional parameters')
      else
        false
      end.then { |handled| handled != false }
    end

    def print_colour_table
      puts 'Colour Table'
      [[30, false], [90, true], [40, false], [100, true]].each do |base, second_row|
        puts(8.times.map do |i|
          format("\e[0;%02dm #%02d \e[0m", base + i, i + (second_row ? 8 : 0))
        end.join)
      end
    end

    # Refuse the combination upstream refuses too.
    def conflicting?
      @options[:working_directory] && !@options[:paths].empty?
    end
  end
end
