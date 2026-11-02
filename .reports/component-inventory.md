# console-rb — upstream component inventory

Upstream: GNOME Console (`kgx`), C + GtkBuilder `.ui`, read from `origin/main`.
Port: the `ruby` branch, `lib/console_rb/*.rb`.

Upstream splits almost every component across two files — `src/kgx-foo.c`
(subclass, template children, callbacks, actions) and `src/kgx-foo.ui` (widget
tree, CSS classes, signals, menus). The rows below union both halves.

## Summary

| | upstream | port |
|---|---|---|
| user-facing component files | 21 | 21 present |
| infrastructure / model files | 15 | 15 present (3 upstream files have no Ruby counterpart by design) |
| bundled app icons (`src/icons/scalable/status`) | 8 | 8 under `data/icons/hicolor/scalable/status` |
| GSettings keys | 17 | 17 |
| `po/` catalogue | 61 languages | 61 `po/*.po`, 61 under `data/locale` |

Revised after `464a7a0` ("Port the spad source, watcher, livery manager, depot,
despatcher, paste dialog and simple tab") and the icon vendoring: every upstream
user-facing component now has a `lib/*.rb` file of its own.

## Windows, views and pages

### `src/kgx-window.c` + `src/kgx-window.ui` → `lib/console_rb/window.rb` — the terminal window
Present.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | `terminal-window`, + `translucent`, `root`, `remote`, `playbox`, `devel` (dynamic) | `notify::fullscreened` → `fullscreened_changed`, `close-request` | 360×294 minimum |
| `Adw.TabOverview` | 1 | — | `create-tab` → `create_tab_cb` | `enable-new-tab`, secondary menu |
| `KgxFullscreenBox` | 1 | — | — | autohide driven by menu popover visibility |
| `Gtk.Stack` | 1 | — | — | `content` / `empty` pages |
| `Adw.HeaderBar` | 1 | — | — | |
| `Adw.WindowTitle` | 1 | — | — | subtitle from cwd |
| `Gtk.ToggleButton` | 1 | — | `win.find` | "Find in Terminal", `edit-find-symbolic` |
| `Gtk.Button` (leave fullscreen) | 1 | — | `win.unfullscreen` | `view-restore-symbolic` |
| `Gtk.MenuButton` + `Gtk.PopoverMenu` | 1 | — | — | hosts `theme-switcher` and `zoom-controls` custom slots |
| `Gtk.Button` (zoom) | 3 | `circular`+`flat`, `flat`+`numeric`, `circular`+`flat` | `app.zoom-out`, `app.zoom-normal`, `app.zoom-in` | middle button shows a percentage `Gtk.Label` |
| `Adw.TabButton` | 1 | — | `win.show-tabs` | narrow mode only |
| `Gtk.Button` (new tab) | 1 | — | `win.new-tab` | `tab-new-symbolic` |
| `Adw.TabBar` | 1 | — | `extra-drag-drop` | inverted per decoration layout |
| `Adw.Breakpoint` | 1 | — | `apply` / `unapply` | `max-width: 400px`; swaps tab button for tab bar |

Menus: **primary menu** — theme switcher slot, zoom controls slot, `win.new-window`,
`win.show-tabs-desktop`, `win.fullscreen`, `win.show-preferences-window`,
`app.shortcuts`, `win.about`. **secondary (overview) menu** — `win.new-window`,
`win.fullscreen`, `win.unfullscreen`. Both reproduced in `window.rb`.

Window actions installed: `win.new-window`, `win.new-tab`, `win.close-tab`,
`win.about`, `win.show-tabs`, `win.show-tabs-desktop`,
`win.show-preferences-window`, `win.fullscreen`, `win.unfullscreen`, `win.find`
(property action), plus `tab.close` / `tab.detach` for the tab menu.

### `src/kgx-pages.c` + `src/kgx-pages.ui` + `src/kgx-page-expression.ui` → `lib/console_rb/pages.rb` — the tab view
Present. `kgx-page-expression.ui` is a bare `AdwTabPage` expression file with no
C half; its bindings (title, tooltip, needs-attention, loading, icon, keyword,
indicator-icon) are reproduced imperatively in `pages.rb#sync_page`.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | |
| `Gtk.Overlay` | 1 | — | — | |
| `Adw.TabView` | 1 | — | `page-attached`, `page-detached`, `create-window`, `close-page`, `setup-menu` | menu model `tab-menu`, default icon `status-regular-symbolic` |
| `Gtk.Revealer` (status) | 1 | — | — | crossfade, a11y role `status` |
| `Gtk.Label` (size readout) | 1 | `floating-bar`, `numeric` | — | "WxH" |
| `Gtk.Revealer` (drop) | 1 | — | — | revealed while a drag hovers |
| `Adw.Bin` (drop highlight) | 1 | `drop-highlight` | — | |

Menu: **tab menu** — `tab.detach`, `tab.close`.
Repeater: one `Adw.TabPage` + `KgxTab` per open tab.

### `src/kgx-tab.c` + `src/kgx-tab.ui` → `lib/console_rb/tab.rb` — one terminal session
Present.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | `dropping` bound from the drop target |
| `Adw.ToastOverlay` | 1 | — | — | copy/paste/launch failure toasts |
| `Gtk.Box` | 1 | — | — | vertical |
| `Adw.ToolbarView` | 1 | — | — | |
| `Gtk.SearchBar` | 1 | `view` | `notify::search-mode-enabled` → `search_enabled` | |
| `Adw.Clamp` | 1 | — | — | max 500 |
| `Gtk.SearchEntry` | 1 | — | `next-match`, `previous-match`, `search-changed` | placeholder "Find text" |
| `Gtk.ShortcutController` + `Gtk.Shortcut` ×2 | 1 / 2 | — | `Return` → next-match, `<shift>Return` → prev-match | on the search entry |
| `Gtk.Button` (prev/next match) | 2 | — | `clicked` → `search_prev` / `search_next` | `go-up-symbolic`, `go-down-symbolic` |
| `Gtk.Stack` | 1 | — | — | crossfade, 10ms |
| `KgxEmpty` | 1 | — | — | shown while the shell starts |
| `Gtk.Revealer` (exit banner) | 1 | `background`, + `error` (dynamic) | — | slide-up |
| `Gtk.Label` (exit message) | 1 | `exit-info` | — | Pango markup, wrapped |
| `KgxDropTarget` | 1 | — | `drop`, `spad-thrown` | |

Actions: `tab.show-spad`.

### `src/kgx-simple-tab.c` + `src/kgx-simple-tab.ui` → `lib/console_rb/simple_tab.rb` — the scrolled terminal inside a tab
Present (71 lines). `Gtk.ScrolledWindow` with CSS `terminal`,
`hscrollbar-policy: never`, holding a `KgxTerminal`, plus the `tab-tooltip`
binding. Upstream subclasses its own widget here (`KgxSimpleTab : KgxTab`); the
port composes instead of inheriting, so the hierarchy is flattened but every
widget, CSS class and signal is reproduced.

### `src/kgx-terminal.c` + `src/kgx-terminal.ui` → `lib/console_rb/terminal.rb` — the VTE widget
Present.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Vte.Terminal` (template root) | 1 | — | `termprop-changed::vte.cwf`, `termprop-changed::vte.cwd` → `location_changed`, `setup-context-menu` | hyperlinks, pixel scroll units, a11y on |
| `Gtk.ShortcutController` + `Gtk.Shortcut` ×4 | 1 / 4 | — | `<Shift><Primary>c/v`, `Copy`, `Paste` | capture phase, named `kgx-terminal-shortcuts` |
| `Gtk.GestureClick` | 1 | — | `pressed` | button 0, context menu |
| `Gtk.EventControllerScroll` | 1 | — | `scroll` | vertical+discrete, ctrl-zoom |

Menu: **context menu** — `term.open-link`, `term.copy-link`, `term.copy`,
`term.paste`, `term.select-all`, `win.unfullscreen`, `term.show-in-files`; every
item `hidden-when: action-disabled`.
Actions: `term.copy`, `term.paste`, `term.select-all`, `term.open-link`,
`term.copy-link`, `term.show-in-files`.

### `src/kgx-empty.c` + `src/kgx-empty.ui` → `lib/console_rb/empty.rb` — the empty / starting state
Present. `Gtk.Box` (vertical, 16) → `Gtk.Revealer` (crossfade 1000ms) with a
128px `Gtk.Image` of the app icon, and a second `Gtk.Revealer` with an
`Adw.Spinner` (32×32). CSS: element selector `kgx-empty` upstream, renamed
`.console-rb-empty` in the port's `data/style.css`.

### `src/kgx-fullscreen-box.c` + `src/kgx-fullscreen-box.ui` → `lib/console_rb/fullscreen_box.rb`
Present. `Adw.Bin` → `Adw.ToolbarView` (CSS `main-box`, `top-bar-style: raised`),
plus a `Gtk.EventControllerMotion` (`motion`, `enter`) and a touch-only
`Gtk.GestureClick` (`pressed`) that reveal the header bar in fullscreen.

### `src/kgx-theme-switcher.c` + `src/kgx-theme-switcher.ui` → `lib/console_rb/theme_switcher.rb`
Present. `Adw.Bin` → `Gtk.Box` (homogeneous, spacing 18) → three
`Gtk.Overlay` each holding a `Gtk.CheckButton` (CSS `system`, `light`, `dark`,
radio-grouped, `notify::active` → `theme_check_active_changed`) overlaid with a
13px `Gtk.Image` (CSS `check`). CSS: `themeswitcher` element selector.
**Gap:** upstream's overlay uses the bundled `theme-check-symbolic`; the port
substitutes stock `object-select-symbolic`.

## Dialogs

### `src/kgx-close-dialog.c` → `lib/console_rb/close_dialog.rb` — "Close Tab?" / "Close Window?"
Present. `Adw.AlertDialog` with responses `cancel` ("_Cancel") and `close`
("C_lose", destructive), close-response `cancel`, and an extra child
`Gtk.ListBox` (CSS `boxed-list`, `process-list`, a11y label "Process list",
selection none, not focusable) repeating one `Adw.ActionRow` per running
command. Headings and bodies are plural-aware (`g_dngettext`).

### `src/kgx-paste-dialog.c` → `lib/console_rb/paste_dialog.rb` — admin paste confirmation
Present (74 lines). `Adw.AlertDialog`, heading "You are pasting a command that
runs as an administrator", CSS `numeric`, responses `cancel` / `paste`
(destructive), body truncated to 8000 chars. Called from `terminal.rb`.

### `src/kgx-spad.c` + `src/kgx-spad.ui` → `lib/console_rb/spad.rb` — "Error Details"
Present.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` (template root) | 1 | `error-details` | — | 550×400 |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 / 1 | — | — | |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | description = error body; second titled "Error Message" |
| `Gtk.Button` (copy) | 1 | `flat` | `spad.copy-message` | icon flips to a tick after copying |
| `Gtk.ScrolledWindow` | 1 | `card` | — | |
| `Gtk.TextView` | 1 | `error-message`, `monospace` | — | read-only, optional appended system info |
| `Gtk.Button` (report) | 1 | `suggested-action`, `pill` | `spad.open-issues` | `Adw.ButtonContent`, `external-link-symbolic` |

Visibility of both the group and the report button is flag-driven
(`show-sys-info`, `show-report`).

### `src/kgx-about.c` → `lib/console_rb/about_dialog.rb`
Present. `adw_show_about_dialog` with app name/icon, developer name "The GNOME
Project", issue and website URLs, version, copyright, debug info
(`kgx-info.txt`), developers, designers, `translator-credits`, GPL-3.0+. The
same file also prints the ASCII logo (`src/logo.txt`) and `--version` banner —
in the port those live in `cli.rb` / `about_dialog.rb`.

### `src/shortcuts-dialog.ui` → `lib/console_rb/shortcuts_dialog.rb`
Present. Standalone `Adw.ShortcutsDialog` with no C half, four
`Adw.ShortcutsSection`s and 17 `Adw.ShortcutsItem`s: Application (New Window);
Terminal (Find, Copy, Paste); Tabs (New Tab, Close Tab, Show All Tabs, Next
Tab, Previous Tab, Move Tab Left/Right ×2 for ltr and rtl, Switch to Tab 1–9,
Switch to Tab 10); Window (Fullscreen). Reached through `app.shortcuts`.

## Preferences

### `src/preferences/kgx-preferences-window.c` + `.ui` → `lib/console_rb/preferences_dialog.rb`
Present. `Adw.PreferencesDialog` → one `Adw.PreferencesPage` ("General") with
three groups:

| Group | Rows |
|---|---|
| Font | `Adw.SwitchRow` "Use _System Default"; `Adw.ActionRow` "Custom _Font" (activatable, `prefs.select-font`) with a `Gtk.Label` (CSS `dim-label`, ellipsize middle, font-rendered label) and a `go-next-symbolic` `Gtk.Image` |
| Behavior | `Adw.SwitchRow` "_Unlimited Scrollback"; `Adw.SpinRow` "_Scrollback Lines" (0–800000, step 1000, insensitive while unlimited) |
| Terminal Bell | description "Control how alerts are indicated"; `Adw.SwitchRow` "Play _Sound"; `Adw.SwitchRow` "_Visual Effects" |

### `src/preferences/kgx-font-picker.c` + `.ui` → `lib/console_rb/font_picker.rb`
Present. `Adw.NavigationPage` (title "Terminal Font", tag `font-picker`) →
`Adw.ToolbarView` with an `Adw.HeaderBar` (no title buttons, no back button)
holding "_Cancel" (`navigation.pop`) and "_Select" (`picker.select`,
`suggested-action`); content is a `Gtk.Box` (CSS `font-picker`) with a
`Gtk.SearchEntry` ("Font Name"), a `Gtk.ScrolledWindow` (CSS `frame`, `view`,
max height 400) around a `Gtk.ListView` (separators, a11y "Font Family",
`activate`) over `Gtk.SingleSelection` → `Gtk.FilterListModel` (incremental,
`notify::pending`) → `Gtk.EveryFilter` of a `Gtk.StringFilter` on family name
and a `Gtk.BoolFilter` on `is-monospace`, with a list-item factory rendering a
`Gtk.Label` (CSS `font-item`) in the face's own font; then a preview `Gtk.Entry`
(a11y "Font Preview") and a `Gtk.SpinButton` (a11y "Font Size", 1–1000).

## Application, actions and keyboard shortcuts

### `src/main.c` + `src/kgx-application.c` → `lib/console_rb/application.rb`, `lib/console_rb/cli.rb`, `lib/console_rb/launcher.rb`
Present. Application actions: `app.new-window`, `app.new-tab`,
`app.focus-page` (`u`), `app.zoom-out`, `app.zoom-normal`, `app.zoom-in`, plus a
`theme` stateful action. Accelerators (all present in `shortcuts.rb` /
`application.rb`):

| Action | Accelerators |
|---|---|
| `win.new-window` | `<shift><primary>n`, `New` |
| `win.new-tab` | `<shift><primary>t`, `<shift>New` |
| `win.close-tab` | `<shift><primary>w` |
| `term.copy` | `<shift><primary>c`, `Copy` |
| `term.paste` | `<shift><primary>v`, `Paste` |
| `win.find` | `<shift><primary>f`, `Find` |
| `app.zoom-in` | `<primary>plus`, `ZoomIn` |
| `app.zoom-out` | `<primary>minus`, `ZoomOut` |
| `app.zoom-normal` | `<primary>0` |
| `win.show-tabs` / `win.show-tabs-desktop` | `<shift><primary>o` |
| `win.fullscreen` / `win.unfullscreen` | `<shift><primary>F11` |

## Models, settings and helpers

| Upstream | Port | Present |
|---|---|---|
| `src/kgx-settings.c`, `src/kgx-settings.ui.in`, `data/org.gnome.Console.gschema.xml.in` | `lib/console_rb/settings.rb`, `data/schemas` | yes — all 17 keys and the `Theme` enum (`auto`/`night`/`day`/`hacker`) |
| `src/kgx-livery.c` | `lib/console_rb/livery.rb` | yes |
| `src/kgx-livery-manager.c` | `lib/console_rb/livery_manager.rb` | yes (66 lines) |
| `src/kgx-palette.c`, `src/kgx-colour-utils.c` | `lib/console_rb/palette.rb` | yes |
| `src/kgx-train.c` | `lib/console_rb/train.rb` | yes |
| `src/kgx-watcher.c` | `lib/console_rb/watcher.rb` | yes (80 lines) |
| `src/kgx-process.c`, `src/pids/*` | `lib/console_rb/process_info.rb` | yes |
| `src/kgx-proxy-info.c` | `lib/console_rb/proxy_info.rb` | yes |
| `src/kgx-system-info.c` | `lib/console_rb/system_info.rb` | yes |
| `src/kgx-drop-target.c` | `lib/console_rb/drop_target.rb` | yes |
| `src/kgx-depot.c` | `lib/console_rb/depot.rb` | yes (84 lines) — one depot per application, see `application.rb:50` |
| `src/kgx-despatcher.c` | `lib/console_rb/despatcher.rb` | yes (123 lines) — one despatcher per application |
| `src/kgx-spad-source.c/.h` | `lib/console_rb/spad_source.rb` | yes (62 lines) — the `spad-thrown` interface |
| `src/kgx-utils.c`, `src/kgx-*-closures.h` | — | closures reimplemented inline where used |
| `src/kgx-templated.c`, `src/kgx.gresource.xml.in`, `src/kgx-marshals.list` | — | n/a: no GtkBuilder templates or GResource in the Ruby port |

## Assets and translations

| Upstream | Port | Present |
|---|---|---|
| `src/style.css` (181 lines; `.terminal-window.translucent/.root/.remote/.playbox`, `.floating-bar`, `kgx-empty`, `.exit-info`, `themeswitcher`, `.font-picker`, `.drop-highlight`, `.error-message`) | `data/style.css` | yes — same 11 selectors, `kgx-empty` → `.console-rb-empty` |
| `src/icons/scalable/status/*.svg` — `bell-outline-symbolic`, `emblem-ok-symbolic`, `external-link-symbolic`, `status-playbox-symbolic`, `status-privileged-symbolic`, `status-regular-symbolic`, `status-remote-symbolic`, `theme-check-symbolic` | `data/icons/hicolor/scalable/status/` | yes — all eight vendored and registered (`application.rb:142`). Two call sites still ask for a stock name instead of the bundled one: `theme_switcher.rb:87` uses `object-select-symbolic` where upstream uses `theme-check-symbolic`, and `spad.rb:15` uses it where upstream uses `emblem-ok-symbolic` |
| `data/org.gnome.Console.desktop.in.in`, `.metainfo.xml.in.in`, `.service.in`, app SVGs | `data/` equivalents | yes |
| `po/` — 61 `*.po`, `po/LINGUAS`, `po/POTFILES.in` listing 30 sources | `po/` (61), `data/locale` (61) | yes |

## Not from upstream

`lib/console.rb` and `lib/console/application.rb` are a leftover scaffold
(`Console::Application`, an `applications-engineering-symbolic` status page)
with no upstream counterpart and no `require` from `lib/console_rb.rb`.

## Gaps to close

File-level parity is reached: every upstream user-facing component and every
model/helper has its own `lib/*.rb`. What remains:

1. Point the two remaining stock-icon call sites at the bundled icons —
   `theme_switcher.rb:87` → `theme-check-symbolic`,
   `spad.rb:15` (`COPIED_ICON`) → `emblem-ok-symbolic`.
2. Delete the `lib/console.rb` / `lib/console/application.rb` scaffold — it has
   no upstream counterpart and nothing requires it.
3. Add the house-style "ported from <upstream file>" class comment to the files
   that predate the convention. Only `tab.rb`, `simple_tab.rb`,
   `paste_dialog.rb`, `depot.rb`, `despatcher.rb`, `livery_manager.rb`,
   `spad_source.rb` and `watcher.rb` carry it; the other 29 name upstream only
   in passing or not at all.
4. Behavioural gaps are tracked in `COMPONENT_PARITY.md`, not here — notably
   `Adwaita::ToolbarView#top_bar_style` never set to `raised` in
   `fullscreen_box.rb`, which leaves every `.top-bar.raised` rule in
   `data/style.css` dead (coloured root/SSH/toolbox header bars, visual bell).
