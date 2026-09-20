---
description: |
  Reviews this Ruby GTK4 port against the original app it was ported from and
  writes a dated PARITY_REPORT into .reports/ on the ruby branch.
  Triggered by hand once a port is believed finished.

on:
  workflow_dispatch:
    inputs:
      upstream_branch:
        description: "Branch holding the original app (blank = the fork parent's default branch)"
        required: false
        type: string

engine: copilot
model: gpt-5

timeout-minutes: 30

permissions: read-all

network:
  allowed: [defaults, github]

tools:
  edit:
  bash: ["*"]
  github:
    toolsets: [repos]

steps:
  - name: Scan the port against its upstream
    env:
      GH_TOKEN: ${{ github.token }}
      UPSTREAM_BRANCH: ${{ inputs.upstream_branch }}
    run: |
      set -euo pipefail
      OUT=/tmp/gh-aw/agent/parity
      mkdir -p "$OUT"

      # The original and the port are two branches of this repository: the
      # workspace is the port (ruby), the original is fetched alongside.
      cd "$GITHUB_WORKSPACE"

      if [ -z "$UPSTREAM_BRANCH" ]; then
        UPSTREAM_BRANCH=$(gh api "repos/${{ github.repository }}" --jq '.parent.default_branch // empty')
      fi
      if [ -z "$UPSTREAM_BRANCH" ]; then
        echo "Could not determine the upstream branch — pass it explicitly." >&2
        exit 1
      fi

      git fetch --quiet --depth 1 origin "$UPSTREAM_BRANCH:refs/remotes/origin/$UPSTREAM_BRANCH"
      git worktree add --quiet --detach /tmp/gh-aw/agent/trees/upstream "origin/$UPSTREAM_BRANCH"

      {
        echo "repo=${{ github.repository }}"
        echo "upstream_branch=$UPSTREAM_BRANCH"
        echo "upstream_sha=$(git rev-parse --short "origin/$UPSTREAM_BRANCH")"
        echo "port_sha=$(git rev-parse --short HEAD)"
        echo "date=$(date -u +%Y-%m-%d)"
      } > "$OUT/context.env"

      # The port tree is the workspace itself.
      bash .github/aw/parity-scan.sh \
        /tmp/gh-aw/agent/trees/upstream "$GITHUB_WORKSPACE" "$OUT"

      cat "$OUT/context.env"

post-steps:
  - name: Commit the report
    env:
      GITHUB_TOKEN: ${{ secrets.GH_AW_PROJECT_GITHUB_TOKEN }}
      GH_TOKEN: ${{ secrets.GH_AW_PROJECT_GITHUB_TOKEN }}
    run: |
      set -euo pipefail
      # the census step recorded the date the agent was told to use
      date=$(grep '^date=' /tmp/gh-aw/agent/parity/context.env | cut -d= -f2)
      f=".reports/PARITY_REPORT-${date}.md"
      [ -s "$f" ] || { echo "::error::agent did not write $f"; exit 1; }
      git config user.name  "github-actions[bot]"
      git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
      git add .reports
      if git diff --cached --quiet; then
        echo "the documents are unchanged — nothing to commit"
        exit 0
      fi
      git commit -m "reports: parity review $(date -u +%F)"
      url="https://x-access-token:${GITHUB_TOKEN}@github.com/${{ github.repository }}.git"
      git pull --rebase --autostash "$url" ruby
      git push "$url" HEAD:ruby

---

# Parity review

A port is finished when the Ruby app does everything the original does. Your
job is to say whether that is true for this repository, on the evidence, and
write it down as a report that the next person can re-run and compare against.

You are not judging code quality, idiom or style. Only: is anything the
original does missing from the port.

## Step 1 — What the scan found

A scan has already run. `/tmp/gh-aw/agent/parity/` holds:

- `context.env` — `repo`, `upstream_branch`, `upstream_sha`, `port_sha`, `date`.
- `metrics.json` — per category: how many items the original has, how many were
  found in the port, how many were not, and the coverage percentage.
- `upstream-<category>.txt` — every item found in the original.
- `found-<category>.txt` / `missing-<category>.txt` — the split.

The categories, and what a missing item means:

