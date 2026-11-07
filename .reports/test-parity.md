# Test parity — console-rb (2026-11-07 audit, re-verified at HEAD `6bb6956`)

| | |
|---|---|
| Upstream tests | `tests/` — 21 `.c` files; `TEST_PARITY.md` counts **148** test cases across them (12 are repeaters expanding to ~90 further runtime cases) |
| Canonical ledger | `TEST_PARITY.md` @ root, last substantively edited `2b33b04`: **148 upstream / 26 ported / 122 gaps** |
| Second ledger | `.reports/TEST_PARITY.md` (older, generated): **0/148**, never reconciled with the root ledger |
| Runtime gate | Re-ran it live this round (below): real, reproducible, green |

This supersedes the same-day draft of this file (written against `a5a2eab`).
Three of its four findings are now fixed in the live ledger/docs (see
`.reports/accountability-ensurance.md` Findings 3 and 4); this version
re-verifies the gate itself and restates what is still open.

## The runtime gate, re-run live this round

```
nix develop --command bash -c 'rake schema && xvfb-run -a rake test'
```

Result, this run, right now:

```
integration_test.rb   29/29 checks passed
actions_test.rb        71/71 checks passed
services_test.rb       55/55 checks passed
drive_console_rb.rb    57 of 57 checks passed — DRIVE OK
```

212/212 total. All four suites exit zero; `test/gtk_driver.rb` makes the exit
code real (`exit(total.zero? ? 0 : 1)`). The task's cited gate — "57 checks
passed, 0 failed, 20 components" — is exactly the `drive_console_rb.rb` line
above, confirmed reproducible on a clean re-run, **and the schema
prerequisite the prior draft found undocumented is now stated** in
`README.md` and the drive script's own header (`test/drive_console_rb.rb:18`).
Several `GLib-GObject-CRITICAL: g_object_ref: assertion 'G_IS_OBJECT (object)'
failed` warnings print during the `actions_test.rb`/`drive_console_rb.rb`
runs and do not fail any check — worth independent follow-up (a ref-counting
bug the suite isn't currently asserting against), but not itself a test-parity
finding since nothing claims it is checked.

## What the runtime gate does and does not prove

212 checks passing is a real, reproducible, honestly-counted number — but it
is **not** a measurement of test parity. Test parity per the skill is a
bijection against upstream's 148 named test cases, by name, and the gate's 212
checks are not that: `drive_console_rb.rb` and `integration_test.rb` are new
integration scripts written for the port with no upstream counterpart, and
even the ones that do map to upstream tests (`actions_test.rb`,
`services_test.rb`) are only partially censused against the 148 upstream
cases — which is exactly what the next section is about. **A component or
behaviour the 212 checks drive through is "exercised", not "proven to match
upstream's pinned property" — those are different claims**, and the task's
framing ("a component no check exercises is unverified, not done") describes
a necessary condition, not a sufficient one. 20 components being driven by
the gate does not mean those same 20 components have test parity; several of
them (shortcuts dialog, font picker a11y, search-bar Return key, Ctrl+click
link-open) are simultaneously driven by the gate *and* listed as open gaps in
`COMPONENT_PARITY.md` (see `.reports/component-parity.md`) — the gate
confirms they do not crash, not that they behave like upstream.

## The test-parity ledger's own numbers: 26/148, and self-admittedly incomplete

`TEST_PARITY.md`'s current body states plainly that the depot/despatcher/
spad-source/livery recount against upstream's `test-depot.c` (3),
`test-despatcher.c` (1), `test-spad-source.c` (4) and `test-livery.c` (5)
functions "is still owed" — i.e. the 26-ported figure has not been fully
re-derived from a complete per-function comparison since `464a7a0` added
`services_test.rb`. Per the `test-parity` skill there is no state between
`ported` and `gap`; treat every one of the 122 gap rows as exactly that,
full stop, regardless of how much of `services_test.rb`'s real new coverage
has not yet been credited against them. The honest state is **at most
26/148, at best somewhat higher once the owed recount happens, and nobody has
done that recount** — reported here as still open, not guessed at.

## Two ledgers disagree and neither says so

`TEST_PARITY.md` (root) says 26/148. `.reports/TEST_PARITY.md` (committed
earlier, from a full per-function pass) says 0/148. Both are checked into the
same branch, both state a specific number as if current, and neither
cross-references the other. A reader who opens either walks away with a
different number for the same underlying comparison. This is recorded as a
standing gap in `.reports/accountability-ensurance.md` Finding 6.

## Still open: the empty spec lane

`spec/` still has only `README.md` and `spec_helper.rb`; no `*_spec.rb` exists
anywhere in the tree, confirmed again at HEAD `6bb6956`. Per upstream's own
test split, the pure-logic suites this lane was scaffolded for
(`test-settings.c`, `test-utils.c`, `test-palette.c`, `test-proxy-info.c`,
`test-colour-utils.c`, `test-system-info.c`, `test-locale.c`, ~60 tests) are
exactly the category this lane would hold, and it holds none that is not
already duplicated into the ad hoc `test/*.rb` scripts.

## Conclusion

Not clean. The runtime gate genuinely passes and is reproducible — that much
is solid and should be stated plainly rather than buried under the gaps below
it. But the gate's 212/57 numbers answer "does the port's own integration
script pass", not "does the port have test parity with upstream's 148
pinned cases" — those are different questions, and conflating them is exactly
the false-green risk the task asked this audit to watch for. The actual
test-parity number is at most 26/148 (122 gaps), self-admittedly incomplete
even at that, contradicted by a second committed ledger claiming 0/148, and
an entire scaffolded test lane (RSpec specs) remains empty.
