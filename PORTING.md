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
| `KgxPreferencesWindow` | `ConsoleRb::PreferencesDialog` |
| `KgxFontPicker` | `ConsoleRb::FontPicker` |
| `KgxSpad`, `KgxSpadSource`, `KgxSystemInfo` | `ConsoleRb::Spad`, `SystemInfo` |
| `KgxProxyInfo` | `ConsoleRb::ProxyInfo` |
| `KgxAbout` | `ConsoleRb::AboutDialog`, `SystemInfo` |
| `po/` (61 catalogues) | `po/`, `ConsoleRb::I18n` |

Widgets are built in code rather than from `.ui` templates, following the
declarative memoized-widget style: every widget is a memoized method that
configures itself in a `tap` block, and a single `build` method assembles the
tree.

### Dropped deliberately

These exist in the original to work around C's lack of closures and GObject's
lack of a value type, not because the terminal needs them. No user-visible
behaviour goes with them:

- **`GTree` page registry** (`kgx_application_add_page` / `lookup_page`, with
  weak refs and a `PageDiedData` struct). `Pages` keeps a plain hash keyed by
  widget, and `app.focus-page` — the registry's only consumer — is implemented
  as a lookup across the open windows.
- **`KgxDepot` / `KgxDespatcher`** — async wrappers around `vte_pty_spawn_async`
  and the D-Bus `OpenURI` portal. `Tab#spawn` calls `spawn_async` directly and
  `Terminal#launch` uses `Gtk::UriLauncher`.
- **`KGX_DEFINE_DATA` closure structs** (`PageDiedData`, `SpawnData`,
  `OpenURIData`, `ShowInData`, `StartData`) — every one is a Ruby block.
- **`KgxTemplated`, `kgx-*-closures.h`, `kgx-marshals.list`** — machinery for
  `.ui` template bindings, which this port does not use.
- **`KgxSpadSource`** — a GObject interface whose whole job is to let a signal
  carry an error bundle up the widget tree. Replaced by a callback.

### Not ported

Two things, both stated plainly rather than quietly dropped:

- **`--wait` beyond a single invocation.** The flag is implemented: the
  application holds itself open until the tabs that invocation started have
  exited. What is not reproduced is upstream's own TODO — it does not implement
  `--wait` either.
- **Tab tear-off by dragging to the desktop.** `win.detach-tab` moves a tab to a
  new window, and `AdwTabView::create-window` is wired, but dragging a tab out of
  the window onto the desktop is untested.

Everything else in the original is present. Three items that an earlier draft of
this file listed as "not ported" turned out to be workable and are now
implemented — see FINDINGS.md §2, §7 and the proxy notes:

- `software-flow-control` — via termios on the pty master, since `spawn_async`
  exposes no `child_setup` hook.
- Proxy environment injection — `org.gnome.system.proxy` mapped onto
  `http_proxy` and friends.
- Custom liveries — stored as JSON rather than `a{sv}`, because `GLib::Variant`
  cannot read a vardict at all. Key-file import and export stay
  byte-compatible with upstream.

## Ruby binding quirks

Every binding defect and gap found during the port — with reproductions,
severities and the workaround in use — is catalogued separately in
**[FINDINGS.md](FINDINGS.md)**. The short version: sixteen entries, of which three
are crashes, four are outright blockers, and one (`GLib::Variant` being unable
to read a vardict) forced a change to how a setting is stored.

The one that contradicts the guidance this port was written against:
`Adwaita::ApplicationWindow` is *not* broken in adwaita 4.3.8, and is required
here because `Gtk::ApplicationWindow` has neither `content=` nor
`add_breakpoint`.

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
