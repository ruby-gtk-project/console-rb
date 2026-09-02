# Findings: defects and gaps in the Ruby GNOME bindings

Everything below was hit while porting GNOME Console to Ruby. Each entry says
what breaks, how it presents, and what this port does about it. Versions:

| | |
|---|---|
| ruby-gnome gems | 4.3.8 (`glib2`, `gio2`, `gtk4`, `adwaita`, `vte4`, `pango`, `gobject-introspection`) |
| Ruby | 3.3.10 |
| GLib / GTK / libadwaita / VTE | 2.88.3 / 4.22.4 / 1.9.3 / 0.84.1 |
| `gettext` gem | 3.5.2 |

Severity: **crash** — takes the process down; **blocker** — the feature cannot
be built the documented way at all; **gap** — the API is simply absent;
**trap** — works, but silently does the wrong thing.

---

## 1. `GSimpleAction#set_state` inside a `change-state` handler segfaults

**crash** · `gio2`

The documented GLib pattern for a stateful action is to handle `change-state`
and call `g_simple_action_set_state` from inside it. In Ruby that call re-enters
the introspection layer while the signal is still emitting and kills the
process with SIGSEGV:

```ruby
action = Gio::SimpleAction.new('find', nil, GLib::Variant.new(false))
action.signal_connect('change-state') do |act, state|
  act.set_state(state)          # <-- SIGSEGV
end
action.activate(nil)
```

```
gobject-introspection/loader.rb:722: [BUG] Segmentation fault
… g_signal_emit → gtk_widget_unparent → sigsegv
```

**Workaround (implemented).** Two shapes, depending on what the state is for:

- `win.find` (`lib/console_rb/window.rb`) is a *stateless* action, with the
  header-bar toggle button holding the state and being resynchronised from the
  search bar's `notify::search-mode-enabled`.
- `app.theme` (`lib/console_rb/application.rb`) simply omits the `change-state`
  handler. With no handler installed GLib updates the state itself, and
  `notify::state` reports the result back.

**Related:** any Ruby exception raised inside a signal handler unwinds through
the C stack and can leave GObject's signal emission in a broken state, so the
*next* unrelated emission segfaults. A stray `NoMethodError` in a handler is
therefore a crash, not a backtrace. Keep handlers total.

---

## 2. `GLib::Variant` cannot read a vardict at all

**blocker** · `glib2`

For `a{sv}` — the type GSettings uses for anything structured — every reader
raises:

```ruby
v = GLib::Variant.parse("{'a': <'x'>}", 'a{sv}')
v.value    # NotImplementedError: TODO: GVariant({sv}) -> Ruby
v.to_s     # same, via value
v.inspect  # same, via value
```

There is no escape hatch:

- `GLib::Variant` exposes only `value` and `type`; no `n_children`,
  `get_child_value`, or `get_string`.
- It exposes no pointer (`to_ptr`, `pointer`, `address` are all absent), so
  `g_variant_get_child_value` cannot be reached through Fiddle either.
- Introspection knows the methods but refuses the receiver:
  `ConstructorInfo#invoke` → `TypeError: GLib::Variant isn't supported`.

**Workaround (implemented).** Custom liveries — upstream's one `a{sv}` setting —
are stored as JSON in a string-typed key instead
(`lib/console_rb/settings.rb`, `palette.rb`, `livery.rb`). The schema documents
why. Nothing user-facing is lost: the dconf path belongs to this app alone, and
the format users actually exchange liveries in is the key file, which remains
byte-compatible with upstream.

---

## 3. `GLib::Variant` cannot *build* a tuple, and `set_value` cannot write one

**blocker** · `glib2`, `gio2`

```ruby
GLib::Variant.new([662, 514], '(ii)')
# NotImplementedError: TODO: Ruby -> GVariant((ii)): [662, 514]

GLib::Variant.new([GLib::Variant.new(662), GLib::Variant.new(514)])
# NotImplementedError: TODO: Ruby -> GVariantType
```

`GLib::Variant.parse` *can* build one — but note the argument order is
`(text, type)`, the reverse of what the name suggests, and passing them the
other way round gives the misleading `ArgumentError: invalid type string`.
Even with a valid tuple in hand, `Gio::Settings#set_value` re-converts the Ruby
object on the way in and fails again with the same `NotImplementedError`.

