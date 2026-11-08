# Component identification — console-rb (2026-11-08 audit, re-verified at HEAD `b3420d6`)

| | |
|---|---|
| Upstream | GNOME Console `main` @ `599b703` (= current `origin/main`, unchanged since the last round) |
| Port | `ruby` @ `b3420d6` (HEAD; was `6bb6956` at the prior round's audit, `3467879` the prior round's report commit) |
| Prior inventory | `.reports/component-inventory.md`, unchanged this round (`find lib -type f` still 36 files, upstream's shape unchanged) |

## What changed between `6bb6956` and `b3420d6`

Four commits since the prior reports were committed: `3f3daab` (drop the
unusable `libgtop` dependency), `e999d74` (drop the unused `gem_kit` runtime
dependency), `44db0db` (add the tab context menu, fix the bell/status-icon
split, bundle `theme-check-symbolic`/`emblem-ok-symbolic`), `b3420d6` (fix a
test assertion after `44db0db` renamed `Pages#indicator_for` to
`#status_icon_for`). `git diff --stat 3467879..HEAD` touches
`COMPONENT_PARITY.md`, `FINDINGS.md`, `console-rb.gemspec`, `flake.nix`,
`lib/console_rb/{pages,process_info,spad,tab,theme_switcher}.rb`,
`nix/{Gemfile,Gemfile.lock,gemset.nix}` and `test/services_test.rb`. None of
these add a new upstream-facing widget unit, remove one, or change which
upstream source file maps to which `lib/` file — the component *list* from
the prior round still holds exactly.

## What upstream actually ships (re-confirmed directly against `origin/main`, unchanged)

```
git ls-tree -r --name-only origin/main
```

Same inventory as the prior round, re-confirmed: 1 application, 1 window +
`.ui`, 1 tab-collection (`kgx-pages`), 2 tab types (`kgx-tab` +
`kgx-simple-tab`), 1 terminal, 1 settings object, 3 livery files, 3 process
files (train/watcher/process), 1 close dialog, 1 paste dialog, 1 empty state,
1 theme switcher, 1 fullscreen box, 1 drop target, 1 preferences window, 1
font picker, 1 spad + spad-source, 1 system-info/about, 1 proxy-info, 1
shortcuts dialog (`.ui` only), `src/main.c`. `data/`: desktop file, gschema,
metainfo, 8 symbolic icons. `po/`: 61 `.po` files + `LINGUAS` +
`POTFILES.in`. `tests/`: 21 test files.

`origin/main` itself is unchanged since the prior round (`599b703`, same SHA
both times — re-confirmed with `git log origin/main -1`), so this is not a
re-derivation, it is a re-confirmation that nothing moved on the upstream
side between rounds.

## Identification is not the live gap this round — a documentation-sync gap is

Everything this report would normally flag (a widget that exists upstream
with no `lib/` counterpart, or a `lib/` file claiming to port something that
doesn't exist upstream) is unchanged from the prior round and already
tracked in `component-parity.md`. The one thing that *did* change on the
identification side this round is that the canonical ledger's own
self-description of the `pages` unit is now wrong in a way worth naming here
because it is about whether the ledger still correctly identifies what each
unit does and doesn't have — see `.reports/component-parity.md`'s new
"Ledger self-contradiction" section. That is a parity-ledger accuracy
finding, not a missing-component finding, so it is scored there, not here.

## Conclusion

No new upstream-facing component was found this round that isn't already
named in `component-inventory.md` or `COMPONENT_PARITY.md`'s 13-unit table,
and none disappeared. Identification itself remains in reasonable shape at
the "does every upstream unit have a named Ruby counterpart" level. The live
findings this round are all parity findings (does each identified component
still match on all four axes, and does the ledger's own prose match the
code) — see `.reports/component-parity.md`.
