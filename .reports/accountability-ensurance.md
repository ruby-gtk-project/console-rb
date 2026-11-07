# Accountability ensurance — console-rb (2026-11-07 audit)

Scope per the skill: `lib/`, `exe/`, `.reports/`, `PORTING.md`, grepped for
`TODO`, `FIXME`, `not implemented`, `for now`, `in a future`, plus every green
claim checked for whether it rests on something never executed.

## Finding 1 (most serious): a previously-identified violation was never fixed, and is now also factually false

`.claude/skills/accountability-ensurance/SKILL.md` itself documents, under
"What it found here", four hits in `PORTING.md` from an earlier audit round:
`:35 Dropped deliberately`, `:55 Not ported`, `:61 upstream's own TODO`,
`:68 not ported`. This is not a hypothetical example — it is this org's own
record of a finding already made against this exact file.

**All four are still present, at the same or near-identical line numbers,
today:**

```
PORTING.md:35  ### Dropped deliberately
PORTING.md:55  ### Not ported
PORTING.md:61  "upstream's own TODO — it does not implement --wait either"
PORTING.md:65  "untested" (tab tear-off to desktop)
```

A documented finding from a prior round sat unaddressed through at least the
`464a7a0`, `a456082`, `a5a2eab`, `ac2d561` commits. Per the skill's own rule
("No document may contain a sentence a reader could mistake for a decision"),
this file should have been rewritten the moment the finding was made. It was
not.

**Worse: two of the five "Dropped deliberately" bullets are now also simply
untrue**, not just badly worded. `PORTING.md:45-47` still reads:

> **`KgxDepot` / `KgxDespatcher`** — async wrappers around `vte_pty_spawn_async`
> and the D-Bus `OpenURI` portal. `Tab#spawn` calls `spawn_async` directly and
> `Terminal#launch` uses `Gtk::UriLauncher`.

and `PORTING.md:52-53`:

> **`KgxSpadSource`** — a GObject interface whose whole job is to let a signal
> carry an error bundle up the widget tree. Replaced by a callback.

Commit `464a7a0` ("Port the spad source, watcher, livery manager, depot,
despatcher, paste dialog and simple tab") gave all three their own real Ruby
files: `lib/console_rb/depot.rb`, `lib/console_rb/despatcher.rb`,
`lib/console_rb/spad_source.rb` — confirmed present on disk, confirmed tested
in `test/services_test.rb` ("the depot falls back to...", "the FileManager1
arguments are a (ass) tuple", "an unhandled spad reports false"). The document
still asserts these are *not built*, three commits after they were built.
Nobody updated the excuse when the excuse became untrue, which is the
mechanism this skill exists to catch: an unaudited note became load-bearing
and nobody checked it against the code it describes.

### Rewrite owed (not performed by this audit, named here as still outstanding)

Per the skill's rule, these do not get softened to a neutral "now ported"
note either — a neutral correction is still a status label. The honest
record for each of the five bullets at `PORTING.md:41-53` is: whichever ones
are genuinely still absent (`GTree` page registry, `KGX_DEFINE_DATA` closure
structs, `KgxTemplated`/`.ui` template machinery — plausibly still true, not
independently re-verified in this pass) get the first-person admission the
skill prescribes; the two that are now built (`Depot`/`Despatcher`,
`SpadSource`) get deleted from this section and the behaviour they carry
scored on `.reports/component-parity.md`'s ledger instead, since they are no
longer gaps. **Leaving them as "dropped deliberately" is a false negative in
the architecture doc's own right** — it is not merely bad tone, it hides that
these units now exist and have never been through a component-parity pass.

## Finding 2: two "green" ledgers are stale and nothing marks them as such

`COMPONENT_PARITY.md` and `TEST_PARITY.md` (and the older, inconsistent
`.reports/TEST_PARITY.md`) each claim a definite, specific score
(1/12 units, 25/148 tests) as if current. Both predate real porting work —
`464a7a0` and `a456082` — that **closed specific defects each document names
as currently open**: the fullscreen top-bar-style bug, the missing
status-playbox icon, the inverted tab-badge precedence. See
`.reports/component-parity.md` and `.reports/test-parity.md` for the itemised
proof. Neither stale document carries a staleness warning, a "superseded by"
pointer, or a re-verify date. A reader who opens `COMPONENT_PARITY.md` today
is told a bug exists that was fixed days ago — this is a false red, the
inverse of a false green, but it is the same failure of an unaudited document
being treated as current truth. The live risk is the same mechanism in the
other direction: a reader could also just as easily trust a *fixed-looking*
old number that is actually still broken, which is why this skill insists on
re-verifying against the files rather than the ledger.

## Finding 3: a real fix shipped with the regression test it needs still absent — and nothing in the repo says so

The tab-badge precedence fix (`pages.rb:80-87`) is real and confirmed by
reading the code. No test anywhere pins `indicator_for`'s behaviour — grep for
`indicator_for` or `STATUS_ICONS` across `test/` returns nothing outside
`pages.rb` itself. This is not recorded as a gap anywhere before this audit.
A green `rake test` run says nothing about this fix's durability, and no
document said that plainly. It is recorded now, in `.reports/test-parity.md`.

## Finding 4: the runtime gate's green status rests on an unstated manual step

Running this round's gate command exactly as given —
`nix develop --command xvfb-run -a ruby test/drive_console_rb.rb` — on this
checkout **aborts** with `Settings schema 'org.gnome.Console.Rb' is not
installed`, because nothing compiles `data/schemas` first. The 57/57 "DRIVE
OK" result this round's task description cites as the gate is real and was
reproduced by this audit — but only after independently discovering and
running `rake schema` first, a step no README, PORTING.md, or the drive
script's own header comment names. A gate whose passing depends on a step
nobody wrote down is one commit away from a false green the next time someone
runs it cold. Recorded in `.reports/test-parity.md`.

## Finding 5: a scaffolded test lane with zero content

`spec/README.md` documents a full RSpec harness; `find spec -type f` finds
only that README and `spec_helper.rb`. No `*_spec.rb` exists. This is not a
`TODO` comment — it is a populated-looking directory (README, helper, gemfile
entries for `kettle-test`) that is empty of the thing it exists to hold. The
drive script's own comment already says this plainly ("currently empty"), so
this is not a hidden excuse — it is flagged here as a gap that is *honestly
labelled but still unbuilt*, which per the skill is "honest but toothless":
naming the absence is necessary but does not retire the debt.

## Grep results against the skill's literal pattern list

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future' lib/ exe/ .reports/ PORTING.md
```

One hit, in `PORTING.md:61`, already covered under Finding 1
("upstream's own TODO"). **Zero hits in `lib/` or `exe/`** — no stray
`# TODO`, `# not required here`, `# simplified` comments in the actual source,
which is a genuinely clean result for that narrower grep. The violations that
matter here are structural (whole sections presenting undone work as settled
architecture) and in the staleness of the standalone ledgers, not scattered
inline comments — the grep alone understates the finding, which is why this
report does not stop at the grep.

## Conclusion

Not clean, and the most serious entry is the oldest one: a violation this
org's own skill file already named, in this exact file, was never corrected,
and in the time it sat uncorrected the underlying facts moved further away
from what it still claims. Everything else found this round — stale ledgers
presented without a staleness mark, a fix with no pin, a gate with an unwritten
precondition, an empty spec lane — is a smaller instance of the same pattern:
documents outliving the state they describe, read as current by default.