**Workaround (implemented).** Build with `parse`, write with `set_value_raw`
(`Settings#save_window_state`). Reading back with `get_value(...).to_a` works
fine — it is only the tuple-writing path that is broken.

```ruby
settings.set_value_raw('last-window-size',
                       GLib::Variant.parse("(#{width}, #{height})", '(ii)'))
```

---

## 4. `Vte::Regex.new` cannot construct a VteRegex

**blocker** · `vte4`

`Vte::Regex.new` resolves to GLib's `Regex` constructor. Every argument shape
fails, and the error never mentions the real problem:

```ruby
Vte::Regex.new('hello', -1, Vte::REGEX_FLAGS_DEFAULT)
# TypeError: no implicit conversion of Symbol into Integer
```

`Vte::Regex.methods - Module.methods` is `[:allocate, :gtype]` — the real
constructors (`new_for_search`, `new_for_match`) are not bound. Without them
there is no terminal search and no link detection.

**Workaround (implemented).** Invoke the introspected constructors directly.
The receiver must be an *allocated but uninitialised* `Vte::Regex` — passing the
class gives `TypeError: wrong argument type Class (expected GLib::Boxed)`:

```ruby
GObjectIntrospection::Repository.default
  .find('Vte', 'Regex').methods
  .find { |m| m.name.to_s == 'new_for_search' }
  .invoke(Vte::Regex.allocate, [pattern, -1, flags])
```

See `lib/console_rb/regex.rb`.

---

## 5. `Vte::REGEX_FLAGS_DEFAULT` is missing `PCRE2_MULTILINE`

**trap** · `vte4`

The exposed constant is `0x40180000`. VTE's own default includes
`PCRE2_MULTILINE` (`0x400`), and `vte_terminal_match_add_regex` rejects any
regex compiled without it:

```
VTE-WARNING: runtime check failed: (_vte_regex_has_multiline_compile_flag(regex))
```

The regex still constructs, so this only surfaces as links silently not working.

**Workaround (implemented).** OR the bit back in
(`Regex::MULTILINE = 0x400`, `lib/console_rb/regex.rb`).

---

## 6. `Vte::Terminal#spawn_async` misbinds arguments, and lies about errors

**trap** · `vte4`

The working signature is seven arguments:

```ruby
spawn_async(pty_flags, working_directory, argv, envv, spawn_flags, timeout, cancellable)
```

Passing five — which looks natural, and which the C signature suggests — does
not raise "wrong number of arguments". It silently rebinds the *fourth* argument
to `spawn_flags` and fails with `TypeError: no implicit conversion of Array into
Integer`, pointing at the wrong parameter entirely.

Worse, the completion callback's error argument is populated **on success**:

```ruby
spawn_async(...) { |_term, pid, err| }
# pid = 2470241, err = #<RuntimeError: GError parameter doesn't have a value.>
```

Treating a non-nil `err` as failure means every successful spawn is reported as
an error.

**Workaround (implemented).** Always pass seven arguments, and treat a positive
pid as the sole success signal (`lib/console_rb/tab.rb#spawn`).

---

## 7. `spawn_async` exposes no `child_setup` hook

**gap** · `vte4`

`vte_terminal_spawn_async` takes a `child_setup` callback that runs between fork
and exec. It is not bound, so anything that must happen in the child before exec
— upstream clears `IXON`/`IXOFF` there for the `software-flow-control` setting —
has nowhere to go.

**Workaround (implemented).** `Vte::Pty#fd` *is* bound, so the same flags are set
via `tcgetattr`/`tcsetattr` through Fiddle on the pty master, which Linux
propagates to the slave's line discipline (`lib/console_rb/termios.rb`).
Verified to flip the bits:

```
initial  iflag=0x0500 IXON=true  IXOFF=false
disabled iflag=0x0100 IXON=false IXOFF=false IXANY=false
enabled  iflag=0x1500 IXON=true  IXOFF=true
```

---

## 8. `Gtk::ShortcutTrigger.parse_string` is not bound

