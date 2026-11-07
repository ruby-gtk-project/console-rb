# Accountability ensurance — console-rb (2026-11-07 audit, re-verified at HEAD `6bb6956`)

Scope per the skill: `lib/`, `exe/`, `.reports/`, `PORTING.md`, grepped for
`TODO`, `FIXME`, `not implemented`, `for now`, `in a future`, plus every green
claim checked for whether it rests on something never executed.

This supersedes the same-day draft of this file, which was written against
port `a5a2eab`. Commit `2b33b04` ("Close window-unit gaps, fix stale ledgers,
and pin tab-badge precedence") landed after that draft and its commit message
explicitly claims to close several of its findings. Each claim was re-checked
against the actual diff and the actual files, not against the commit message.

## Finding 1 (most serious, still open): a claimed fix to the excuse-language violation did not happen

The prior round of this report (and, before it, this org's own
`.claude/skills/accountability-ensurance/SKILL.md`, under "What it found
here") flagged four hits in `PORTING.md`: `### Dropped deliberately` (line
35), `### Not ported` (line 64), `"upstream's own TODO"` (line 71), plus the
toothless `"not ported"` language around it.

Commit `2b33b04`'s own message says: *"Docs: rewrite PORTING.md's 'Dropped
deliberately'/'Not ported' sections, which still called Depot/Despatcher/
SpadSource dropped after they were ported as real files in 464a7a0."*

**Reading the actual diff (`git show 2b33b04 -- PORTING.md`) and the current
file shows the headings were never removed.** What changed is the prose
*under* the two excuse-labelled headings — three paragraphs correcting the
Depot/Despatcher/SpadSource claim, and a rewording of the `--wait` and
tab-tear-off bullets into first-person sentences. The section titles
themselves, which are the thing the skill's own rule names as the violation
("No document may contain a sentence that a reader could mistake for a
decision"), are unchanged, verbatim, right now:

```
$ grep -n '^### ' PORTING.md
PORTING.md:35:### Dropped deliberately
PORTING.md:64:### Not ported
```

A heading reading "Dropped deliberately" is exactly the construction the
skill names first in its table ("Presents the absence as chosen. Nobody chose
it; nobody with authority was asked") and exactly what it rewrites in its own
worked example from this file. The commit message describes a rewrite that,
measured against the diff it actually produced, did not perform the one
rewrite the skill requires — removing the status-field heading and replacing
the whole entry with the first-person admission format. The prose under the
headings got more accurate (and in the `--wait`/tear-off bullets, slightly
closer to first person: "I have not ported these", "I have not verified")
but every entry still gives a reason ("that was wrong even then", "upstream's
own TODO", "I have not verified") instead of the one the skill requires —
the writer's own incompetence — and the section titles still file the whole
thing as settled architecture.

**This is the finding the task description asked to be treated as the most
serious kind: a commit message asserting a documentation fix that the diff
does not support.** The next reader of `PORTING.md` sees two headings that
read as decisions and a commit history that says those decisions were already
corrected. Both are false.

### What is actually still missing behind the headings (unchanged from the prior round, re-verified)

- `GTree` page registry, `KGX_DEFINE_DATA` closure structs, `KgxTemplated`/
  `.ui` template machinery — genuinely not needed as *mechanisms* (Ruby has
  closures and GC), but the skill's rule is that the sentence must name the
  **behaviour**, not the mechanism, and attribute the gap to the writer, not
  to the mechanism being unnecessary. Neither bullet does this.
- `--wait` beyond a single invocation and tab tear-off to the desktop by drag
  are the two true remaining gaps in that section, now in first person but
  still giving a reason ("upstream's own TODO", "I have not verified") rather
  than the required admission.

### Rewrite owed (still not performed)

Every bullet under both headings needs the heading removed and the entry
replaced with the skill's format: first person, leads with the admission,
reason is the writer's own failure, names the user-facing behaviour, cites
both sides with file:line. This was owed at the prior round and is owed now;
`2b33b04` did not close it despite saying it did.

## Finding 2 (resolved since the prior round): the two stale "green" ledgers were corrected

The prior round's Finding 2 — `COMPONENT_PARITY.md` and `TEST_PARITY.md`
describing the fullscreen top-bar-style bug and the missing status-playbox
icon as live defects after they were already fixed in code — **is now fixed**.
`2b33b04` added a staleness note to both files' headers, struck through the
resolved cross-cutting findings in `COMPONENT_PARITY.md` (`~~Fixed~~`, items
1, 5, 8, 10, 13), and gave the paste dialog its own unit (13) with a `gap`
verdict instead of leaving it unscored. Verified by reading the current files,
not the commit message alone.

## Finding 3 (resolved): the tab-badge-precedence fix now has a regression test

The prior round's Finding 3 — a real fix (`pages.rb` testing `remote` before
`privileged`) shipped with no test pinning it — is fixed.
`test/services_test.rb#check_tab_badge_precedence` (added in `2b33b04`) ports
upstream's `test-icon-closures.c` `status_as_icon_cases` table directly,
including the `remote|privileged -> remote` precedence case, and is called
from the suite's run list (`services_test.rb:42`). Confirmed present and
confirmed it runs as part of `rake test`'s 55 `services_test.rb` checks this
round (see `.reports/test-parity.md`).

## Finding 4 (resolved): the schema prerequisite is now documented

The prior round's Finding 4 — the gate's documented one-line invocation aborts
without an unstated `rake schema` step — is fixed. `README.md:25,100,110,115`
and `test/drive_console_rb.rb:18-25` both now state the `rake schema`
prerequisite explicitly.

## Finding 5 (still open): a scaffolded test lane with zero content

`spec/README.md` documents a full RSpec harness; `find spec -type f` still
returns only that README and `spec_helper.rb`. No `*_spec.rb` exists anywhere
in the repository, confirmed again at HEAD `6bb6956`. Honestly labelled
("currently empty" in the drive script's own header) but still unbuilt, which
per the skill is "honest but toothless" — naming the absence does not retire
the debt, and nothing in this round's commits added a single spec.

## Finding 6 (new this round): the test-parity ledger's own admitted incompleteness is a gap, not a caveat

`TEST_PARITY.md`'s current header (post-`2b33b04`) reads **148 upstream / 26
ported / 122 gaps**, and the body says outright that the depot/despatcher/
spad-source/livery recount "is still owed" — i.e. the document's own author
states the number has not been fully re-derived. Per the `test-parity` skill
there is no third state between `ported` and `gap`; an admittedly-unrecomputed
count is not a third state either, it is 122 open gap rows, full stop, and
"the recount is owed" is prose describing debt, not a reason to treat any of
those 122 rows as anything but `gap`. Separately, `.reports/TEST_PARITY.md`
(a different, older file, generated from an earlier full per-function pass)
still states **0/148** at the top and is never reconciled against the root
`TEST_PARITY.md`'s 26/148. Two documents in the same repository claim
different, both-stated-as-current counts for the same comparison and neither
says the other exists. A reader who opens one or the other walks away with a
different number for the same fact, and nothing in the repo resolves which
one is right.

## Grep results against the skill's literal pattern list, re-run at HEAD `6bb6956`

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future' lib/ exe/ .reports/ PORTING.md
```

One hit, `PORTING.md:71` ("upstream's own TODO"), already covered under
Finding 1. Zero hits in `lib/` or `exe/`. The violations that matter are
structural — a heading that presents undone work as settled architecture, and
two ledgers quietly disagreeing about the same number — not scattered inline
comments.

## Conclusion

Not clean. The headline finding has not changed, only sharpened: the
org's own skill file documents this exact violation in this exact file, a
commit explicitly claims to have fixed it, and the diff that commit produced
shows it did not. That is a false claim of remediation sitting in the git
history right now, which is a more serious instance of the pattern than the
original unaddressed note was — it is no longer merely an omission nobody
checked, it is a stated fix that a one-command diff shows is false. Three of
the five findings from the prior round (stale ledgers, unpinned fix, undocumented
prerequisite) are genuinely resolved, which is worth recording plainly so the
real progress is not lost in the finding above it. The empty spec lane and the
two-ledgers-disagreeing problem remain, unresolved, at HEAD `6bb6956`.
