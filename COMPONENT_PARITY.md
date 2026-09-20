# Component parity — console-rb

| | |
|---|---|
| Upstream | GNOME Console `main` @ `599b703` |
| Port | `ruby` @ `dd5fbc0` |
| Units with parity | **1 / 12** |
| Stylesheet | `src/style.css` → `data/style.css`, 181 lines both, 3 hunks differ (all `set_css_name` → class rewrites) |

Method: `component-scan.sh` over both trees with the GIR symbol table, unioned
per unit using the file mapping in [PORTING.md](PORTING.md) §Architecture. The
`.c` file's `G_DEFINE_TYPE` parent and the `.ui` file's `<template parent=>` are
the same widget and are counted once. `widget` counts are per instance;
`css`/`signal`/`action` counts are attachment sites, so a port that factors N
upstream branches into one helper is compared as a set, not a count.
`controller` rows are judged on the signal axis, `type` rows as data plumbing.

Every row below was confirmed by opening both files. PORTING.md is used as the
file map only; nothing in it excuses a missing component.

---

## Two findings that cut across every unit

**1. `AdwToolbarView.top-bar-style` is never set to `raised`.**
`kgx-fullscreen-box.ui:12` sets `top-bar-style: raised`; `fullscreen_box.rb:61`
constructs `Adwaita::ToolbarView.new` and leaves the default (`flat`). libadwaita
puts the `.raised` class on the top-bar area only in `raised` mode, so *every*
rule in the port's own stylesheet that is keyed on `.top-bar.raised` is dead:

```
style.css:47-59   .terminal-window.root/.remote/.playbox .top-bar.raised { background-color: … }
style.css:54-59   … .top-bar.raised popover { --popover-bg-color: … }
style.css:61-63   .terminal-window.bell .top-bar.raised { animation: bell 0.5s ease-out; }
```

That is the coloured header bar for root/SSH/toolbox sessions **and** the visual
bell flash. `Window#ring` (`window.rb:171`) correctly adds and removes the `bell`
class on a 600 ms timer, and nothing renders.

**2. None of upstream's eight bundled symbolic icons are shipped.**
`up/src/icons/scalable/**` carries `status-regular`, `status-remote`,
`status-privileged`, `status-playbox`, `bell-outline`, `emblem-ok`,
`external-link` and `theme-check`. `port/data/icons` carries only the app icon
and its symbolic variant. The port substitutes stock names in three places
(`pages.rb:82-84`, `spad.rb:15`, `theme_switcher.rb:120`) and references
`external-link-symbolic` at `spad.rb:157` with nothing to resolve it.

---

## Unit: window — `src/kgx-window.c` + `src/kgx-window.ui` -> `lib/console_rb/window.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Verdict |
|---|---:|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | 1 | ✓ `terminal-window`; ✓ `bell`; ✓ `root`/`remote`/`playbox` (dynamic, `STATUS_CLASSES` `window.rb:8`, applied `:162`); ✗ `translucent`; ✗ `devel` | ✓ `notify::fullscreened`, `close-request` | **gap** (css) |
| `Adw.TabOverview` | 1 | 1 | — | ✓ `create-tab`; ✗ extra drop target | **gap** |
| `Adw.HeaderBar` | 1 | 1 | — | — | parity |
| `Adw.WindowTitle` | 1 | 1 | — | — | parity |
| `Adw.TabBar` | 1 | 1 | — | ✗ `extra-drag-drop`; ✗ `inverted` binding | **gap** |
| `Adw.TabButton` | 1 | 1 | — | ✓ `win.show-tabs` | parity |
| `Gtk.Stack` | 1 | 1 | — | ✓ content/empty named pages | parity |
| `Gtk.ToggleButton` (find) | 1 | 1 | — | ✓ `toggled` → search | parity |
| `Gtk.Button` | 5 | 5 | ✓ `circular`×2, `flat`×3, `numeric` | ✓ `win.unfullscreen`, `win.new-tab`, `app.zoom-{in,out,normal}` | parity |
| `Gtk.MenuButton` + `Gtk.PopoverMenu` | 1 + 1 | 1 + 1 | — | ✓ both custom slots (`theme-switcher`, `zoom-controls`) | parity |
| `Gtk.Box` (zoom controls) | 1 | 1 | — | — | parity |
| `Gtk.Label` (zoom %) | 1 | 1 | — | ✓ refreshed on settings change | parity |
| `Adw.Breakpoint` | 1 | 1 | — | ✗ `apply`, ✗ `unapply` | **gap** |
| `Gtk.WindowGroup` | 1 | 0 | — | — | **gap** |

Menus: primary (5 sections, 6 items + 2 custom slots) and secondary (3 items)
match item for item — `window.rb:356-381` against `kgx-window.ui:4-47, 270-291`.

Located correspondences: `Gtk.ApplicationWindow` ×2 and one of the port's two
`Adw.ApplicationWindow` rows are the prose comment at `window.rb:196-200`, not
widgets. Upstream's `win.find` property action is a plain action plus a
button-held state (`window.rb:97-114`), documented and equivalent.

