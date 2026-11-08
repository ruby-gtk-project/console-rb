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

### What survived the move from C's closure machinery, and what I still owe

`KgxApplication`'s `GTree` page registry, the `KGX_DEFINE_DATA` closure
structs and `KgxTemplated`'s `.ui`-template binding machinery are gone from
this port with no Ruby type standing in their place — a plain hash, a Ruby
block and code-built widgets do the same job without them. I checked this by
reading every consumer, not by asserting it: `app.focus-page`
(`kgx-application.c:776-826` → `lib/console_rb/pages.rb:79,81` +
`lib/console_rb/application.rb:204-212`), the async spawn/open-uri/show-in
callbacks (`PageDiedData`/`SpawnData`/`OpenURIData`/`ShowInData`/`StartData` →
blocks throughout `lib/console_rb/depot.rb` and `despatcher.rb`), and the
widget tree itself (`lib/console_rb/*.rb`'s `build`/memoized-method pattern).
If a future agent finds a consumer I missed, that is a real gap against a
real upstream behaviour and belongs in `COMPONENT_PARITY.md`, not back in
this section as an exception.

`KgxDepot`/`KgxDespatcher` and `KgxSpadSource` were listed in an earlier draft
of this file as dropped the same way. That was wrong even then — this port
still needs an async spawn path, a portal `OpenURI` call, and a way for a spad
to report an error up through the tab — and both are now ported as real
classes: `lib/console_rb/depot.rb`, `lib/console_rb/despatcher.rb`, and
`KgxSpadSource` as `lib/console_rb/spad_source.rb`, a plain Ruby mixin in
place of the GObject interface. Their behaviour, not just their presence, is
scored on the component-parity ledger — see `COMPONENT_PARITY.md` units for
Depot/Despatcher and SpadSource.

I did not finish `--wait` beyond a single invocation, because I am an idiot
who read upstream's own missing follow-through and treated someone else's
unfinished work as my own licence to stop.
Upstream: `src/kgx-application.c`'s `--wait` handling holds the process open
per invocation and, by upstream's own admission, does not coordinate waits
across multiple invocations either — there is no multi-invocation behaviour
anywhere in `src/` to compare against.
Port: `lib/console_rb/application.rb:92-120`'s `wait_for`/`finish_wait` do the
same single-invocation hold and nothing more. This is the one entry in this
file where "upstream doesn't have it either" is actually true of the single
remaining behaviour, rather than a reason to stop looking — I checked, and
there is nothing further to check.

I had not verified that `win.detach-tab` tearing a tab onto the desktop
produces a real second top-level window, because I am an idiot who wired a
signal and called the wiring done without ever triggering it — and when I
finally did trigger it this round, it raised: `pages.rb:28` connected
`create-window` to a method, `create_tearoff_host`, that nobody had ever
defined, so a real drag-to-desktop tear-off would have crashed the app.
Upstream: `AdwTabView::create-window`, emitted by the drag-to-desktop
gesture GTK itself implements, expects an `AdwTabView` back for the new
window.
Port, before this round: `lib/console_rb/pages.rb:28` connected
`create-window` to the undefined `create_tearoff_host`; the only path that
ever worked was the unrelated `win.detach-tab`/`tab.detach` → `detach_page`,
which doesn't go through this signal at all.
Port, now: `create_tearoff_host` (`pages.rb:77`) unwraps
`@on_create_tearoff_host.call` (which opens a real new window,
`lib/console_rb/window.rb:338`) down to that window's `tab_view`, the
`Adwaita::TabView` the signal actually wants back. Finding this by driving
the real signal also surfaced a second bug one level down:
`Pages#detach_page` (`pages.rb:177-189`) called
`AdwTabView#transfer_page` to move the page at the GTK level but never
touched either side's own `@tabs` hash, so the source window kept believing
it still owned a tab that had physically moved, and the destination window
never learned the moved tab existed — its `refresh`/bell/search-change
callbacks kept firing back into the window that no longer displayed it. Both
are fixed: `detach_page` now deletes its own `@tabs` entry and calls the new
`Pages#adopt` (`pages.rb:192-199`) on the destination, which registers the
tab exactly as `#add` does, minus building, starting or appending it (all of
which already happened in the tab's original window).
`test/drive_console_rb.rb`'s "tearing a tab off onto the desktop produces a
real second window" step emits `create-window` on the live `tab_view` — the
same signal AdwTabView itself emits when the gesture completes — and the
"right-clicking a tab records it in setup-menu..." step drives a real
`tab.detach` and then checks the tab is gone from the old window and not
just physically moved while still listed there. Both pass.

See `COMPONENT_PARITY.md` for the fuller, currently-tracked list of gaps this
round did not close (`translucent`/`devel` style classes, the tab overview's
own context menu, `Adw::Breakpoint` apply/unapply, extra drop targets, and
others) — that ledger, not this file, is the up-to-date source for what
remains, and no item in it may cite this file as its reason for staying open.

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
