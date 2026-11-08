# Component parity — console-rb (2026-11-08 audit, re-verified at HEAD `b3420d6`)

| | |
|---|---|
| Upstream | GNOME Console `main` @ `599b703` |
| Port | `ruby` @ `b3420d6` |
| Canonical ledger | `COMPONENT_PARITY.md` @ root, header still reads `Port \| ruby @ 9ef75ce`, header's own "Units with parity" line still reads **1 / 13**, unchanged across every commit since `2b33b04` |
| Units with parity | **1 / 13**, unchanged since `2b33b04` — confirmed again this round by reading the header line directly, not inferred |

This supersedes the prior round's `.reports/component-parity.md` (written
against `6bb6956`). Four commits landed since then: `3f3daab`, `e999d74`
(dependency cleanup, no widget-tree effect), `44db0db` (real widget-tree
changes to the `pages` unit, the `window` unit's `tab` action group, and two
bundled icons), `b3420d6` (test-only fix). Only `44db0db` is relevant to this
report, and it is real, verified progress — but it also produced a ledger
self-contradiction worth flagging on its own, below.

## Still open at HEAD `b3420d6` — read directly from the current ledger's own numbered list, not its prose

Of the ledger's 16 cross-cutting findings, 5 are struck through as fixed (1,
5, 8, 10, 13) — unchanged from the prior round. **9 remain open, unstruck, as
written in the numbered list** (re-read directly at `COMPONENT_PARITY.md`
lines ~610-662 this round):

- **#2** — the pages view's entire `GtkOverlay` layer (terminal-size readout
  on resize, drag-and-drop highlight) is still missing.
- **#3** — the theme switcher is unstyled (plain radio buttons, not swatches).
- **#4 is now FIXED IN CODE but the numbered list has not been updated to
  say so** — see "Ledger self-contradiction" below. Scoring it open here
  because the canonical document still asserts it is open; the actual code
  state is addressed separately so this isn't quietly double-counted as a
  real gap.
- **#6** — the shortcuts dialog is a structurally different widget
  (`AdwShortcutsDialog` → `AdwPreferencesDialog`): no keycaps, no live
  accelerators, Ctrl+Tab/Ctrl+Shift+Tab and RTL tab-move labels dropped.
- **#7** — fullscreen bars cannot be recovered by touch (missing
  `GtkGestureClick`; `motion`/`autohide`/`enter` fixed, the touch gesture
  itself is not).
- **#9 is also now FIXED IN CODE but the numbered list has not been updated**
  — same situation as #4, see below.
- **#11** — Return/Shift+Return do nothing in the search bar; the
  `GtkShortcutController` for `next-match`/`previous-match` was not ported.
- **#12** — Ctrl+click does not open a link; no counterpart to
  `kgx-terminal.c:779`'s `GtkGestureClick`.
- **#14** — a simple error opens the full details dialog, and a failed
  "Report Issue" is silent; two `AdwAlertDialog`s from `kgx-spad.c` have no
  counterpart.
- **#15** — font previews are not rendered in their own font, four
  `<accessibility>` labels dropped, the custom-font row's `attributes`
  binding dropped, the list doesn't grey out while filtering, initial-family
  pre-selection usually fails, preview text is hard-coded ASCII.