Gaps:
- **`translucent` never applied.** `kgx-window.ui:55-62` binds it to
  `settings.transparency AND window.floating`, and `kgx-window.c:112` adds the
  class. Nothing in `port/lib` mentions `translucent` on the window;
  `style.css:28 .terminal-window.translucent` is dead. `Terminal#translucent?`
  (`terminal.rb:358`) substitutes `!terminal.root.nil?` for `floating`, which is
  always true once realised — so terminal transparency also stays on when the
  window is maximised, tiled or fullscreen, where upstream turns it off.
- **`devel` class** (`kgx-window.c:673`, under `IS_DEVEL`) has no counterpart.
- **`tab.close` / `tab.detach`** (`kgx-window.c:590-591`) not installed. There is
  no `tab` action group anywhere in the port — `insert_action_group` appears
  twice, for `win` (`window.rb:20`) and `term` (`terminal.rb:48`). These are the
  targets of the tab context menu (see the pages unit); both menu items are dead.
- **Breakpoint `apply`/`unapply`** (`kgx-window.c:391-405`) disable
  `win.show-tabs-desktop` below 400 px and close the overview on widening. The
  port's breakpoint (`window.rb:344-352`) has the three setters and neither
  signal, so "Show All Tabs" stays in the menu when narrow (upstream hides it via
  `hidden-when="action-disabled"`) and the overview does not close on widening.
- **Extra drop targets.** `kgx-window.c:684-691` calls
  `adw_tab_bar_setup_extra_drop_target` and
  `adw_tab_overview_setup_extra_drop_target` for `GdkFileList` and strings, and
  `extra-drag-drop` feeds the drop into the tab. Neither call exists in the port:
  dropping a file onto the tab bar or the overview does nothing.
- **`AdwTabBar.inverted`** (`kgx-window.ui:256-264`) follows
  `gtk-decoration-layout`; the port never sets it, so the tab bar does not flip
  for left-side window controls.
- **`GtkWindowGroup`** (`kgx-window.c:689`) — each window gets its own group so a
  modal dialog blocks only its own window. Absent.

**Verdict: gap** (7).

---

## Unit: pages — `src/kgx-pages.c` + `src/kgx-pages.ui` + `src/kgx-page-expression.ui` -> `lib/console_rb/pages.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Verdict |
|---|---:|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | 0 | ✗ css-name `pages` | — | correspondence (no rule exists for `pages` in either stylesheet; `Pages#build` returns the `AdwTabView` directly, `pages.rb:23-31`) |
| `Gtk.Overlay` | 1 | 0 | — | — | **gap** |
| `Adw.TabView` | 1 | 1 | — | ✓ `page-attached`, `page-detached`, `create-window`, `close-page`; ✗ `setup-menu`; ✗ `menu-model`; ✗ `default-icon` | **gap** |
| `Gtk.Revealer` (status) | 1 | 0 | — | — | **gap** |
| `Adw.Bin` (status wrapper) | 1 | 0 | — | — | **gap** |
| `Gtk.Label` (size readout) | 1 | 0 | ✗ `floating-bar`, ✗ `numeric` | — | **gap** |
| `Gtk.Revealer` (drop) | 1 | 0 | — | — | **gap** |
| `Adw.Bin` (drop highlight) | 1 | 0 | ✗ `drop-highlight` | — | **gap** |

Gaps:
- **The whole overlay layer is missing.** `kgx-pages.ui:41-95` wraps the tab view
  in a `GtkOverlay` with two overlay children. `pages.rb:23` returns
  `tab_view` with no overlay at all. That removes:
  - the **terminal size readout** — `kgx-pages.c:266-311` shows `"<cols> × <rows>"`
    in the `floating-bar` label for 1200 ms on resize (suppressed when maximised)
    and announces it to AT. `port/lib` contains no size-change handler; the
    `Tab`/`Terminal` chain never surfaces `resize-window`.
  - the **drag-and-drop highlight** — a crossfading revealer keyed on the active
    tab's `dropping` property. `DropTarget` in the port sets no such property and
    nothing reveals anything.
  Both `.floating-bar` (`style.css:71,80`) and `.drop-highlight`
  (`style.css:168`) are present in the port's stylesheet and unreachable.
- **No tab context menu.** `kgx-pages.ui:44` sets `menu-model="tab-menu"`
  (`:98-111`, `_Detach Tab` → `tab.detach`, `_Close` → `tab.close`). The port
  never assigns `tab_view.menu_model`. Right-clicking a tab offers nothing.
- **`setup-menu`** (`kgx-pages.c:495-502`) records which page was right-clicked so
  `tab.close`/`tab.detach` act on it. The port's `close_selected_page` /
  `detach_selected_page` (`pages.rb:123-133`) always act on the *selected* page.
- **`default-icon`** `status-regular-symbolic` (`kgx-pages.ui:112-114`) is not set.
- **Page properties from `kgx-page-expression.ui`.** The port sets `title`,
  `tooltip` and `indicator_icon` (`pages.rb:68-86`) and leaves three unset:
  - `icon` — upstream's status glyph (`kgx_status_as_icon`: `status-remote` /
    `status-playbox` / `status-privileged`). The port instead puts
    `channel-secure-symbolic` / `network-server-symbolic` into the **indicator**
    slot, which is a different position on the tab, has no playbox case, and
    displaces the real indicator.
  - `indicator-icon` — upstream's `bell-outline-symbolic` while a tab is ringing.
    Absent; the port sets `needs_attention` only (`pages.rb:95`).
  - `keyword` — `kgx_file_as_display (tab-path)`, which is what makes the tab
    overview's search box find a tab by its directory. Absent.
  - `loading` — bound to the tab's `working`. Absent, so the tab spinner never
    shows while a command is starting.