| Category | Items | A miss means |
|---|---|---|
| `actions` | `app.*` / `win.*` GAction names | a command the original exposes that the port does not |
| `accels` | keyboard accelerators | a shortcut that does nothing in the port |
| `settings` | GSettings keys | a preference the original has |
| `menulabels` | menu and UI labels | a menu entry or control |
| `widgets` | Gtk/Adw types used | a kind of UI element — often a whole dialog or page |
| `cli` | command line flags | an invocation the original supports |
| `strings` | translatable strings | user-visible text, so usually a feature |
| `datafiles` | desktop entry, metainfo, schemas, resources | something the packaged app needs |

The two trees are on disk: the original at `/tmp/gh-aw/agent/trees/upstream`,
the port is the workspace. Read them.

## Step 2 — Judge every miss

The scan matches literals, so it is a lead, not a verdict. For **each** item in
each `missing-*.txt`, open both trees and decide which it is:

- **Missing** — the original has this and the port does not. A real gap.
- **Present** — the port has it under a different spelling. Ruby bindings
  rename things (`AdwAboutDialog` is `Adwaita::AboutDialog`), and a label may
  be built rather than declared. Say where you found it.
- **Not applicable** — it does not carry over. Build-system strings, enum type
  names, GJS/Vala-specific plumbing, translator credits. Say why.

Do not classify an item without looking. "Probably fine" is not a judgement,
and a report that waves misses through is worse than no report, because it
tells the next person the port was checked when it was not.

When a cluster of misses points at one feature — an accelerator, its menu
label and its strings all absent together — report it once as that feature,
not as three items.

## Step 3 — Look for what the scan cannot see

The scan compares names. It cannot see behaviour. Spend real effort here,
working from the original's source:

- **Flows** — does each multi-step path (open → edit → save, first run, an
  error and its recovery) exist end to end in the port?
- **States** — empty, loading, error and offline states. These are frequently
  the parts a port leaves out, and they rarely have distinctive strings.
- **Window plumbing** — geometry saved and restored, close confirmation,
  modality, focus.
- **Data** — file formats read and written, config file locations, migration
  of existing user data.
- **Integrations** — D-Bus services, portals, notifications, the clipboard,
  drag and drop, network APIs.

## Step 4 — Write the report

Write `.reports/PARITY_REPORT-<date>.md` in the workspace (the port's `ruby`
branch), where `<date>` is from `context.env`. Generated parity documents live
in `.reports/` — create the directory first. Exactly this shape, so that two
reports on the same repo can be compared:

```markdown
# Parity report — <repo>

| | |
|---|---|
| Reviewed | <date> |
| Port | `ruby` @ `<port_sha>` |
| Original | `<upstream_branch>` @ `<upstream_sha>` |
| Verdict | **PASS** / **FAIL** |

## Summary

<Two or three sentences. If FAIL, lead with what is missing.>

## Metrics

| Category | Original | Found | Gaps | Coverage |
|---|---:|---:|---:|---:|
<one row per category from metrics.json, with Gaps being the count that
survived your judgement in Step 2, not the raw missing count>

## Gaps

<One `### <feature>` per real gap, ordered by how much of the app it is.
Each gives: what the original does, where in the original source it lives,
and what the port has instead. If there are none, write "None found.">

## Behaviour checked

<What you checked in Step 3 and what you concluded, including the things
that were fine. Name the flows and states by name.>

## Dismissed

<Every scan miss you judged Present or Not applicable, one line each with
the reason. This is what makes the report auditable.>

## Not verifiable here

<Anything that needs the app running — visual layout, animation, input
handling, performance. This review is static; say plainly what it did not
cover.>

​```json
<the metrics.json contents, with a "verdict" and "gaps" field added>
​```
```

The verdict is **PASS** only when every category's surviving gap count is zero
and Step 3 turned up nothing. Anything else is **FAIL** with the gaps listed.
A port with one missing dialog is not a pass with a note.

## Rules

- Never edit anything but the report file.
- The commit is automatic — the run fails if the report is missing when you
  finish, so write it before you finish.
- If the port has no application code, stop and say so — there is nothing to
  review yet, and the run should end without the report.
- If you could not complete the review, say why in the report and mark the
  verdict FAIL. Never write a report you know is incomplete without saying so
  in it.
