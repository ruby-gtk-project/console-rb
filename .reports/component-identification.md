# Component identification — console-rb (2026-11-07 audit)

| | |
|---|---|
| Upstream | GNOME Console `main` @ `599b703` (= current `origin/main`) |
| Port | `ruby` @ `a5a2eab` (HEAD at audit time) |
| Prior inventory | `.reports/component-inventory.md` @ `f87c2cf` (2026-11-02) |

## Finding: the existing inventory is one porting round stale

`.reports/component-inventory.md` was last refreshed at `f87c2cf`, which
predates two later commits that changed the file map it depends on:

- `ac2d561` "Depend on the binding gems instead of working around them"
- `a456082` "Declare vte4 and gettext as runtime deps, fix fullscreen gaps"
- `a5a2eab` "Add a real GtkDriver-shaped integration run (test/drive_console_rb.rb)"

None of these add a new upstream-facing widget unit, so the inventory's
component list is not wrong in substance, but it does not know
`test/drive_console_rb.rb` and `test/gtk_driver.rb` exist, and it does not know
about the `fullscreen_box.rb` fix in `a456082` (worth a re-check: the fix
touched CSS/sizing, which is exactly what component-parity scores).

## What upstream actually ships (confirmed directly against `origin/main`, not via the inventory)

```
git ls-tree -r --name-only origin/main
```

- 1 application (`src/kgx-application.c`), 1 window + `.ui`, 1 tab-collection
  (`kgx-pages`), 2 tab types (`kgx-tab` + `kgx-simple-tab`), 1 terminal,
  1 settings object, 3 livery files (livery/palette/livery-manager), 3 process
  files (train/watcher/process), 1 close dialog, 1 paste dialog, 1 empty state,
  1 theme switcher, 1 fullscreen box, 1 drop target, 1 preferences window,
  1 font picker, 1 spad + spad-source, 1 system-info/about, 1 proxy-info,
  1 shortcuts dialog (`.ui` only, no `.c`), `src/main.c`.
- `data/`: `org.gnome.Console.desktop.in.in`, `org.gnome.Console.gschema.xml.in`,
  `org.gnome.Console.metainfo.xml.in.in`, 8 symbolic icons under
  `src/icons/scalable/`.
- `po/`: 61 translated `.po` files + `LINGUAS` + `POTFILES.in` (confirmed by
  direct `git ls-tree`, not by trusting the inventory's count).
- `tests/`: 21 test files (counted directly, see `.reports/test-parity.md`).

This matches what `.reports/component-inventory.md` lists. **Independently
re-deriving this list from `origin/main` rather than trusting the existing
document is the point of this pass** — the existing document is this port's
own work product and is not authority over what upstream ships (per the
`component-parity` skill's framing).

## New unit discovered during this audit that no existing report names as a component

**`src/kgx-paste-dialog.c` / `lib/console_rb/paste_dialog.rb` is not scored as
its own unit anywhere.** `.reports/component-inventory.md` does name the file
mapping (line 147) and `COMPONENT_PARITY.md` mentions it only as a stale aside
("the paste-confirmation `Adw.AlertDialog` ... is upstream's
`kgx-paste-dialog.c`", `COMPONENT_PARITY.md:249` — written when the dialog was
still inline in `terminal.rb:264-278`; it has since been split into its own
file, `lib/console_rb/paste_dialog.rb`, by commit `464a7a0`). Neither the
12-unit table in `COMPONENT_PARITY.md` nor any later report gives the paste
dialog its own four-axis scorecard (count / style / behaviour / text). This is
a gap in the *identification* step, not just the parity step: a component that
exists upstream and in the port was never put on the ledger to be scored. See
`.reports/component-parity.md`.

## Conclusion

Not clean. The component list itself is substantially right, but:
1. The canonical inventory document is stale by three commits, one of which
   (`a456082`) touched exactly the kind of CSS/sizing fact this audit exists to
   check.
2. One real upstream unit (the paste dialog) has never been entered as a row
   in any parity ledger, so "parity" claims made about the port have never
   actually covered it.
