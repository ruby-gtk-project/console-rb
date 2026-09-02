# frozen_string_literal: true

require 'gobject-introspection'

module ConsoleRb
  # `Vte::Regex.new` in the Ruby bindings resolves to GLib's Regex constructor
  # and raises `TypeError: no implicit conversion of Symbol into Integer`, so
  # VteRegex has to be built by invoking the introspected constructors directly.
  # The receiver must be an allocated (not initialised) Vte::Regex.
  module Regex
    # VTE rejects any match regex compiled without PCRE2_MULTILINE, and the
    # REGEX_FLAGS_DEFAULT the bindings expose does not include it, so it has to
    # be added back explicitly.
    MULTILINE = 0x00000400
    # PCRE2_CASELESS
    CASELESS = 0x00000008

    DEFAULT_FLAGS = Vte::REGEX_FLAGS_DEFAULT | MULTILINE

    module_function

    def for_search(pattern, caseless: true)
      build('new_for_search', pattern, caseless: caseless)
    end

    def for_match(pattern, caseless: false)
      build('new_for_match', pattern, caseless: caseless)
    end

    def build(constructor, pattern, caseless:)
      info(constructor).invoke(
        Vte::Regex.allocate,
        [pattern, -1, caseless ? DEFAULT_FLAGS | CASELESS : DEFAULT_FLAGS]
      )
    rescue StandardError => e
      warn "console-rb: could not compile regex #{pattern.inspect}: #{e.message}"
      nil
    end

    def info(constructor)
      @info ||= {}
      @info[constructor] ||=
        struct_info.methods.find { |method| method.name.to_s == constructor }
    end

    def struct_info
      @struct_info ||= GObjectIntrospection::Repository.default.then do |repository|
        repository.require('Vte')
        repository.find('Vte', 'Regex')
      end
    end
  end
end
