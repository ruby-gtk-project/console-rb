# Test parity — console-rb (2026-11-07 audit)

| | |
|---|---|
| Upstream tests | `tests/` — 21 `.c` files, confirmed by `git ls-tree -r --name-only origin/main` |
| Existing ledger | `TEST_PARITY.md` @ `57073a5` ("148 upstream / 25 ported / 123 gaps"), and a second, older, inconsistent copy at `.reports/TEST_PARITY.md` @ `07ed601` |
| This audit | Ran the suite for real; it executes and passes, but the ledger's numbers predate real porting work and are no longer the current count |

## First: does the suite actually run? Yes — verified by executing it

```
nix develop --command bash -c 'rake schema && xvfb-run -a rake test'
```

`rake test` runs, in order: `integration_test.rb` (29/29), `actions_test.rb`
(71/71), `services_test.rb` (50/50), `drive_console_rb.rb` (57/57). All four
exit zero. `test/gtk_driver.rb:222-223` confirms the gate is real, not cosmetic
— `exit(total.zero? ? 0 : 1)`, so a failed check fails the process.

**One prerequisite the gate's own documented invocation omits.** Running the
literal command this campaign's gate uses —
`nix develop --command xvfb-run -a ruby test/drive_console_rb.rb` — with no
prior `rake schema` **aborts immediately**:

```
(drive_console_rb.rb:…): GLib-GIO-ERROR **: Settings schema
'org.gnome.Console.Rb' is not installed
```

The schema has to be compiled first (`rake schema` → `glib-compile-schemas
data/schemas`). `rake test` does this implicitly by sharing a working
directory where a prior compile already happened to leave a compiled schema
blob around; a genuinely clean checkout does not. This does not invalidate the
57-of-57 result — once compiled, it reliably passes — but it means **"drive_ok"
as stated in this round's gate is not reproducible from the one-line command
the gate names**, and nothing in `README.md`, `PORTING.md` or the drive
script's own header comment says to run `rake schema` first. Treat this as a
packaging gap, not a behavioural one, but a real one: an agent or CI runner
that copies the documented command verbatim gets a crash, not "DRIVE OK".

**One screenshot step is silently non-fatal.** In an early run, step 22 logged
`shot 07-preferences failed: RuntimeError: widget produced no render node (not
realised yet?)` and the run still printed `57 of 57 checks passed` / `DRIVE
OK` — screenshot capture is not one of the counted checks. A second run
captured the shot cleanly. The flake is real (render-timing dependent) and the
gate's check count does not reflect it either way; "57 of 57" is accurate
about assertions and silent about rendering.

## Second: the 148/25/123 ledger is stale, in the direction that currently overstates gaps

`TEST_PARITY.md` was written before commit `464a7a0` ("Port the spad source,
watcher, livery manager, depot, despatcher, paste dialog and simple tab")
added `test/services_test.rb`, which did not exist in the ledgered state.
Counting upstream's own `g_test_add_func` calls directly (not the ledger's
prose):

| Upstream file | Upstream test functions | Now has a named counterpart in `services_test.rb`? |
|---|---:|---|
| `tests/test-depot.c` | 3 | Yes — 7 checks: fallback dir/shell, explicit command wins, TERM forced, TERM_PROGRAM, explicit env + TERM |
| `tests/test-despatcher.c` | 1 | Yes — 5 checks: FileManager1 tuple shape, percent-encoding (quote, backslash), session-bus reachability, `show_folder` result |
| `tests/test-spad-source.c` | 4 | Yes — 5 checks: unhandled/handled report, handler gets title, bundle is the Spad keyword set, body-required |
| `tests/test-livery.c` | 5 | Partially — livery-manager resolution/shadowing is covered (6 checks); roundtrip/palette-set on a bare `Livery` object is not independently re-verified here |
| (train/watcher split) | — | watcher polling/background-switch/tick/drop behaviour is covered (6 checks), new since the watcher was extracted from `train.rb` |

This closes real ground the existing ledger still lists as 4-of-44 in its
"Closures, template machinery, spawn wrappers" bucket. **The 25/148 figure in
`TEST_PARITY.md` is a lower bound from before this work landed, not the
current count.** I have not re-derived a new precise total — doing that
properly means repeating the ledger's full per-function comparison across all
21 files, which this round did not have room for — but reporting the old
figure as current, as `COMPONENT_PARITY.md`-adjacent documents already do,
would itself be a false claim. **The honest state is: the ledger is out of
date and nobody has recomputed it since `464a7a0`.** That is reported here as
a gap in its own right, not quietly corrected with a guessed number.

## Third: a confirmed fix with zero regression coverage

`lib/console_rb/pages.rb:81-87` now tests `remote` before `privileged` —
`COMPONENT_PARITY.md`'s cross-cutting bug (root-over-SSH badges as privileged,
not remote) has been fixed in code since the ledger was written (see
`.reports/component-parity.md`). But grepping the whole `test/` tree for
`indicator_for` or `STATUS_ICONS` (the pages.rb constant) turns up **zero
references outside `pages.rb` itself**. `services_test.rb:230-240` checks only
that the eight icon *files* exist on disk, not that `indicator_for` picks the
right one for a given combination of flags. Upstream's `test-icon-closures.c`
(`status_as_icon`) exists precisely to pin this, and it is one of the 123 gaps
the ledger already names, correctly, as unported. **The fix shipped; the
regression test that upstream has, and that would catch the fix being
reverted, still does not exist.** This is exactly the scenario test-parity
exists to prevent: a real behaviour with no pin.

## Fourth: an entire planned test lane has zero files in it

`spec/README.md` describes an RSpec harness (`kettle-test`) with helpers for
env stubbing, time travel, etc. `spec/spec_helper.rb` exists and loads it.
`find spec -type f` returns exactly those two files — **no `*_spec.rb` file
exists anywhere in the repository.** The drive script's own header comment
says as much: "The specs under `spec/` (currently empty — see
`spec/README.md`) would cover the display-free half." A test lane that is
documented, scaffolded, and has never had a single spec written against it is
not a deferred nicety; per upstream's own test split (pure-logic tests —
`test-settings.c`, `test-utils.c`, `test-palette.c`, `test-proxy-info.c`,
`test-colour-utils.c`, `test-system-info.c`, `test-locale.c`, 60 tests) this is
the exact category of coverage the spec lane was meant to hold, and it holds
none of it that is not already duplicated into the ad hoc `test/*.rb` scripts.

## Conclusion

Not clean. The suite that exists runs and genuinely passes, with exit codes
that mean something — that much is real. But: the gate's documented one-line
invocation is not reproducible on a clean checkout without an unstated
`rake schema` step; the only parity ledger for tests is stale in a way that
currently *overstates* the gap count without saying so; a confirmed bug fix
shipped with no regression test; and an entire planned test lane (RSpec specs)
has zero files in it after being scaffolded.