Extras, explained: `notify::selected-page` (`pages.rb:27`) and `response`
(`pages.rb:154`) replace the property bindings and the close-dialog response
upstream expresses declaratively.

**Verdict: gap** (6, one of them the entire overlay layer).

---

## Unit: tab — `src/kgx-tab.c` + `src/kgx-tab.ui` -> `lib/console_rb/tab.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Verdict |
|---|---:|---:|---|---|---|
| `Adw.Bin` (root) | 1 | 1 | ✓ css-name `kgx-tab` → class `console-rb-tab` (`tab.rb:211`), stylesheet rewritten at `style.css:22,162,163` | — | parity |
| `Adw.ToastOverlay` | 1 | 1 | — | ✓ `spad-thrown` → `throw_spad` (`tab.rb:348`) | parity |
| `Gtk.Box` (column) | 1 | 1 | — | — | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | parity |
| `Gtk.SearchBar` | 1 | 1 | ✓ `view` | ✓ `notify::search-mode-enabled` | parity |
| `Adw.Clamp` | 1 | 1 | — | — | parity |
| `Gtk.Box` (search row) | 1 | 1 | — | — | parity |
| `Gtk.SearchEntry` | 1 | 1 | — | ✓ `search-changed`, `next-match`, `previous-match` | parity |
| `Gtk.ShortcutController` + 2 `Gtk.Shortcut` | 1 + 2 | 0 | — | ✗ Return, ✗ `<shift>`Return | **gap** |
| `Gtk.Button` (prev/next) | 2 | 2 | — | ✓ `clicked` ×2 | parity |
| `Gtk.Stack` | 1 | 1 | — | — | parity |
| `Gtk.Revealer` (exit banner) | 1 | 1 | ✓ `background`, ✓ `error` (conditional, `tab.rb:148`) | — | parity |
| `Gtk.Label` (exit message) | 1 | 1 | ✓ `exit-info` | — | parity |
| `Gtk.ScrolledWindow` (from `kgx-simple-tab.ui`) | 1 | 1 | ✓ `terminal` | — | parity |
| `KgxDropTarget` | 1 | 1 | — | ✓ `drop` (`tab.rb:221`) | parity |

Gaps:
- **Return / Shift+Return in the search box do nothing.** `kgx-tab.ui:47-63`
  attaches a capture-phase `GtkShortcutController` to the search entry with
  `Return → signal(next-match)` and `<shift>Return → signal(previous-match)`.
  The port connects the two signals (`tab.rb:180-181`) but nothing emits them
  from the keyboard; only the two buttons reach them.
- `tab.show-spad` (`kgx-tab.c:833`) — **located, not a gap**: the port wires the
  toast's `button-clicked` straight to `Spad#present` (`tab.rb:351-354`), which
  is the same behaviour without the `a{sv}` round trip.
- `remote`/`root` classes on the tab widget (`kgx-tab.c:285-293`) have no
  counterpart in the port, and no rule in either stylesheet targets them — the
  styling that uses those names is on the window (`.terminal-window.root …`),
  which the port does apply. Recorded, no visual difference.

**Verdict: gap** (1).

---

## Unit: simple tab — `src/kgx-simple-tab.c` + `src/kgx-simple-tab.ui` -> `lib/console_rb/tab.rb` (merged)

Upstream subclasses `KgxTab`; the port folds both into one class, so the widget
rows are counted in the tab unit above. What is specific to this template:

| Item | Up | Port | Verdict |
|---|---|---|---|
| `GtkScrolledWindow.terminal` wrapping `KgxTerminal` | 1 | 1 (`tab.rb:241-249, 69`) | parity |
| `vexpand`, `propagate-natural-{width,height}`, `hscrollbar-policy: never` | ✓ | ✓ | parity |
| `allow-hyperlink` on the terminal | ✓ | ✓ (`terminal.rb:76`) | parity |
| `tab-tooltip` = `kgx_file_as_display_or_uri(path)` | ✓ | partial (`tab.rb:342`) | **gap** |

Gap: `kgx-file-closures.h:112-126` falls back to the **URI** when the file has no
local path; `Tab#tooltip` returns `@path&.path`, i.e. `nil` for an `sftp://` or
other non-local cwd, so a remote tab loses its tooltip entirely.

**Verdict: gap** (1).

---

## Unit: terminal — `src/kgx-terminal.c` + `src/kgx-terminal.ui` -> `lib/console_rb/terminal.rb`

