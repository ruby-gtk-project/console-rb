# Parity report — ruby-gtk-project/console-rb

| | |
|---|---|
| Reviewed | 2026-09-20 |
| Port | `ruby` @ `780c3ca` |
| Original | `main` @ `599b703` |
| Verdict | **FAIL** |

## Summary

The port covers the core terminal, tab, settings, preferences, drag-and-drop,
search, close-confirmation, and command-line flows, but it is not behaviorally
complete. The original's tab context menu is absent, the `--command` plus
positional-argument conflict is accepted, and several user-facing integrations
are missing: inactive-tab command-completion notifications, Ctrl-click link
opening and its tooltip, and the terminal size status overlay.

## Metrics

| Category | Original | Found | Gaps | Coverage |
|---|---:|---:|---:|---:|
| actions | 14 | 14 | 0 | 100% |
| accels | 0 | 0 | 0 | 100% |
| settings | 18 | 18 | 0 | 100% |
| menulabels | 15 | 13 | 2 | 86% |
| widgets | 56 | 47 | 1 | 83% |
| cli | 2 | 1 | 1 | 50% |
| strings | 45 | 25 | 3 | 55% |
| datafiles | 4 | 0 | 0 | 0% |

## Gaps

### Tab context menu

The original exposes `_Detach Tab` and `_Close` in the `AdwTabView` tab menu
(`src/kgx-pages.ui`, `tab.detach` and `tab.close`). The port implements the
`win.detach-tab` and `win.close-tab` actions in `lib/console_rb/window.rb` and
`lib/console_rb/pages.rb`, but never installs a tab menu model or those two
menu entries, so the tab-menu commands and labels are unavailable.

### Command-line conflict handling

The original rejects `--command` together with positional parameters in
`src/kgx-utils.c` (`Cannot use both --command and positional parameters`).
`lib/console_rb/cli.rb` only rejects `--working-directory` with positional
paths, so `console-rb --command foo directory` is accepted and opens a tab
instead of reporting the conflict.

### Inactive-tab command completion notification

When a command completes in an inactive tab, `src/kgx-tab.c` sends a
`Command completed` desktop notification and withdraws it when the tab becomes
active. `lib/console_rb/tab.rb` reports exit state and closes ordinary shell
tabs, but has no application notification path.

### Ctrl-click link opening and link tooltip

`src/kgx-terminal.c` attaches a `GtkGestureClick` that opens a matched URI on
Ctrl-primary/middle-click and supplies the `Ctrl-click to open:` tooltip.
`lib/console_rb/terminal.rb` provides link matching, context-menu actions, and
URI launchers, but no click gesture or matching tooltip.

### Terminal size status overlay

The original emits terminal row/column changes from `kgx-terminal.c` and shows
the transient `"%i columns %i rows"` status overlay in `src/kgx-pages.ui`.
The port has no size-change signal or floating size indicator.

## Behaviour checked

The source flow from application startup through window creation, shell/explicit
command spawning, PTY setup, child exit, read-only exit banners, ordinary-shell
auto-close, explicit-command retention, and `--wait` completion is present in
`application.rb` and `tab.rb`. Search, copy/paste, sudo-paste confirmation,
link context actions, file display, drag-and-drop quoting, theme and palette
selection, font filtering/preview, scrollback and bell preferences, close
confirmation, tear-off transfer, fullscreen state, saved geometry, and
single-instance command-line routing are also wired end to end.

Empty/loading and failed-spawn states are represented by the empty spinner and
read-only/error banner. Settings and custom livery persistence are covered by
the GSettings schema and the port's JSON/key-file paths; the renamed desktop,
metainfo, schema, and D-Bus service files are present under `data/`. Clipboard,
URI launching, and drop handling have Ruby implementations. The gaps above are
the behavior found missing during this static comparison.

## Dismissed

- `AdwShortcutsItem`, `AdwShortcutsSection`: represented by
  `ShortcutsDialog` preference groups and action rows.
- `AdwTabPage`: represented by `Adwaita::TabView` page objects returned by
  `append`.