**gap** · `gtk4`

`Gtk::ShortcutTrigger` has no `parse_string` or `parse`, and
`Gtk::Shortcut.new('<Primary>c', action)` rejects the string form. Building a
`GtkShortcutController` from accelerator strings therefore has no direct route.

**Workaround (implemented).** `Gtk.accelerator_parse` plus
`Gtk::KeyvalTrigger.new(keyval, modifiers)` (`lib/console_rb/shortcuts.rb`).

---

## 9. `GLib.markup_escape_text` is not bound

**gap** · `glib2`

Absent from the `GLib` module. This matters because several Adwaita widgets
render their properties as Pango markup — `AdwActionRow#title` among them — so
any interpolated user data (here, process command lines) needs escaping.

**Workaround (implemented).** A local `gsub` over the five XML entities
(`lib/console_rb/close_dialog.rb`, `lib/console_rb/terminal.rb`).

---

## 10. `GetText::MO` rejects MO format revision 1.1

**blocker** · `gettext` 3.5.2

GNU `msgfmt` emits format revision 1.1 for some catalogues — of Console's 61
translations, Arabic and Persian — and the gem's reader refuses them outright:

```
GetText::MO::InvalidFormat: file format revision 65537 isn't supported
```

`65537` is `0x00010001`, i.e. major 1 minor 1. No `msgfmt` flag avoids it
(`--no-hash`, `--no-convert`, `--endianness` all still emit 1.1), and the cause
is not plural forms or sysdep strings — both files declare an ordinary
`nplurals=2`.

**Workaround (implemented).** Compile with the gem's own `rmsgfmt`
(`GetText::Tools::MsgFmt`), which always writes revision 0. Both the Rakefile
and the Nix build use it. All 61 catalogues now load.

---

## 11. Action parameters arrive unwrapped, but must be passed as Variants

**trap** · `gio2`

`Gio::SimpleAction`'s `activate` signal delivers a plain Ruby value for simple
types, not the `GLib::Variant` the C API documents:

```ruby
action = Gio::SimpleAction.new('focus-page', GLib::VariantType.new('u'))
action.signal_connect('activate') { |_act, parameter| parameter.value }
action.activate(GLib::Variant.parse('7', 'u'))
# NoMethodError: undefined method `value' for an instance of Integer
```

Going the other way is asymmetric: `Action#activate` and `#change_state` both
require an actual `GLib::Variant`. `SimpleAction#state` reads back unwrapped
too.

This one is dangerous rather than merely annoying, because of §1: the
`NoMethodError` raised inside the handler unwinds through GObject's signal
emission and takes the process down with a core dump, several steps later and
nowhere near the actual mistake. What looks like a crash in unrelated widget
code is a typo in a signal handler.

**Workaround (implemented).** `Application#unwrap` coerces either shape, and is
used everywhere an action parameter or state is read.

---

## 12. `Gtk::CustomFilter` segfaults at interpreter shutdown

**crash** · `gobject-introspection`, `glib2`

A `Gtk::CustomFilter` built from a Ruby block dies when GTK disposes it during
interpreter teardown — after ruby-gnome's GC marker table has already gone:

```
[BUG] Segmentation fault
g_hash_table_lookup
rbg_gc_marker_unguard          (glib2.so)
rb_gi_callback_data_free       (gobject_introspection.so)
gtk_custom_filter_dispose
gtk_multi_filter_dispose
```

It is intermittent and happens *after* the program's work is complete, so it
presents as a clean run that nonetheless exits with a core dump — easy to
mistake for a flaky test rather than a binding defect.

**Workaround (implemented).** Express the predicate as a `Gtk::BoolFilter` over
a `Gtk::PropertyExpression` instead, so no Ruby callback is involved. In this
port that is the monospace test in the font picker
(`lib/console_rb/font_picker.rb`) — which is also what upstream's `.ui` does:

```ruby
Gtk::BoolFilter.new(
  Gtk::PropertyExpression.new(Pango::FontFamily.gtype, nil, 'is-monospace')
)
```

Any callback-carrying GTK object built from a Ruby block is suspect here; prefer
an expression when the binding offers one.

---

