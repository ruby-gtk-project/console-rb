# frozen_string_literal: true

module ConsoleRb
  # Ported from src/kgx-spad-source.c and src/kgx-spad-source.h.
  #
  # Upstream this is a GObject interface carrying one signal, `spad-thrown`,
  # accumulated with g_signal_accumulator_true_handled: whoever is willing to
  # show the error returns TRUE and emission stops there. A thrower that nobody
  # listens to is a bug, so the unhandled case is logged rather than swallowed.
  #
  # A Ruby mixin is the same contract without the GObject machinery: anything
  # that can raise an error includes this, calls #throw_spad, and lets whatever
  # is above it in the widget tree register a handler with #on_spad_thrown.
  module SpadSource
    # Handlers run in the order they registered and the first truthy answer
    # wins, matching the true-handled accumulator.
    def on_spad_thrown(&block) = spad_listeners << block

    def spad_listeners = @spad_listeners ||= []

    # +title+ is the one-line summary shown on the toast; +body+ is the
    # explanation shown in the dialog and is mandatory, exactly as upstream's
    # kgx_str_non_empty precondition on error_body requires. +content+ and
    # +error+ are the copyable raw detail, and +flags+ mirrors KgxSpadFlags.
    #
    # Returns true when a listener took the error.
    def throw_spad(title:, body:, content: nil, error: nil, flags: [])
      body.to_s.strip.empty? && raise(ArgumentError, 'a spad needs an explanatory body')

      spad_bundle(title: title, body: body, content: content, error: error, flags: flags)
        .then { |bundle| deliver_spad(title, bundle) }
    end

    def deliver_spad(title, bundle)
      spad_listeners.any? { |listener| listener.call(title, bundle) }.tap do |handled|
        handled || log_unhandled_spad(bundle)
      end
    end

    # Upstream packs the same five values into a GVariant so the signal can
    # carry them; here the bundle is the keyword set Spad itself takes, so a
    # listener can hand it straight to Spad.new.
    def spad_bundle(title:, body:, content:, error:, flags:)
      { title: title, body: body, content: content, error: error, flags: flags }
    end

    # The structured fields match upstream's g_log_structured keys so the same
    # journal queries find them.
    def log_unhandled_spad(bundle)
      warn format('console-rb: unhandled-spad: %<title>s' \
                  "\n  KGX_SPAD_BODY: %<body>s" \
                  "\n  KGX_SPAD_CONTENT: %<content>s" \
                  "\n  KGX_SPAD_ERROR: %<error>s",
                  title: bundle[:title],
                  body: bundle[:body],
                  content: spad_field(bundle[:content]),
                  error: spad_field(bundle[:error]))
    end

    def spad_field(value) = value.to_s.strip.empty? ? 'None' : value.to_s
  end
end