- `GtkBuilderListItemFactory`: replaced by `Gtk::SignalListItemFactory` in
  `font_picker.rb`.
- `GtkEntryBuffer`: entry buffers are supplied by the Ruby `Gtk::Entry` and
  `Gtk::SearchEntry` widgets; no separate builder object is needed.
- `GtkListItem`: used implicitly as the item passed to the signal list-item
  factory's setup/bind callbacks.
- `GtkStackPage`: created implicitly by `Gtk::Stack#add_child`/`add_named`.
- `GtkTextBuffer`: `Spad#message_view` uses the `Gtk::TextView` buffer directly.
- `# KGX %s using VTE %u.%u.%u %s`: `SystemInfo.report` supplies equivalent
  port/VTE/runtime diagnostics with the port application identity.
- `%i by %i`: an upstream diagnostic-format fragment; the port emits Ruby and
  renderer diagnostics through `SystemInfo`, not the same C process-size line.
- `Color string is wrong length`: palette parsing validates and raises an
  equivalent `ArgumentError` with Ruby wording.
- `GPL 3.0 or later`: the About dialog sets `Gtk::License::GPL_3_0`.
- `KGX %s — Terminal Emulator`: the port's About and `--about` output identify
  `console-rb` and its Ruby GTK port instead.
- `Missing argument for --command`: `OptionParser` reports the equivalent
  missing-value error; the conflict case itself remains a real CLI gap above.
- `No Font Set`: the port falls back to the system monospace font when no
  custom font is selected.
- `Process %d`: `ProcessInfo` and `CloseDialog` render the process title and
  arguments without the original numeric format.
- `Process list`: the port renders the same running-command rows in
  `CloseDialog`; the original's accessibility-only list label is not a
  separate user flow in the Ruby construction.
- `Tab %i`: Adwaita supplies tab pages and labels from the port's tab titles.
- `The GNOME Project`: the independent port correctly credits the Ruby GTK
  project rather than claiming GNOME authorship.
- `Unable To Open`: URI and file-launch failures are represented by the port's
  localized toast and `Spad` error-details flow.
- `Wait until the child exits (TODO)`: the port implements the wait path; the
  original text describes its own TODO rather than a required user feature.
- `[-e|-- COMMAND [ARGUMENT...]]`: reproduced in the Ruby `OptionParser` banner.
- `© %s Zander Brown`: the original copyright is retained in the About dialog.
- `GtkGestureClick`: unlike the other widget-name substitutions, this one
  remains a real gap because no equivalent click controller is installed; it
  is counted with the Ctrl-click gap above.
- `data/org.gnome.Console.desktop.in.in`,
  `org.gnome.Console.gschema.xml.in`,
  `org.gnome.Console.metainfo.xml.in.in`, and
  `org.gnome.Console.service.in`: all four packaging surfaces exist under
  renamed `org.gnome.Console.Rb` files in `target/data/`.

## Not verifiable here

This review is static. It does not verify visual layout, animation timing,
accessibility presentation, actual keyboard or pointer event delivery,
desktop notification delivery, portal behavior, performance, or packaging
installation on a real desktop session.

```json
{
  "categories": {
    "actions": {"upstream": 14, "found": 14, "missing": 0, "coverage": 100},
    "accels": {"upstream": 0, "found": 0, "missing": 0, "coverage": 100},
    "settings": {"upstream": 18, "found": 18, "missing": 0, "coverage": 100},
    "menulabels": {"upstream": 15, "found": 13, "missing": 2, "coverage": 86},
    "widgets": {"upstream": 56, "found": 47, "missing": 9, "coverage": 83},
    "cli": {"upstream": 2, "found": 1, "missing": 1, "coverage": 50},
    "strings": {"upstream": 45, "found": 25, "missing": 20, "coverage": 55},
    "datafiles": {"upstream": 4, "found": 0, "missing": 4, "coverage": 0}
  },
  "port_ruby_files": 49,
  "upstream_source_files": 129,
  "verdict": "FAIL",
  "gaps": 7
}
```
