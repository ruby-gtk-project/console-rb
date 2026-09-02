# frozen_string_literal: true

module ConsoleRb
  # The entry point. All argument handling happens in the application's
  # command-line signal so a second invocation is routed to the running
  # instance; this only has to start the loop.
  class Launcher
    def initialize(argv)
      @argv = argv
    end

    def run = exit(application.build.run([$PROGRAM_NAME] + @argv))

    def application = @application ||= Application.new
  end
end
