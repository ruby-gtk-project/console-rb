# Porting notes

What changed on the way from the C implementation to this one, and what the
Ruby GTK bindings would not let us do the obvious way.

## Architecture

The shape of the original survives; the scaffolding around it does not.

| GNOME Console (C) | console-rb |
|---|---|
| `KgxApplication` | `ConsoleRb::Application` |
| `KgxWindow` | `ConsoleRb::Window` |
| `KgxPages` | `ConsoleRb::Pages` |
| `KgxTab` + `KgxSimpleTab` | `ConsoleRb::Tab` |
| `KgxTerminal` | `ConsoleRb::Terminal` |
| `KgxSettings` | `ConsoleRb::Settings` |
| `KgxLivery`, `KgxPalette`, `KgxLiveryManager` | `ConsoleRb::Livery`, `Palette`, `Liveries` |
| `KgxTrain`, `KgxWatcher`, `KgxProcess`, `src/pids/` | `ConsoleRb::Train`, `Watcher`, `ProcessInfo` |
| `KgxCloseDialog` | `ConsoleRb::CloseDialog` |
| `KgxEmpty`, `KgxThemeSwitcher`, `KgxFullscreenBox` | `Empty`, `ThemeSwitcher`, `FullscreenBox` |
| `KgxDropTarget` | `ConsoleRb::DropTarget` |
| `KgxPreferencesWindow`, `KgxFontPicker` | `ConsoleRb::PreferencesDialog` |

Widgets are built in code rather than from `.ui` templates, following the
declarative memoized-widget style: every widget is a memoized method that
configures itself in a `tap` block, and a single `build` method assembles the
tree.

### Dropped deliberately

These exist in the original to work around C's lack of closures and GObject's
lack of a value type, not because the terminal needs them:

- **`GTree` page registry** (`kgx_application_add_page` / `lookup_page`, with
  weak refs and a `PageDiedData` struct). `Pages` keeps a plain hash keyed by
  widget. The `app.focus-page` action that was its only consumer is not ported;
  nothing in the UI reaches it.
- **`KgxDepot` / `KgxDespatcher`** — async wrappers around `vte_pty_spawn_async`
  and the D-Bus `OpenURI` portal. `Tab#spawn` calls `spawn_async` directly and
  `Terminal#launch` uses `Gtk::UriLauncher`.
- **`KGX_DEFINE_DATA` closure structs** (`PageDiedData`, `SpawnData`,
  `OpenURIData`, `ShowInData`, `StartData`) — every one is a Ruby block.
- **`KgxSpad` / `KgxSpadSource` / `KgxSystemInfo`** — the error-report dialog
  with attached system information. Errors surface as toasts instead.
- **`KgxTemplated`, `kgx-*-closures.h`, `kgx-marshals.list`** — machinery for
  `.ui` template bindings, which this port does not use.
- **`KgxFontPicker`** — a custom font-list widget. `Gtk::FontDialog` covers it.

### Not ported

Stated plainly so the gap is visible:

- **`--wait`** — upstream marks it TODO and does not implement it either.
- **Proxy environment injection** (`KgxProxyInfo`) — the child does not get
  `http_proxy` etc. synthesised from GNOME's proxy settings.
- **`software-flow-control`** — the setting is read but not applied. Upstream
  clears `IXON`/`IXOFF` in a `child_setup` callback that runs between fork and
  exec; the Ruby binding for `spawn_async` exposes no such hook.
- **Custom liveries** (`custom-liveries`, an `a{sv}` of user-defined palettes).
  The three built-ins are present; upstream ships no UI to create more either.
- **Tab tear-off by dragging** to the desktop. `win.detach-tab` moves a tab to a
  new window; dragging a tab out of the window does not.

## Ruby binding quirks

Findings that cost real debugging time. The skill's `adwaita-quirks.md` covers
namespace and constructor issues; these are additional, and one contradicts it.

### `Adwaita::ApplicationWindow` is *not* broken

The skill's quirks reference says to use `Gtk::ApplicationWindow` instead. With
adwaita 4.3.8 and libadwaita 1.9.3 that advice is out of date, and following it
is not an option here: the window needs `content=` and `add_breakpoint`, neither
of which `Gtk::ApplicationWindow` has.

