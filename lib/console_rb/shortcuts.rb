# frozen_string_literal: true

module ConsoleRb
  # `Gtk::ShortcutTrigger.parse_string` is not bound in Ruby, so triggers are
  # assembled from the parsed accelerator instead.
  module Shortcuts
    module_function

    def trigger(accelerator)
      Gtk.accelerator_parse(accelerator).then do |parsed|
        ok, keyval, modifiers = normalise(parsed)
        ok ? Gtk::KeyvalTrigger.new(keyval, modifiers) : nil
      end
    end

    # Depending on the binding version the parse returns either
    # [ok, keyval, mods] or just [keyval, mods].
    def normalise(parsed)
      case parsed
      in [true | false => ok, keyval, modifiers] then [ok, keyval, modifiers]
      in [keyval, modifiers] then [!keyval.zero?, keyval, modifiers]
      end
    end
  end
end
