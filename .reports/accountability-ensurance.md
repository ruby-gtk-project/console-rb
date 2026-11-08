# Accountability ensurance — console-rb (2026-11-08 audit, re-verified at HEAD `b3420d6`)

Scope per the skill: `lib/`, `exe/`, `.reports/`, `PORTING.md`, grepped for
`TODO`, `FIXME`, `not implemented`, `for now`, `in a future`, plus every
green claim checked for whether it rests on something never executed.

This supersedes the prior round's `.reports/accountability-ensurance.md`
(written against `6bb6956`). Four commits landed since: `3f3daab`, `e999d74`
(dependency cleanup), `44db0db` (tab context menu, bell/status-icon split,
bundled icons), `b3420d6` (test fix). Each is checked against what it
actually changed, not against its commit message.

## Finding 1 (most serious, still open, unchanged): `PORTING.md`'s excuse-language headings are still there

Unchanged from every prior round. `grep -n '^### ' PORTING.md` still returns:

```
PORTING.md:35:### Dropped deliberately
PORTING.md:64:### Not ported
```

No commit since `2b33b04` touches `PORTING.md` at all (confirmed:
`git log 3467879..HEAD -- PORTING.md` is empty). The prior round's finding —
that `2b33b04`'s commit message claimed to rewrite these sections but the
diff shows only the prose under the headings changed, not the
excuse-labelled headings themselves — stands exactly as written, because
nothing has touched the file since. `PORTING.md:71` ("upstream's own TODO")
is still there too. This is still the most serious open finding: a
commit in this repository's own history asserts a documentation fix that a
one-command diff shows did not happen, and three rounds later nobody has
performed the rewrite the skill requires (first-person, admission-first,
no reason given, heading removed).

## Finding 2 (new this round, second most serious): `COMPONENT_PARITY.md` now has the same self-contradiction pattern as Finding 1, in a different document

`44db0db` fixed two real, verified gaps in `pages.rb` — `setup-menu`,
`menu-model`, `default-icon`, and the `icon`/`indicator-icon`/`keyword`/
`loading` page properties (verified directly against
`lib/console_rb/pages.rb:32,38,39,90-93`, not just the commit message). The
commit's own `+18` lines to `COMPONENT_PARITY.md` correctly describe this
fix in a prose note prepended to the top of the file. **But the detailed
per-unit table and the numbered "real gaps" list items #4 and #9, further
down the same file, were never touched and still assert the opposite**:

```
$ sed -n '154p' COMPONENT_PARITY.md
| `Adw.TabView` | 1 | 1 | — | ✓ ...; ✗ `setup-menu`; ✗ `menu-model`; ✗ `default-icon` | **gap** |
$ sed -n '198,201p' COMPONENT_PARITY.md
- **No tab context menu.** ... The port never assigns `tab_view.menu_model`.
  Right-clicking a tab offers nothing.
- **`setup-menu`** ... The port's `close_selected_page` / `detach_selected_page`
  (`pages.rb:123-133`) always act on the *selected* page.
```

`close_selected_page`/`detach_selected_page` do not exist in the current
file — `44db0db` renamed them to `close_action_page`/`detach_action_page` in
the exact same commit this ledger text is supposed to describe. A reader
who opens `COMPONENT_PARITY.md` and reads the detailed sections (which is
most of the file, and the natural place to read for detail) walks away with
a materially false picture of the `pages` unit, directly contradicted by a
note 150 lines above it in the same document. This is structurally the same
defect as Finding 1 — a document whose top-level claim and body claim
disagree because a commit updated a summary without updating the detail it
summarizes — and it is a second instance in this codebase, not a one-off.
Full detail and the fix this needs: `.reports/component-parity.md`'s "Ledger
self-contradiction" section.

This finding points the opposite direction from the usual false-green risk
(it understates progress rather than overstating it), but it is reported
with equal weight because the task's framing is about the ledger's
reliability, not just about which direction an error points: a ledger that
is wrong in either direction cannot be trusted without independent
verification, which is exactly what this round had to do instead of reading
the document at face value.

## Finding 3 (still open, unchanged): new functionality landed with zero test coverage

`44db0db` added the tab context menu (`menu_model`, `setup-menu`,
`tab.detach`/`tab.close` acting on `@action_page`). `grep -n
'context\|menu_model\|setup.menu\|tab\.detach\|tab\.close'
test/drive_console_rb.rb test/services_test.rb` returns zero hits for any of
it. The commit message for `44db0db` says "Verified with
test/drive_console_rb.rb (57/57) and the three existing test files... all
green" — true, but misleading read in isolation: none of those 212 checks
assert anything about the context menu, because none of them exercise a
right-click or call `setup-menu`/inspect `menu_model`. "All green" here means
"did not crash while present", not "the new feature was tested" — the exact
distinction the task's framing draws ("a component no check exercises is
unverified, not done"). The tab context menu is unverified, full stop,
regardless of the overall gate's green.

## Finding 4 (resolved, re-confirmed): the two previously-stale ledgers' prior staleness notes are unchanged and still accurate for what they cover

The prior round's Finding 2 (the `2b33b04`-era staleness notes in
`COMPONENT_PARITY.md`/`TEST_PARITY.md` about the fullscreen box and status
icons) remains correctly resolved and the notes remain accurate for what
they describe — this round's Finding 2 above is a *new*, different
staleness problem introduced by a *later* commit (`44db0db`), not a
regression of this one.

## Finding 5 (still open, unchanged): a scaffolded test lane with zero content

`spec/` still has only `README.md` and `spec_helper.rb`. No `*_spec.rb`
exists anywhere in the repository, confirmed again at HEAD `b3420d6`.

## Finding 6 (still open, unchanged): two test-parity ledgers disagree and neither says so

`TEST_PARITY.md` (root, unchanged since `2b33b04`) says 26/148.
`.reports/TEST_PARITY.md` says 0/148. Neither cross-references the other.
Unchanged since the prior round — `git diff --stat 3467879..HEAD` touches
neither file.

## Grep results against the skill's literal pattern list, re-run at HEAD `b3420d6`

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future' lib/ exe/ .reports/ PORTING.md
```

Zero hits in `lib/` or `exe/`, unchanged. One hit, `PORTING.md:71`
("upstream's own TODO"), already covered under Finding 1.

## Conclusion

Not clean, and the number of live findings went from 1 open+4 resolved last
round to **4 open** this round — not because the port regressed, but because
this round's own audit found a second instance of the exact pattern Finding
1 already named (a document whose summary and detail disagree) in a
different file, plus new functionality shipped with no test pinning it. The
headline finding is unchanged: `PORTING.md`'s excuse-headings and false
claimed fix remain uncorrected three rounds running. The new finding this
round — `COMPONENT_PARITY.md`'s own internal self-contradiction about the
`pages` unit — shows this project has a recurring process defect, not a
one-time lapse: when a commit fixes code and updates a ledger's summary, the
ledger's own detailed body is not being re-run or reconciled, in either
direction (overstating gaps here, previously understating them before
`2b33b04`'s corrections). A reader of either canonical ledger cannot trust
its detailed sections without independently checking the code, which is
exactly the condition that makes a green claim unsafe to take at face value.