### `Vte::Regex.new` cannot construct a VteRegex

`Vte::Regex.new` resolves to GLib's `Regex` constructor and raises
`TypeError: no implicit conversion of Symbol into Integer` for every argument
shape. The real constructors are only reachable through introspection, and the
receiver must be an *allocated* `Vte::Regex`:

```ruby
GObjectIntrospection::Repository.default
  .find('Vte', 'Regex').methods
  .find { |m| m.name.to_s == 'new_for_search' }
  .invoke(Vte::Regex.allocate, [pattern, -1, flags])
```

See `lib/console_rb/regex.rb`.

### `Vte::REGEX_FLAGS_DEFAULT` is missing `PCRE2_MULTILINE`

VTE rejects any match regex compiled without it
(`_vte_regex_has_multiline_compile_flag` runtime check), so `0x400` has to be
added back by hand.

### `spawn_async` takes seven arguments, and its error argument lies

`spawn_async(pty_flags, working_directory, argv, envv, spawn_flags, timeout,
cancellable)`. Passing five arguments silently rebinds them to the wrong
parameters. The callback's third argument is a `RuntimeError` reading
"GError parameter doesn't have a value" *on success* — a valid pid is the only
reliable success signal.

### `GSimpleAction#set_state` inside `change-state` segfaults

The documented C pattern — handle `change-state`, call
`g_simple_action_set_state` — re-enters through the introspection bindings and
crashes the process. Two consequences:

- `win.find` is a stateless action; the header bar toggle button carries the
  state and is kept in sync from the search bar's `notify::search-mode-enabled`.
- `app.theme` has no `change-state` handler at all. Without one, GLib updates
  the state itself, and `notify::state` reports it back.

### `GLib::Variant` cannot build a tuple, and `set_value` cannot write one

`GLib::Variant.new([w, h], '(ii)')` raises `NotImplementedError`.
`GLib::Variant.parse('(800, 600)', '(ii)')` builds one — note the argument order
is `(text, type)` — but `Gio::Settings#set_value` re-converts it and fails
again. `set_value_raw` is the only path that works. Reading with `get_value`
and `to_a` is fine.

### Other small ones

- `Gtk::ShortcutTrigger.parse_string` is not bound. Build triggers from
  `Gtk.accelerator_parse` + `Gtk::KeyvalTrigger.new` (`lib/console_rb/shortcuts.rb`).
- `GLib.markup_escape_text` is not bound; `AdwActionRow` titles render as markup,
  so escaping is done locally in `CloseDialog`.
- `Adwaita::TabPage#title=` and `#tooltip=` reject `nil`.
- `Gtk::Window#is_active?` does not exist; it is `#active?`.
- `Gtk::CheckButton#group = self` trips a GTK assertion — the first button in a
  radio group must be left ungrouped.
- `GApplication::command-line` stops after the first handler returns, so there is
  no signal left for a second observer to hook.

## Packaging

Four things the devshell provides implicitly that the wrapper must set:

1. `bin/` must sit beside `lib/` for the launcher's `require_relative`.
2. `-rbundler/setup`, or the bundled gems are not on the load path.
3. `GI_TYPELIB_PATH`, or GObject-Introspection re-registers cairo types the
   cairo gem's C extension already registered and aborts. Build it with an
   explicit `.out` — glib's *first* output is `bin`, which has no typelibs.
4. The GSettings schema path. glib's setup hook relocates
   `share/glib-2.0/schemas` to `share/gsettings-schemas/$name` during fixup,
   which is after `wrapGAppsHook4` computes its wrapper arguments — so that hook
   is not used and the wrapper points at both locations.

The Ruby `pkg-config` gem resolves `Requires.private` transitively and hard-fails
on any missing `.pc`, so gtk4's entire private closure (X11, wayland, fontconfig,
pcre2, …) has to be in `buildInputs`, not just its public dependencies.

## Application id

The app id and schema are `org.gnome.Console.Rb` at `/org/gnome/Console/Rb/`,
not upstream's `org.gnome.Console`, so this port can be installed alongside
GNOME Console without the two fighting over the same dconf keys.
