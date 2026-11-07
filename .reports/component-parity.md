# Component parity — console-rb (2026-11-07 audit)

| | |
|---|---|
| Upstream | GNOME Console `main` @ `599b703` (= `origin/main`) |
| Port | `ruby` @ `a5a2eab` |
| Existing ledger | `COMPONENT_PARITY.md` @ `57073a5`, headed "Port @ `dd5fbc0`" |

## The existing ledger is stale, and stale in both directions

`COMPONENT_PARITY.md` was written against port commit `dd5fbc0`. Six commits
later, `464a7a0` ("Port the spad source, watcher, livery manager, depot,
despatcher, paste dialog and simple tab") and `a456082` ("fix fullscreen
gaps") changed facts the ledger states as current. Verified directly against
the files, not against the ledger's own prose:

### Fixed since the ledger was written (confirmed by reading the code)

1. **`top-bar-style` is now `raised`.** The ledger's own headline cross-cutting
   finding #1 says this is never set, so the coloured header bar and the bell
   flash are dead. `a456082` sets it (`fullscreen_box.rb`); `data/style.css`'s
   `.top-bar.raised` rules are reachable again. **The ledger's #1 finding no
   longer holds.**
2. **Tab status badge precedence is no longer inverted.** `TEST_PARITY.md`'s
   divergence #1 and `COMPONENT_PARITY.md`'s pages notes both cite
   `pages.rb:82` testing `:privileged` before `:remote`. Current
   `lib/console_rb/pages.rb:80-86` defines `STATUS_ICONS` in the order
   `remote, playbox, privileged` and a comment says "The icons and the order
   they are tested in are upstream's." **This divergence no longer holds.**
3. **All eight bundled symbolic icons are vendored**, including the previously
   missing `status-playbox-symbolic` (`data/icons/hicolor/scalable/status/`,
   confirmed present on disk and exercised by `services_test.rb`'s eight
   icon-presence checks, which pass). **The ledger's #2 cross-cutting finding
   no longer holds.**

### Newly stale claims about file location (introduced by the same commits)

4. `COMPONENT_PARITY.md:249` states the paste-confirmation dialog "is located
   inline" in `terminal.rb:264-278`. It has not been inline since `464a7a0`
   split it into `lib/console_rb/paste_dialog.rb`. The ledger's citation is
   now simply wrong, and — because it was never given its own unit row before
   or after the move — **the paste dialog has never been scored on any of the
   four parity axes.**
5. `COMPONENT_PARITY.md`'s own unit table lists "simple tab ... ->
   `lib/console_rb/tab.rb` (merged)". `464a7a0` gave it its own file,
   `lib/console_rb/simple_tab.rb`. The claimed merge is no longer true, and no
   corrected scorecard exists for it under its real file.

### Confirmed still true (spot-checked directly against current `window.rb` /
`terminal.rb`, not assumed from the stale ledger)

The `window` unit's other listed gaps were **not** touched by the later
commits and remain exactly as described:

- No `translucent` class application anywhere in `window.rb`; `terminal.rb:405`
  still substitutes `!terminal.root.nil?`, which stays true once realised —
  transparency does not turn off when maximised/tiled/fullscreen as upstream
  requires.
- No `devel` class.
- No `Gtk::WindowGroup`.
- No `tab` action group: `insert_action_group` appears exactly twice in
  `lib/` (`window.rb:20` for `win`, `terminal.rb:49` for `term`). `tab.close` /
  `tab.detach`, the tab context menu's targets, are still unimplemented —
  confirmed by grep, not by trusting the old ledger.
- No breakpoint `apply`/`unapply` handler — "Show All Tabs" still does not hide
  itself below 400px, and the tab overview still does not close on widening.
- No extra-drop-target wiring on the tab bar or tab overview — dropping a file
  onto either still does nothing.

## Units never put on any ledger

- **Paste dialog** (`src/kgx-paste-dialog.c` → `lib/console_rb/paste_dialog.rb`):
  no count/style/behaviour/text scorecard exists anywhere. Its *logic* is unit
  tested (`services_test.rb`: "the paste dialog is an alert", "it offers both
  responses", "cancelling is the default way out", "the body quotes the
  command") but that is behaviour, one of four axes, and tested in isolation
  from the widget tree it is built into — count and CSS class parity against
  `kgx-paste-dialog.c`'s `Adw.AlertDialog` were never checked.
- **Watcher, livery manager, depot, despatcher, spad source** are backend
  units with no widget surface, so they correctly sit outside the 12-unit
  widget table — but `PORTING.md`'s "Dropped deliberately" section (see
  `.reports/accountability-ensurance.md`) still describes three of them as
  intentionally-dropped C workarounds, when in fact all three now have real
  Ruby files and real tests. **`PORTING.md` itself is stale about its own
  architecture**, not just the parity ledgers that cite it.

## Net assessment

Of the ledger's 12 widget units, parity was already recorded at 1/12 before
this round and nothing in the intervening commits closed a whole unit to full
four-axis parity — the fixes above close specific named defects, not entire
units. The `window` unit alone still carries five uncontested gaps
(translucent, devel, WindowGroup, tab actions, breakpoint signals, extra drop
targets). **Current state: still far from component parity.** The round's
real news is that the *ledger itself* cannot be trusted as a current snapshot
without re-verification against the actual files — three of its claims were
independently falsified in a single afternoon's spot check.

## Recommendation

Re-run the full twelve-unit `component-scan.sh` pass against current HEAD,
add the paste dialog as unit 13, and republish `COMPONENT_PARITY.md` with a
port SHA that matches the commit actually being scored. Do not leave the old
document in place uncorrected — it is already demonstrated to mislead a reader
into believing live bugs (badge precedence, missing playbox icon) that were
fixed days ago.
