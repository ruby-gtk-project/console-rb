# Test parity — console-rb (2026-11-08 audit, re-verified at HEAD `b3420d6`)

| | |
|---|---|
| Upstream tests | `tests/` — 21 `.c` files; `TEST_PARITY.md` counts **148** test cases across them (12 are repeaters expanding to ~90 further runtime cases) |
| Canonical ledger | `TEST_PARITY.md` @ root, last substantively edited `2b33b04`, unchanged since: **148 upstream / 26 ported / 122 gaps** |
| Second ledger | `.reports/TEST_PARITY.md` (older, generated), unchanged: **0/148**, still never reconciled with the root ledger |
| Runtime gate | Re-ran it live this round: real, reproducible, green, and the task's stated gate numbers (212 checks, 0 failed, 13 components) are exactly reproduced |

This supersedes the prior round's `.reports/test-parity.md` (written against
`6bb6956`). `git diff --stat 3467879..HEAD -- TEST_PARITY.md` is empty —
nothing touched the test-parity ledger between rounds. The only test-related
change was `b3420d6`, which fixed `services_test.rb`'s tab-badge assertion
after `44db0db` renamed `Pages#indicator_for` to `#status_icon_for`; it is a
same-count fix (still 55 `services_test.rb` checks), not a new test.

## The runtime gate, re-run live this round

```
nix develop --command xvfb-run -a rake test
```

Result, this run, right now:

```
== test/integration_test.rb
29/29 checks passed
== test/actions_test.rb
71/71 checks passed
== test/services_test.rb
55/55 checks passed
== test/drive_console_rb.rb
57 of 57 checks passed
DRIVE OK
```

29 + 71 + 55 + 57 = **212**, matching the task's stated gate exactly (212
checks passed, 0 failed). `test/gtk_driver.rb` makes the exit code real
(`exit(total.zero? ? 0 : 1)`); all four scripts exited zero. This is the
same gate the prior round confirmed, re-confirmed again now with the latest
four commits in the tree, and it is genuinely reproducible — that much is
solid.

## What the runtime gate does and does not prove (unchanged from the prior round, still true)

212 checks passing is real and reproducible, but it is **not** a measurement
of test parity against upstream's 148 named test cases by name.
`drive_console_rb.rb` and `integration_test.rb` are new integration scripts
with no upstream counterpart; `actions_test.rb`/`services_test.rb` are only
partially censused against the 148 upstream cases. The gate exercises the
component — including, now, the tab context menu and bell/status-icon code
added in `44db0db`, which `services_test.rb`'s existing checks and
`drive_console_rb.rb`'s tab/overview steps pass through — but passing through
a check is "exercised, did not crash", not "pinned to upstream's behaviour by
name". No new check was added this round that specifically asserts the
`setup-menu`/`menu-model`/right-click-targets-the-clicked-tab behaviour
`44db0db` added; `services_test.rb`'s `check_tab_badge_precedence` (from the
prior round) only covers the icon-precedence logic, not the context-menu
wiring. **The tab context menu itself has no test, upstream or ported** —
worth naming directly, since it is new functionality added this round with
zero assertion coverage of its own; the 212-count gate's green does not
include a check for it at all, it simply doesn't crash while it's present.

## The test-parity ledger's own numbers: still 26/148, unchanged and still self-admittedly incomplete

`TEST_PARITY.md` is byte-for-byte unchanged since the prior round
(confirmed by the empty diff above). Its own body still states the
depot/despatcher/spad-source/livery recount against upstream's
`test-depot.c` (3), `test-despatcher.c` (1), `test-spad-source.c` (4) and
`test-livery.c` (5) functions "is still owed". Per the `test-parity` skill
there is no state between `ported` and `gap`; every one of the 122 gap rows
remains exactly that.

## Two ledgers still disagree and neither says so (unchanged)

`TEST_PARITY.md` (root) says 26/148. `.reports/TEST_PARITY.md` says 0/148.
Both still checked into the same branch, neither cross-references the
other. Unchanged from the prior round — recorded again in
`.reports/accountability-ensurance.md`.

## Still open: the empty spec lane (unchanged)

`spec/` still has only `README.md` and `spec_helper.rb`; `find spec -type f`
confirmed again at HEAD `b3420d6`. No `*_spec.rb` exists anywhere in the
tree.

## Conclusion

Not clean. The runtime gate genuinely passes, is reproducible, and matches
the task's cited numbers exactly (212/212, 0 failed) — that is real and
should be stated plainly. But: (1) the actual test-parity number against
upstream's 148 named cases is still at most 26/148, self-admittedly
incomplete, and contradicted by a second committed ledger claiming 0/148;
(2) an entire scaffolded RSpec lane remains empty; (3) new functionality
landed this round (the tab context menu) with zero test coverage of its
own, which the drive gate's green number does not surface because the gate
counts "did not crash", not "is pinned by a test". The task's framing — a
component no check exercises is unverified, not done — applies directly to
the tab context menu: it is exercised incidentally by the drive script's
existing right-click-adjacent steps at best, and has no check that would
fail if `setup-menu`/`menu-model` regressed.
