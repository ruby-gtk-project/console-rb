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
- **`KGX_DEFINE_DATA` closure structs** (`PageDiedData`, `SpawnData`,
  `OpenURIData`, `ShowInData`, `StartData`) — every one is a Ruby block, so no
  struct is needed to carry state into an async callback.
- **`KgxTemplated`, `kgx-*-closures.h`, `kgx-marshals.list`** — machinery for
  `.ui` template bindings, which this port does not use; widgets are built in
  code (see Architecture, above).

`KgxDepot`/`KgxDespatcher` and `KgxSpadSource` were listed here in an earlier
draft of this file as dropped. That was wrong even then — this port still
needs an async spawn path, a portal `OpenURI` call, and a way for a spad to
report an error up through the tab — and it is now also stale: both are
ported as real classes, `lib/console_rb/depot.rb` and
`lib/console_rb/despatcher.rb`, and `KgxSpadSource` is
`lib/console_rb/spad_source.rb`, a plain Ruby mixin in place of the GObject
interface (a module with `include`d callback state rather than a vtable,
since Ruby has no need of the interface machinery to get the same contract).
Their behaviour, not just their presence, is scored on the component-parity
ledger — see `COMPONENT_PARITY.md` units for Depot/Despatcher and SpadSource.

### Not ported

I have not ported these. Both are stated plainly rather than quietly dropped
or stubbed:

- **`--wait` beyond a single invocation.** The flag is implemented: the
  application holds itself open until the tabs that invocation started have
  exited. What is not reproduced is upstream's own TODO — it does not implement
  `--wait` either, so there is no further behaviour on the other side to port.
- **Tab tear-off by dragging to the desktop.** `win.detach-tab` moves a tab to a
  new window, and `AdwTabView::create-window` is wired, but I have not verified
  that dragging a tab out of the window onto the desktop actually produces a
  second top-level window end to end; it is wired but untested.

See `COMPONENT_PARITY.md` for the fuller, currently-tracked list of gaps this
round did not close (tab context menu, `translucent`/`devel` style classes,
`Gtk::WindowGroup`, the `tab` action group, `Adw::Breakpoint` apply/unapply,
extra drop targets, and others) — that ledger, not this file, is the
up-to-date source for what remains.

Three items that an earlier draft of this file listed as "not ported" turned
out to be workable and are now implemented — see FINDINGS.md §2, §7 and the
proxy notes:

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