## 13. `Adwaita::TabPage#title=` and `#tooltip=` reject nil

**trap** · `adwaita`

```ruby
page.tooltip = nil
# <Adw::TabPage#set_tooltip>: the 0th argument must not nil: <tooltip>
```

The C setters accept NULL. A tab that has not yet resolved a title or path
therefore crashes on its first refresh.

**Workaround (implemented).** Coerce with `.to_s` (`lib/console_rb/pages.rb`).

---

## 14. GObject-Introspection re-registers cairo's types without `GI_TYPELIB_PATH`

**crash** · `gobject-introspection`, packaging

Running outside a shell that sets `GI_TYPELIB_PATH`, loading `gtk4` aborts:

```
GLib-GObject-CRITICAL: cannot register existing type 'cairo_font_type_t'
GLib-CRITICAL: g_once_init_leave: assertion 'result != 0' failed
ArgumentError: NULL pointer given
```

The `cairo` gem's C extension has already registered those types; without the
typelib search path GI takes a different resolution path and registers them
again.

**Workaround (implemented).** The Nix wrapper sets `GI_TYPELIB_PATH` explicitly.
Note that `lib.makeSearchPath` takes each package's *first* output, and glib's
first output is `bin`, which contains no typelibs — the path must be built from
`.out` (`flake.nix`).

---

## 15. The Ruby `pkg-config` gem hard-fails on any missing transitive `.pc`

**trap** · `pkg-config` 1.6.5, packaging

It resolves `Requires.private` transitively and aborts the build if any `.pc` in
the closure is absent:

```
pkg-config.rb:663:in 'parse_pc': .pc doesn't exist: <xdmcp> (PackageConfig::NotFoundError)
```

Building the `gtk4` gem therefore needs gtk4's entire *private* dependency
closure present — X11, wayland, fontconfig, pcre2, brotli, and so on — not just
its public dependencies.

**Workaround (implemented).** The full closure is listed in `buildInputs`
(`flake.nix`).

---

## 16. Smaller traps

| Finding | Workaround |
|---|---|
| `Gtk::Window#is_active?` does not exist; the binding renames it `#active?`. | Use `#active?`. |
| `Gtk::CheckButton#group = self` trips `gtk_check_button_set_group: assertion 'self != group' failed`. The natural "build a hash of buttons, group each to the first" idiom hits this on the first button. | Leave the first button ungrouped (`lib/console_rb/theme_switcher.rb`). |
| `GApplication::command-line` uses `g_signal_accumulator_first_wins`, so emission stops after the first handler returns — a second observer never runs, with no warning. | Do not rely on a second handler; the test suite arms a timer instead. |
| The system `ruby` on NixOS is a `bundlerEnv` wrapper that `--set`s `BUNDLE_GEMFILE`, so it cannot be overridden from the environment and every `bundle` command targets a read-only store path. | Work inside `nix shell nixpkgs#ruby`, or unset it in the devshell hook. |

---

## Not a defect: `Adwaita::ApplicationWindow`

Included because the guidance this port was written against says otherwise.
The `ruby-gtk` skill's `adwaita-quirks.md` states that `Adwaita::Application`
and `Adwaita::ApplicationWindow` are broken and that `Gtk::ApplicationWindow`
should be used instead. As of `adwaita` 4.3.8 with libadwaita 1.9.3,
`Adwaita::ApplicationWindow` constructs and works, including `content=` and
`add_breakpoint`.

It is also required here: `Gtk::ApplicationWindow` has neither of those methods,
so a window with an `AdwBreakpoint` cannot be built without it.

`Adwaita::Application` was not retested — this port uses `Gtk::Application`
because it needs `:handles_command_line`, not because of any defect.

---

## Reporting

None of these have been filed upstream yet. The ones worth reporting to
[ruby-gnome](https://github.com/ruby-gnome/ruby-gnome/issues) are §1 and §12 (crashes),
§2 and §3 (`GLib::Variant` is largely unusable for structured settings), §4, §6,
§7, §11 and §12 (`vte4`, `gio2`, and the GC interaction). §10 belongs to [ruby-gettext](https://github.com/ruby-gettext/gettext).
