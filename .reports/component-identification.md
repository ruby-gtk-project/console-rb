# Component identification — console-rb (2026-11-07 audit, re-verified at HEAD `6bb6956`)

| | |
|---|---|
| Upstream | GNOME Console `main` @ `599b703` (= current `origin/main`) |
| Port | `ruby` @ `6bb6956` (HEAD; was `a5a2eab` at the prior same-day draft) |
| Prior inventory | `.reports/component-inventory.md`, last substantively edited `a2029bd` (a self-correcting pair of commits: `0839c7a` accidentally replaced it with a thinner survey, `a2029bd` restored the fuller one in the same session) |

## What changed between `a5a2eab` and `6bb6956`

Four commits: `9ef75ce` (wrote the first round of `.reports/`), `2b33b04`
("Close window-unit gaps, fix stale ledgers, and pin tab-badge precedence"),
`0839c7a`+`a2029bd` (inventory edited then restored, net no new content),
`6bb6956` (test timing fix only, no widget-tree change). None of these add a
new upstream-facing widget unit and `component-inventory.md`'s content is
unchanged net of the restore. The component *list* from the prior round still
holds.

## What upstream actually ships (re-confirmed directly against `origin/main`)

```
git ls-tree -r --name-only origin/main
```

1 application, 1 window + `.ui`, 1 tab-collection (`kgx-pages`), 2 tab types
(`kgx-tab` + `kgx-simple-tab`), 1 terminal, 1 settings object, 3 livery files,
3 process files (train/watcher/process), 1 close dialog, 1 paste dialog, 1
empty state, 1 theme switcher, 1 fullscreen box, 1 drop target, 1 preferences
window, 1 font picker, 1 spad + spad-source, 1 system-info/about, 1
proxy-info, 1 shortcuts dialog (`.ui` only), `src/main.c`. `data/`: desktop
file, gschema, metainfo, 8 symbolic icons. `po/`: 61 `.po` files + `LINGUAS` +
`POTFILES.in`. `tests/`: 21 test files.

The port's `lib/console_rb/*.rb` has 36 files (confirmed by `find lib -type
f | wc -l` at HEAD), matching the inventory's claimed 21 user-facing + 15
infrastructure/model split.

## Standing gap, unchanged since the prior round: the paste dialog is now scored, everything else about it stands

The prior round's finding that the paste dialog (`kgx-paste-dialog.c` →
`lib/console_rb/paste_dialog.rb`) had never been entered as a row in any
parity ledger **is resolved** — `COMPONENT_PARITY.md` now carries it as unit
13 (scored `gap`, see `.reports/component-parity.md`). The identification gap
itself is closed; whether the dialog actually has parity is a separate
question, answered there.

## Conclusion

The component list is substantially right and has been for several rounds;
the inventory document survived an accidental regression and restore with no
net content loss. No new upstream-facing component was found this round that
isn't already named in `component-inventory.md` or `COMPONENT_PARITY.md`'s
13-unit table. Identification itself is in reasonable shape; the open
questions from here on are all parity questions (does each identified
component match on all four axes), not identification questions (does a
component exist that nobody named) — see `.reports/component-parity.md`.
