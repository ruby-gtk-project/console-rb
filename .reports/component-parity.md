# Component parity — console-rb (2026-11-07 audit, re-verified at HEAD `6bb6956`)

| | |
|---|---|
| Upstream | GNOME Console `main` @ `599b703` |
| Port | `ruby` @ `6bb6956` |
| Canonical ledger | `COMPONENT_PARITY.md` @ root, last substantively edited `2b33b04` |
| Units with parity | **1 / 13**, unchanged since `2b33b04` — no commit after it touches a widget unit |

This supersedes the same-day draft of this file (written against `a5a2eab`).
`COMPONENT_PARITY.md` itself was corrected by `2b33b04` after that draft: the
draft's three "ledger says X is broken but X was already fixed" findings
(top-bar-style, tab-badge precedence, missing status icons) are now reflected
in the live ledger as struck-through, resolved cross-cutting findings
(`COMPONENT_PARITY.md`'s items 1, 5, 8, 10, 13). Re-read directly, not assumed
from the prior draft:

## Still open at HEAD `6bb6956` — read directly from the current ledger, not its prose

Of the ledger's 16 cross-cutting findings, 5 are now struck through as fixed
(1, 5, 8, 10, 13) and **11 remain open, unstruck, exactly as written**:

- **#6** — the shortcuts dialog is a structurally different widget
  (`AdwShortcutsDialog` → `AdwPreferencesDialog`): no keycaps, no live
  accelerators, Ctrl+Tab/Ctrl+Shift+Tab and RTL tab-move labels dropped.
- **#7** — fullscreen bars cannot be recovered by touch (missing
  `GtkGestureClick`; `motion`/`autohide` fixed, the touch gesture itself is
  not).
- **#9** — tab page properties `icon`, `loading`, `keyword` never set: no
  status glyph slot, no spinner while a command starts, tab-overview search
  cannot find a tab by directory.
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
  `nil` instead of its URI; copy-confirmation icon/timing differ from
  upstream.

Separately, the `window` unit itself — confirmed by `2b33b04`'s own
description and spot-checked against `lib/console_rb/window.rb` — gained real
new wiring this round (`translucent` via `Gdk::ToplevelState`, a `tab` action
group, `Breakpoint` apply/unapply, extra drop targets, `AdwTabBar.inverted`,
`GtkWindowGroup` per window). That closes several items the prior draft listed
as open, which is genuine progress and is recorded as such — but it does not
move the **units-with-parity** count, because the ledger's own per-unit table
still scores `window` a `gap` overall (the unit needs every row to say
`parity`, not most of them).

## Units never given a four-axis scorecard

**The paste dialog (unit 13) exists as a row now but is scored `gap`, not
re-verified axis-by-axis in this round** — this audit did not independently
re-run `component-scan.sh` against `lib/console_rb/paste_dialog.rb` and
`src/kgx-paste-dialog.c`; it is reporting the ledger's own self-assessment,
confirmed only to the extent that the file exists and the unit row exists.

## Net assessment

**1 of 13 units at full four-axis parity, and 11 of 16 cross-cutting findings
still open**, unchanged from the last time the canonical ledger was edited
(`2b33b04`). Real, confirmable progress happened this round (5 cross-cutting
findings closed, the paste dialog identified and scored, the window unit
gaining real feature wiring) — but "far from component parity" remains the
accurate summary, not a caveat on an otherwise-clean result. A port at 1/13
units is not close to parity by any reading of the ledger's own numbers.

## Recommendation (unchanged from the prior round)

Re-run `component-scan.sh` against current HEAD for the 8 widget units that
were not part of `2b33b04`'s window-focused pass (tab, terminal, close
dialog, empty state, theme switcher, drop target, preferences dialog, font
picker, shortcuts dialog, about dialog, paste dialog) to confirm none of
their listed gaps have silently drifted the way the fullscreen box's had.