- **#16** — `enable-a11y` not set on the terminal; a remote tab's tooltip is
  `nil` instead of its URI. (The icon/timing half of #16 was fixed in
  `e999d74`'s predecessor round and is already reflected correctly as fixed
  in the ledger's prose, re-confirmed this round.)

## Ledger self-contradiction (new finding this round): `44db0db` fixed two real gaps but the canonical ledger still describes them as open

`44db0db`'s commit message and its own `+18` lines added to
`COMPONENT_PARITY.md` (a prose note prepended to the top of the file) both
correctly describe that it fixed: the pages unit's `menu-model`,
`setup-menu`, `default-icon`, and the `icon`/`indicator-icon`/`keyword`/
`loading` page properties. Verified directly against the code, not the
commit message:

```
lib/console_rb/pages.rb:32   view.signal_connect('setup-menu') { |_view, page| @action_page = page }
lib/console_rb/pages.rb:38   view.menu_model = tab_menu
lib/console_rb/pages.rb:39   view.default_icon = Gio::ThemedIcon.new('status-regular-symbolic')
lib/console_rb/pages.rb:90   page.keyword = keyword_for(tab).to_s
lib/console_rb/pages.rb:91   page.loading = tab.working?
lib/console_rb/pages.rb:92   page.icon = status_icon_for(tab)
lib/console_rb/pages.rb:93   page.indicator_icon = ringing_icon_for(tab)
```

All of this is real and all of it matches the commit message's description.
**But the top-of-file prose note is the only thing `44db0db` changed in
`COMPONENT_PARITY.md`.** The actual per-unit table for "Unit: pages" (further
down the same file) and the numbered "real gaps" list items #4 and #9 were
never touched by that commit and still read, verbatim, as if none of this
exists:

```
$ sed -n '154,156p;197,209p' COMPONENT_PARITY.md
| `Adw.TabView` | 1 | 1 | — | ✓ ...; ✗ `setup-menu`; ✗ `menu-model`; ✗ `default-icon` | **gap** |
...
- **No tab context menu.** `kgx-pages.ui:44` sets `menu-model="tab-menu"` ...
  The port never assigns `tab_view.menu_model`. Right-clicking a tab offers nothing.
- **`setup-menu`** ... The port's `close_selected_page` / `detach_selected_page`
  (`pages.rb:123-133`) always act on the *selected* page.
- **`default-icon`** `status-regular-symbolic` ... is not set.
- **Page properties from `kgx-page-expression.ui`.** The port sets `title`,
  `tooltip` and `indicator_icon` ... and leaves three unset:
  - `icon` — ... Absent ...
  - `indicator-icon` — ... Absent ...
  - `keyword` — ... Absent.
  - `loading` — ... Absent ...
```

Every one of those bullet claims ("never assigns", "always act on the
selected page", "is not set", "Absent") is false against the current code —
the method names referenced (`close_selected_page`/`detach_selected_page`)
don't even exist any more; they were renamed to `close_action_page`/
`detach_action_page` in the same commit the prose note describes. The
canonical, single-source-of-truth parity ledger now contradicts itself
within one file: a header note says a thing is fixed, the detailed table
three screens down says the opposite, and nobody reconciled them. This is
the same failure mode this project's own `accountability-ensurance.md`
already flagged once (`PORTING.md`'s headings vs. its own commit message) —
a document whose top-level claim and body claim disagree, where a reader
who only reads the body (which is most of the file, and where a human
auditor would naturally spend their time) would conclude #4 and #9 are
still fully open when they are not. Here the drift is a false *negative*
(claiming broken when fixed), the mirror image of a false green, but it is
the same underlying defect: the ledger was not actually re-run or
re-synchronized, only prefaced.

This also means the ledger's own **"Units with parity: 1/13"** figure and
unit-level verdict for `pages` ("**gap** (6, one of them the entire overlay
layer)") are now counting gaps that no longer all exist — the `pages` unit
genuinely has fewer open items than its own table claims, but the table was
never re-scored, so the published count overstates how many gaps remain
there. It does not change the headline 1/13 (pages was already scored `gap`
and remains `gap` — the overlay layer alone keeps it there), so this finding
does not flip the overall verdict, but it means the per-unit detail the
ledger offers as evidence for that verdict is partly stale.

## Net assessment

**1 of 13 units at full four-axis parity, 9 of 16 cross-cutting findings
genuinely still open, and the canonical ledger itself is internally
inconsistent about two more** (items #4 and #9 — fixed in code, still
described as open in the ledger's per-unit detail even though a header note
elsewhere in the same file says they're fixed). Real progress happened this
round in the code (menu-model, setup-menu, default-icon, tab status/bell/
keyword/loading properties all now wired, matching upstream's
`kgx-page-expression.ui`) — but the project's own record of that progress is
half-applied, which is itself a finding. "Far from component parity" remains
the accurate summary for the port; "the ledger accurately reflects the
port's current state" is no longer true for the `pages` unit specifically,
and should not be trusted without cross-checking the code the way this round
did.

## Recommendation

1. Re-run `component-scan.sh` against the `pages` unit specifically and
   rewrite its table and the #4/#9 "real gaps" entries (strike-through, same
   convention already used for #1/#5/#8/#10/#13) so the detailed sections
   agree with the header note that already exists.
2. Re-run `component-scan.sh` for the remaining 8 widget units not touched
   by `2b33b04` or `44db0db` (tab, terminal, close dialog, empty state, drop
   target, preferences dialog, font picker, shortcuts dialog, about dialog,
   paste dialog) — unchanged recommendation from the prior round, still not
   done.