| Widget / controller | Up × | Port × | CSS | Signals / actions | Verdict |
|---|---:|---:|---|---|---|
| `Vte.Terminal` (root) | 1 | 1 | — | ✓ `termprop-changed::vte.cwd`, `::vte.cwf`, `setup-context-menu`; extra `bell`, `child-exited`, `selection-changed` (the port's tab reads these here rather than through a `GSignalGroup`) | **gap** (`enable-a11y`) |
| `Gtk.ShortcutController` + 4 `Gtk.Shortcut` | 1 + 4 | 1 + 4 (`terminal.rb:83-103`, built in a loop) | — | ✓ `term.copy`/`term.paste` × `<Shift><Primary>c/v` + `Copy`/`Paste` keys | parity |
| `Gtk.EventControllerScroll` | 1 | 1 | — | ✓ `scroll` → ctrl-zoom | parity |
| `Gtk.GestureClick` (button 0) | 1 | 0 | — | ✗ `pressed` | **gap** |

Context menu: 4 sections, 6 items — `terminal.rb:111-145` matches
`kgx-terminal.ui:4-58` item for item, including `win.unfullscreen`. All six
`term.*` actions are installed (`terminal.rb:147-164`) with `hidden-when`
reproduced as `enabled` state (`terminal.rb:216-225`).

Gaps:
- **Ctrl+click / Ctrl+middle-click to open a link** (`kgx-terminal.c:779-807`) has
  no counterpart. Links are only reachable through the context menu.
- **`enable-a11y: True`** (`kgx-terminal.ui:18`) is not set on the port's terminal
  (`terminal.rb:74-80`), so screen-reader access to the terminal contents is left
  at VTE's default rather than explicitly enabled as upstream does.
- The palette's translucency condition differs — see the window unit.

Located: `Vte.Regex` → `Regex.for_match` (`lib/console_rb/regex.rb`, called at
`terminal.rb:183`); the `resolve_livery`/`resolve_theme` closure chain →
`apply_palette`/`resolved_theme` (`terminal.rb:340-356`); the paste-confirmation
`Adw.AlertDialog` (`terminal.rb:264-278`) is upstream's `kgx-paste-dialog.c`.

**Verdict: gap** (2).

---

## Unit: empty state — `src/kgx-empty.c` + `src/kgx-empty.ui` -> `lib/console_rb/empty.rb`

| Widget | Up × | Port × | CSS | Signals | Verdict |
|---|---:|---:|---|---|---|
| `Gtk.Box` (root) | 1 | 1 | ✓ css-name `kgx-empty` → class `console-rb-empty` (`empty.rb:26`), stylesheet rewritten at `style.css:84` | — | parity |
| `Gtk.Revealer` (logo) | 1 | 1 | — | ✓ driven by `working=` | parity |
| `Gtk.Image` | 1 | 1 | — | — | parity |
| `Gtk.Revealer` (spinner) | 1 | 1 | — | ✓ driven by `working=` | parity |
| `Adw.Spinner` | 1 | 1 | — | — | parity |

Orientation, spacing 16, crossfade, 1000 ms duration, 128 px logo, 32×32 spinner,
`valign` end/start — all reproduced exactly. The icon name differs by app id
(`org.gnome.Console-symbolic` → `#{APPLICATION_ID}-symbolic`, `empty.rb:41`),
which is the deliberate co-installability rename and ships as
`data/icons/.../org.gnome.Console.Rb-symbolic.svg`.

**Verdict: parity.**

---

## Unit: error dialog (spad) — `src/kgx-spad.c` + `src/kgx-spad.ui` -> `lib/console_rb/spad.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Verdict |
|---|---:|---:|---|---|---|
| `Adw.Dialog` (root) | 1 | 1 | ✓ `error-details` | — | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | parity |
| `Adw.PreferencesPage` | 1 | 1 | — | — | parity |
| `Adw.PreferencesGroup` | 2 | 2 | — | ✓ conditional `visible` | parity |
| `Gtk.Button` (copy) | 1 | 1 | ✓ `flat` | ✓ `spad.copy-message` → `clicked` (`spad.rb:51`) | parity |
| `Gtk.ScrolledWindow` | 1 | 1 | ✓ `card` | — | parity |
| `Gtk.TextView` (+ buffer) | 1 | 1 | ✓ `error-message`, `monospace` | — | parity |
| `Gtk.Button` (report) | 1 | 1 | ✓ `suggested-action`, `pill` | ✓ `spad.open-issues` → `clicked` (`spad.rb:52`) | parity |
| `Adw.ButtonContent` | 1 | 1 | — | — | **gap** (icon asset) |
| `Adw.AlertDialog` (simple-error path) | 1 | 0 | — | — | **gap** |
| `Adw.AlertDialog` ("Unable To Open") | 1 | 0 | — | — | **gap** |

Content width/height, margins, `Report _Issue` underline, sys-info separator —
all match.

Gaps:
- **Simple errors get the wrong dialog.** `kgx-spad.c:360-375`: when there are no
  flags, no content and no message, upstream presents a plain `AdwAlertDialog`
  with a Close response instead of the full details page. `Spad#build` is the
  only path in the port, so a one-line error opens a 550×400 preferences page
  with an empty body.
- **A failed "Report Issue" is silent.** `kgx-spad.c:180-206` shows an
  "Unable To Open" alert with the error text when the URI launch fails;
  `spad.rb:76-82` rescues and returns `nil`.
- **`external-link-symbolic`** (`spad.rb:157`) is an upstream-bundled icon the
  port does not ship — the report button renders with a missing-image glyph.
- Minor: the copied-confirmation icon is `object-select-symbolic` for 2000 ms
  (`spad.rb:15-16`) against upstream's bundled `emblem-ok-symbolic` for 500 ms
  (`kgx-spad.c:35,175`).

**Verdict: gap** (3 + 1 minor).

---

## Unit: theme switcher — `src/kgx-theme-switcher.c` + `src/kgx-theme-switcher.ui` -> `lib/console_rb/theme_switcher.rb`

| Widget | Up × | Port × | CSS | Signals | Verdict |
|---|---:|---:|---|---|---|
| `Adw.Bin` (root) | 1 | 0 | ✗ css-name `themeswitcher` | — | **gap** (see below) |
| `Gtk.Box` | 1 | 1 | `themeswitcher` as a **class** (`theme_switcher.rb:43`) | — | **gap** |
| `Gtk.Overlay` | 3 | 3 (`theme_switcher.rb:52-59`, one factory × 3 themes) | — | — | parity |
| `Gtk.CheckButton` | 3 | 3 (`:74-83`) | ✓ `system`, `light`, `dark` (dynamic, `:80`) | ✓ `notify::active` ×3 (`:25`) | parity |
| `Gtk.Image` (check mark) | 3 | 3 (`:86-95`) | ✓ `check` | — | parity |

Homogeneous box, spacing 18, `halign: center`, 13 px check overlay, the
group-leader arrangement and the `system_supports_color_schemes?` visibility rule
are all reproduced (`theme_switcher.rb:19`).

Gap — **the entire theme switcher is unstyled.** Upstream's selectors are
*element* selectors, produced by `gtk_widget_class_set_css_name (klass,
"themeswitcher")` (`kgx-theme-switcher.c:158`). The port copied
`style.css:103-151` across **verbatim**, still as element selectors, but attaches
`themeswitcher` as a *class* (`theme_switcher.rb:43`). `themeswitcher { }` never
matches a `GtkBox`, so eight rules are dead:

```
themeswitcher { padding: 6px }
themeswitcher .check { accent pill, 17px radius, 3px margin }
themeswitcher checkbutton { outline-offset, transition: none }
themeswitcher checkbutton radio { 24px swatch, no icon, 1px border, --light-bg/--dark-bg }
themeswitcher checkbutton radio:checked { 2px accent ring }
themeswitcher checkbutton.system radio { split light/dark gradient }
themeswitcher checkbutton.light radio { white }
themeswitcher checkbutton.dark radio { #1e1e1e }
```

Rendered result: three ordinary radio buttons in the menu instead of three theme
swatches, and no accent pill behind the tick. The fix is one line in
`data/style.css` — rewrite the eight selectors to `.themeswitcher` — matching the
`kgx-tab` → `.console-rb-tab` and `kgx-empty` → `.console-rb-empty` rewrites that
were done correctly.

The missing `Adw.Bin` is a located correspondence, not a second gap: upstream's
Bin exists to be the GObject that owns the css name, and the port's root is the
`Gtk::Box` (`theme_switcher.rb:40`), one level flatter with the same children.
The tick icon is stock `object-select-symbolic` (`:89`) against upstream's
bundled `theme-check-symbolic`.

**Verdict: gap** (1, stylesheet-wide for this unit).

---

## Unit: fullscreen box — `src/kgx-fullscreen-box.c` + `src/kgx-fullscreen-box.ui` -> `lib/console_rb/fullscreen_box.rb`

| Widget / controller | Up × | Port × | CSS | Signals | Verdict |
|---|---:|---:|---|---|---|
| `Adw.Bin` (root) | 1 | 0 | ✗ css-name `fullscreenbox` (no rule in either stylesheet) | — | correspondence: root is the `ToolbarView` (`fullscreen_box.rb:61`) |
| `Adw.ToolbarView` | 1 | 1 | ✗ `main-box`; ✗ `top-bar-style: raised` | — | **gap** |
| `Gtk.EventControllerMotion` | 1 | 1 | — | ✓ `motion`; ✗ `enter`; extra `leave` | **gap** |
| `Gtk.GestureClick` (touch-only) | 1 | 0 | — | ✗ `pressed` | **gap** |

The reveal geometry matches: upstream's `get_titlebar_area_height` +
`KGX_FULLSCREEN_BOX_REVEAL_ZONE` is `reveal_threshold` (`fullscreen_box.rb:45-47`),
and the 500 ms hide timer matches `HIDE_DELAY`.

Gaps:
- **`top-bar-style: raised` is not set** (`kgx-fullscreen-box.ui:12`) — the
  cross-cutting finding above; it is what disables the status-colour header bars
  and the visual bell.
- **`main-box` class** (`kgx-fullscreen-box.ui:15-17`) is not attached. No rule
  targets it in either stylesheet today, so nothing renders differently, but the
  class is a hook upstream ships and the port does not.
- **`enter`** (`kgx-fullscreen-box.c:299-304`) re-runs the motion logic the moment
  the pointer enters the widget. The port connects `leave` instead
  (`fullscreen_box.rb:20`), so a pointer that enters already inside the reveal
  zone — moving in from the screen edge, the common case in fullscreen — does not
  bring the bars back until it moves again.
- **Touch reveal** — the `touch-only` `GtkGestureClick` (`kgx-fullscreen-box.ui:28-35`,
  handler `:308-321`) reveals the bars on a tap below the title-bar area and sets
  `is_touch`. There is no gesture in the port: on a touchscreen the top bars
  cannot be brought back in fullscreen at all.
- **`last-focus` binding** (`kgx-fullscreen-box.ui:5-9`) tracks the window's focus
  widget so focus is restored when the bars hide. No counterpart.
- The port's `autohide` is a plain writer defaulting to `true`
  (`fullscreen_box.rb:12,37`) and nothing ever writes it. Upstream binds it to
  `primary_menu_popover.visible` inverted (`kgx-window.ui:82-83`), so opening the
  main menu in fullscreen pins the bars. In the port the bars can slide away
  under an open popover.

**Verdict: gap** (6).

---

## Unit: preferences — `src/preferences/kgx-preferences-window.{c,ui}` -> `lib/console_rb/preferences_dialog.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Verdict |
|---|---:|---:|---|---|---|
| `Adw.PreferencesDialog` (root) | 1 | 1 | — | — | parity |
| `Adw.PreferencesPage` | 1 | 1 | — | — | parity |
| `Adw.PreferencesGroup` | 3 | 3 | — | — | parity |
| `Adw.SwitchRow` | 4 | 4 | — | ✓ `notify::active` ×4 | parity |
| `Adw.SpinRow` (+ `Gtk.Adjustment` 0/800000/1000) | 1 | 1 | — | ✓ `notify::value`; ✓ sensitivity follows unlimited-scrollback | parity |
| `Adw.ActionRow` (custom font) | 1 | 1 | — | ✓ `prefs.select-font` → `activated` (`preferences_dialog.rb:61`) | parity |
| `Gtk.Box` (row suffix) | 1 | 0 | — | — | correspondence: two `add_suffix` calls (`:147-148`) |
| `Gtk.Label` (font name) | 1 | 1 | ✓ `dim-label`, ✓ `ellipsize: middle` | ✗ `attributes` binding | **gap** |
| `Gtk.Image` (`go-next-symbolic`) | 1 | 1 | — | — | parity |

All nine titles, the `use-underline` flags, the group titles and the bell group
description match string for string.

Gap: **the custom-font row does not preview the font.**
`kgx-preferences-window.ui:28-34` binds the label's `attributes` through
`font_as_attributes`, so the row shows the chosen family *rendered in that
family*. `preferences_dialog.rb:78` sets `label.label` only — plain UI font.

**Verdict: gap** (1).

---

## Unit: font picker — `src/preferences/kgx-font-picker.{c,ui}` -> `lib/console_rb/font_picker.rb`

| Widget | Up × | Port × | CSS | Signals / actions | Verdict |
|---|---:|---:|---|---|---|
| `Adw.NavigationPage` (root) | 1 | 1 | — | ✓ title `Terminal Font`, tag `font-picker` | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | ✓ all three `show-*` flags false | parity |
| `Gtk.Button` (Cancel / Select) | 2 | 2 | ✓ `suggested-action` on Select | ✓ `navigation.pop` / `picker.select` → `clicked` (`font_picker.rb:46-47`) | parity |
| `Gtk.Box` (column) | 1 | 1 | ✓ `font-picker` | — | parity |
| `Gtk.SearchEntry` | 1 | 1 | — | ✓ `search-changed` → `StringFilter#search` | **gap** (a11y) |
| `Gtk.ScrolledWindow` | 1 | 1 | ✓ `frame`, `view`; ✓ max height 400 | — | parity |
| `Gtk.ListView` | 1 | 1 | — | ✓ `activate`; ✗ `sensitive` ← `filterer.pending` | **gap** |
| list item `Gtk.Label` | 1 | 1 (factory `setup`/`bind`, `:191-213`) | ✓ `font-item`, ✓ per-family `attributes` | — | parity |
| `Gtk.Entry` (preview) | 1 | 1 | — | ✓ live `attributes` (`:77-81`) | **gap** (text + a11y) |
| `Gtk.SpinButton` (+ adjustment 1/1000/1/10) | 1 | 1 | — | ✓ `value-changed` | **gap** (a11y) |
| `Gtk.Label` (“Font Size”) | 0 | 1 | — | — | extra, explained below |

The model stack is reproduced exactly: `SingleSelection(autoselect: false,
can_unselect: false)` → `FilterListModel(incremental: true)` →
`EveryFilter[BoolFilter(is-monospace), StringFilter(name)]`, with the same
`PropertyExpression`s (`font_picker.rb:146-185`). The port's
`GtkSignalListItemFactory` replaces upstream's `GtkBuilderListItemFactory` and
produces the same row.

Gaps:
- **Four accessibility labels dropped.** `kgx-font-picker.ui` declares
  `<accessibility><property name="label">` on the search entry (`:47-49`), the
  list view (`:132-134`), the preview entry (`:157-159`) and the size spinner
  (`:178-180`). None is set in the port. The extra visible `Gtk.Label` "Font Size"
  (`font_picker.rb:227-232`, plus the `Gtk.Box` holding it) partly substitutes for
  the fourth, and is the only one of the four with any replacement.
- **The list does not grey out while filtering.** `kgx-font-picker.ui:60-64` binds
  `sensitive` to `filterer.pending`, and `pending_changed`
  (`kgx-font-picker.c:193-205`) re-selects the prior family once the incremental
  filter settles. The port has neither, and instead walks the model once at build
  time (`font_picker.rb:67-75`) — with `incremental: true` that scan runs before
  the filter has finished, so the user's current font is often not pre-selected.
- **Preview text is a hard-coded ASCII string.** `PREVIEW_TEXT` is
  `'AaBbCcDd 0123 {}[]()<>'` (`font_picker.rb:11`); upstream uses
  `pango_language_get_sample_string (NULL)` (`kgx-font-picker.c:240-243`), the
  locale's own sample text — the port shows Latin glyphs to a CJK or Cyrillic
  user choosing a font.

**Verdict: gap** (3).

---

## Unit: shortcuts dialog — `src/shortcuts-dialog.ui` (no backing source) -> `lib/console_rb/shortcuts_dialog.rb`

| Widget | Up × | Port × | CSS | Verdict |
|---|---:|---:|---|---|
| `Adw.ShortcutsDialog` | 1 | 0 | — | **gap**: substituted by `Adwaita::PreferencesDialog` (`shortcuts_dialog.rb:46`) |
| `Adw.ShortcutsSection` | 4 | 4 × `Adw.PreferencesGroup` (`:54-60`) | — | substitution |
| `Adw.ShortcutsItem` | 16 | 17 × `Adw.ActionRow` (`:62-67`) | — | substitution |
| accelerator rendering | keycaps, from the action's live accel | `Gtk.Label` + string rewriting (`:69-86`) | `dim-label`, `numeric` | **gap** |

The four section titles match, and all 17 accelerator strings agree with
`Application::ACCELERATORS` (`application.rb:7-21`), which in turn matches
`kgx-application.c:166-204` key for key.

Gaps:
- **The dialog is a different widget.** Upstream's `AdwShortcutsDialog` renders
  each accelerator as keycaps, groups into a paged searchable dialog and picks up
  the *live* accelerator for the eight items declared by `action-name`. The port
  renders `Ctrl+Shift+N` as dim text in an action row. The substitution is not
  recorded in PORTING.md or FINDINGS.md, and no binding defect was found that
  would prevent constructing `Adwaita::ShortcutsDialog`.
- **Accelerators are transcribed, not looked up.** Eight upstream items use
  `action-name` (`win.new-window`, `win.find`, `term.copy`, `term.paste`,
  `win.new-tab`, `win.close-tab`, `win.show-tabs`, `win.fullscreen`), so the
  dialog can never disagree with what is installed. The port hard-codes the
  strings in a second table; they agree today.
- **Secondary accelerators lost.** Upstream's Next Tab is
  `<Primary>Page_Down <Primary>Tab` and Previous Tab is
  `<Primary>Page_Up <Shift><Primary>Tab` (`shortcuts-dialog.ui:63,69`); the port
  lists only the Page_Down/Page_Up half (`shortcuts_dialog.rb:23-24`), so Ctrl+Tab
  is undiscoverable.
- **RTL variants lost.** Upstream ships Move Tab Left/Right twice with
  `direction` ltr and rtl (`:72-99`). The port has one of each, which is mislabelled
  in a right-to-left locale.

Extra, explained: the port adds Enlarge Text / Shrink Text / Reset Size to the
Terminal section (`:15-17`). Those accelerators are real on both sides; upstream
simply omits them from its shortcuts window.

**Verdict: gap** (4).

---

## Stylesheet

`up/src/style.css` and `port/data/style.css` are both 181 lines and differ on
three hunks, all of them the `set_css_name` → class rewrite the
`component-parity` skill describes:

| Upstream selector | css name set at | Port selector | Attached at | Verdict |
|---|---|---|---|---|
| `kgx-tab .top-bar` (`:22`) | `kgx-tab.c:837` | `.console-rb-tab .top-bar` | `tab.rb:211` | ✓ |
| `kgx-empty` (`:84`) | `kgx-empty.c:210` | `.console-rb-empty` | `empty.rb:26` | ✓ |
| `kgx-tab:drop(active)` (`:162-163`) | `kgx-tab.c:837` | `.console-rb-tab:drop(active)` | `tab.rb:211` | ✓ |
| `themeswitcher …` (`:103-151`, 8 rules) | `kgx-theme-switcher.c:158` | **not rewritten** | class added at `theme_switcher.rb:43` | ✗ |
| `pages` | `kgx-pages.c:689` | — | — | no rule exists; nothing to port |
| `fullscreenbox` | `kgx-fullscreen-box.c:365` | — | — | no rule exists; nothing to port |

Rules that exist in the port's stylesheet and can never match:

| Rule | Why |
|---|---|
| `themeswitcher …` × 8 (`:103-151`) | element selector vs attached class |
| `.terminal-window.root/.remote/.playbox .top-bar.raised` (`:47-59`) | `top-bar-style` never `raised` |
| `.terminal-window.bell .top-bar.raised` (`:61-63`) | same |
| `.terminal-window.translucent` (`:28-30`) | class never attached |
| `.floating-bar`, `.floating-bar:backdrop` (`:71-82`) | the size readout is not built |
| `.drop-highlight` (`:168-172`) | the drop overlay is not built |

No variant stylesheet (high-contrast or otherwise) exists on either side.

---

## Coverage note

The twelve units above are the upstream template roots plus the standalone
`shortcuts-dialog.ui`. Four further upstream files build UI outside them and were
not compared in this pass: `kgx-application.c` (app actions, accelerators — the
accelerator table was checked against the port and matches), `kgx-about.c`,
`kgx-close-dialog.c` and `kgx-paste-dialog.c` (the last is located inline at
`terminal.rb:264-278`). They map to `application.rb`, `about_dialog.rb`,
`close_dialog.rb` and `terminal.rb` respectively and need their own sections
before the ledger is complete.

Steps 4b and 5 of the parity procedure — running the port beside upstream and
driving each signal — have not been done. Every verdict here is static.

---

## The real gaps, ranked

1. **`top-bar-style: raised` is never set on the toolbar view** (`fullscreen_box.rb:61`).
   Kills eleven rules in the port's own stylesheet: the coloured header bar for
   root, SSH and toolbox sessions, the popover tint that goes with it, and the
   visual bell flash. Largest visible difference in the app, and a one-line fix.
2. **The whole `GtkOverlay` layer of the pages view is missing** (`pages.rb:23`).
   No terminal-size readout on resize, no drag-and-drop highlight. Two features
   and four widgets, with both stylesheets already carrying the rules.
3. **The theme switcher is completely unstyled** (`data/style.css:103-151`).
   Eight rules keyed on an element name the port re-expressed as a class. Three
   plain radio buttons in the main menu instead of three theme swatches.
4. **No tab context menu and no `tab.*` actions** (`pages.rb:33`, `window.rb:73`).
   `menu-model`, `setup-menu`, `tab.close` and `tab.detach` are all absent; right
   clicking a tab does nothing.
5. **Window transparency is applied on the wrong condition and never styled**
   (`terminal.rb:358`, `window.rb`). `translucent` is never put on the window, so
   `.terminal-window.translucent` is dead, and the terminal stays transparent when
   maximised, tiled or fullscreen where upstream turns it off.
6. **The shortcuts dialog is a different widget** (`shortcuts_dialog.rb:46`).
   `AdwShortcutsDialog` → `AdwPreferencesDialog`, keycaps → dim text, live
   accelerators → a hard-coded second table, and Ctrl+Tab / Ctrl+Shift+Tab and
   the RTL tab-move labels are dropped.
7. **Fullscreen bars cannot be recovered by touch, or by entering from the screen
   edge, and slide away under an open menu** (`fullscreen_box.rb:19-20,37`).
   Missing `GtkGestureClick`, `enter` connected as `leave`, `autohide` never
   written.
8. **None of upstream's eight bundled symbolic icons are shipped** (`data/icons/`).
   Stock substitutes in three places, no playbox status icon, no ringing
   indicator, and `external-link-symbolic` referenced with nothing behind it.
9. **Tab page properties `icon`, `loading` and `keyword` are never set**
   (`pages.rb:68-86`). No status glyph in its own slot, no spinner while a command
   starts, and the tab overview's search cannot find a tab by directory.
10. **Files cannot be dropped on the tab bar or the tab overview**
    (`window.rb`). Both `setup_extra_drop_target` calls and the `extra-drag-drop`
    handler are absent.
11. **Return and Shift+Return do nothing in the search bar** (`tab.rb:180`).
    The `GtkShortcutController` that emits `next-match`/`previous-match` was not
    ported; only the two arrow buttons work.
12. **Ctrl+click does not open a link** (`terminal.rb`). The `GtkGestureClick`
    from `kgx-terminal.c:779` has no counterpart; links need the context menu.
13. **The narrow breakpoint has no `apply`/`unapply`** (`window.rb:344`).
    "Show All Tabs" stays in the menu when narrow, and the overview does not close
    when the window widens again.
14. **A simple error opens the full details dialog, and a failed "Report Issue"
    is silent** (`spad.rb:31,76`). Two `AdwAlertDialog`s from `kgx-spad.c`
    have no counterpart.
15. **Font previews are not rendered in their font, and the picker's a11y labels
    are gone** (`preferences_dialog.rb:78`, `font_picker.rb`). Four
    `<accessibility>` labels dropped, the custom-font row's `attributes` binding
    dropped, the list never greys out while filtering and the initial family is
    usually not pre-selected, and the preview text is hard-coded ASCII instead of
    the locale's sample string.
16. **Smaller, confirmed:** `enable-a11y` not set on the terminal
    (`terminal.rb:74`); no `GtkWindowGroup` per window (`window.rb:201`);
    `AdwTabBar.inverted` never follows the decoration layout; the `main-box` class
    unattached; a remote tab's tooltip is `nil` instead of its URI
    (`tab.rb:342`); the copy-confirmation icon and its 2000 ms reset differ from
    upstream's bundled icon and 500 ms.
