# Test parity — console-rb

| | |
|---|---|
| Upstream | `main` @ `599b703` (GNOME Console, C) |
| Port | `ruby` @ `dd5fbc0` |
| Test command | `rake test` |
| Upstream tests | **148** (21 files; 12 are repeaters expanding to ~90 further runtime cases) |
| Ported | **25** |
| Gaps | **123** |

Two states only. `ported` means a named Ruby test pins **the whole** property.
`gap` is everything else — including a test that pins part of a property, and
including anything `PORTING.md` describes as deliberately dropped. Nothing
authorises a skip: see `.claude/skills/test-parity/SKILL.md`.

Every gap carries the **behaviour still owed** — what a Ruby test must pin,
stated as something the terminal does for a person.

## Where the port stands

By area (these three groups partition all 148 upstream tests):

| Area | Upstream files | Tests | Ported | Gaps |
|---|---|---:|---:|---:|
| Closures, template machinery, spawn wrappers | `test-file-closures.c`, `test-shared-closures.c`, `test-icon-closures.c`, `test-templated.c`, `test-spad-source.c`, `test-depot.c`, `test-despatcher.c` | 44 | 4 | 40 |
| Widgets and behaviour | `test-window.c`, `test-spad.c`, `test-train.c`, `test-livery.c`, `test-tab.c`, `test-empty.c`, `test-theme-switcher.c`, `test-pages.c`, `test-remote.c`, `test-playbox.c` | 44 | 12 | 32 |
| Pure logic | `test-settings.c`, `test-utils.c`, `test-palette.c`, `test-proxy-info.c`, `test-colour-utils.c`, `test-system-info.c`, `test-locale.c` | 60 | 9 | 51 |
| **Total** | | **148** | **25** | **123** |

A test that pins part of a property counts as a gap. **Seventeen** port tests
cover their upstream counterpart only partly — direction but not saturation,
count but not fidelity, three of eight theme cases, one of seven rounding cases
— and each is recorded as a gap with the missing half named.

One further test is counted a gap for being **vacuous**:
`actions_test.rb#proxy settings map to environment variables` asserts only that
the result is a Hash whose keys pair upper and lower case. The suite installs
no isolated GSettings backend, so it reads the developer's real desktop; on a
machine with proxy mode `none` the hash is empty and both assertions pass
having checked nothing.

Twelve upstream rows are repeaters (a loop generating cases). They are one row
each here, with the range stated, and expand to roughly 90 further runtime
assertions — all of them currently unpinned.

## Divergences the missing tests are already hiding

These are not merely untested. The port's behaviour differs from upstream
**now**, and the absent test is why nobody noticed. Each is a bug to fix, not
just a test to write.

### 1. Tab status badge precedence is inverted
`lib/console_rb/pages.rb:82` tests `:privileged` before `:remote`. Upstream
(`test-icon-closures.c`, `status_as_icon`) pins `REMOTE|PRIVILEGED` → **remote**.
A root shell over SSH therefore badges as privileged, not remote — the single
most dangerous state the indicator exists to signal. There is no playbox icon
at all.

### 2. `toolbox list` is classified as a container session
`kgx_is_playbox` requires the *subcommand*: `toolbox enter` yes, `toolbox list`
and bare `toolbox` no, `sh /usr/bin/distrobox enter` yes. `ProcessInfo#playbox?`
matches the program name only, so ordinary commands get the container
header-bar colour and the `sh`-wrapped form is missed entirely.

### 3. Home-directory abbreviation is gone
`lib/console_rb/window.rb:187` assigns the raw path. Upstream's 7
`file_as_subtitle` tests pin `~` for `$HOME`, suppression when the subtitle
would repeat the title, and the `$HOMEsuffix` guard added for upstream issue
#445. None of it survives.

### 4. Non-UTF-8 paths are pushed raw into GTK labels
Upstream deliberately renders them percent-encoded as a URI in the subtitle and
with U+FFFD in the display string. `window.rb:187` and `tab.rb:334,342` pass the
bytes straight through.

### 5. `-e 'ls *.txt'` no longer runs a shell
`CLI#split_command` + `Shellwords.split` gives `["ls", "*.txt"]`. Upstream wraps
any command containing shell syntax in `/bin/sh -c` and resolves a bare binary
to its absolute path. `if [ -e foo ]; then xeyes; fi` splits into rubble. This
is every scripted and desktop-file invocation of the terminal.

### 6. `--command=bash -- zsh` silently last-wins
Upstream returns `KGX_ARGUMENT_ERROR_BOTH`.

### 7. Window geometry is saved even when the user opted out
`Application#save_window_state` writes unconditionally; upstream's
`restore-window-size=false` makes both reads and writes no-ops.

### 8. `Palette.parse` accepts 3-digit hex
It delegates to `Gdk::RGBA.parse`. Upstream rejects `#ABC` with
`WRONG_LENGTH`, so a malformed `.livery` file now imports with wrong colours
instead of failing.

### 9. The tab bar never inverts
No `inverted` binding on the `Adwaita::TabBar` (`window.rb:32,48`), so
left-handed window-button layouts get the tab bar on the wrong side.

### 10. `Palette#opaque` always allocates
Upstream's `as_opaque` returns the *same* pointer when already opaque. The
identity property the test pins cannot hold here.

### 11. Exported liveries are not byte-compatible with upstream
`Palette#hex` uses `%02x` — lower case. Upstream's `colour-utils/to_string`
pins exactly six **upper-case** hex digits. `PORTING.md` claims key-file import
and export "stay byte-compatible with upstream"; they do not, and the port's
round-trip test never compares bytes so the divergence is invisible.

### 12. The process locale is never set
There is no `setlocale` call anywhere in `lib/` or `bin/`. Upstream's
`locale/init` pins that the *process* locale follows the user, not just the
message catalogue — so numbers, dates and the locale child processes inherit
are wrong.

### 13. Scrollback is not clamped
`Settings#scrollback_lines` returns the raw int64; upstream clamps into int
range and maps anything negative to -1. A `scrollback-lines` above `INT_MAX`
reaches VTE unclamped.

---

## Suite: file, shared and icon closures — `test-file-closures.c`, `test-shared-closures.c`, `test-icon-closures.c` (30)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 1 | `file_as_subtitle/null_when_null` | no directory known ⇒ no subtitle at all | — | gap | A window with no directory yet shows a bare title, not a blank second line |
| 2 | `file_as_subtitle/no_path` | a `trash://`-style cwd with no local path produces no subtitle | — | gap | A shell whose directory isn't a local path leaves the header subtitle off |
| 3 | `file_as_subtitle/raw_matches_title` | subtitle suppressed when it would repeat the title | — | gap | The header never shows the same string twice |
| 4 | `file_as_subtitle/non_utf8` | invalid UTF-8 shown percent-encoded as a URI | — | gap | A directory whose name isn't valid UTF-8 displays legibly, not as mojibake |
| 5 | `file_as_subtitle/non_utf8_in_home` | URI form wins over home-collapsing | — | gap | A badly-named directory inside home shows as a URI, not half-collapsed garbage |
| 6 | `file_as_subtitle/outside_home` | a path outside `$HOME` shown verbatim | — | gap | `cd /etc` puts `/etc` in the header, unabbreviated |
| 7 | `file_as_subtitle/outside_home_prefix` | `/homexsuffix` is not "inside home" — regression for issue #445 / MR !188 | — | gap | A directory merely starting with home's characters is not shown as `~…` |
| 8 | `file_as_subtitle/is_home` | `$HOME` renders as `~` | — | gap | Sitting in your home directory shows `~` |
| 9 | `file_as_subtitle/in_home` | a path under `$HOME` renders as `~/in/home` | — | gap | `cd ~/src/foo` shows `~/src/foo` |
| 10 | `file_as_display/null_when_null` | no file ⇒ no display string | — | gap | A tab with no known directory shows no directory text |
| 11 | `file_as_display/utf8` | a normal path displays as its local path | — | gap | A tab shows the directory the shell is in |
| 12 | `file_as_display/non_utf8` | invalid byte replaced by U+FFFD so the label renders | — | gap | An undecodable byte still renders, with a replacement glyph |
| 13 | `file_as_display/no_path` | a pathless URI yields no display string | — | gap | A remote cwd doesn't produce a bogus local-looking path |
| 14 | `file_as_display_or_uri/null_when_null` | no file ⇒ no tooltip | — | gap | A tab with no directory has no tooltip |
| 15 | `file_as_display_or_uri/utf8` | tooltip is the local path when there is one | — | gap | Hovering a tab shows its directory |
| 16 | `file_as_display_or_uri/non_utf8` | falls back to the URI in the tooltip | — | gap | Hovering a badly-named directory shows a readable URI |
| 17 | `file_as_display_or_uri/no_path` | a pathless URI shown as the URI rather than dropped | — | gap | Hovering a remote tab still tells you where it is |
| 18 | `manager_null_when_null` | style-manager lookup off-display returns nothing, no crash | — | gap | A window built before it is shown doesn't crash |
| 19 | `settings_null_when_null` | GTK-settings lookup off-display returns nothing, no crash | — | gap | A window built before it reaches a screen still picks up settings |
| 20 | `text_or_fallback/case_%` — repeater, 6 cases | whitespace-only counts as absent, so the fallback wins | — | gap | A shell reporting a blank title falls back to the tab's own title, then "Console" |
| 21 | `object_or_fallback` | active page's path falls back to its initial path | — | gap | Before the shell reports a directory, the header shows where the tab opened |
| 22 | `enum_is` | theme-enum equality both ways | `actions_test.rb#a day theme resolves to day regardless of the system` | **ported** | — |
| 23 | `flags_includes` | a mask contains a flag only when every bit is set | `integration_test.rb#it is not mistaken for a remote session` | **ported** | — |
| 24 | `bool_and` | full truth table for translucent = transparency AND floating | — | gap | See-through only when transparency is on *and* the window is floating |
| 25 | `format_percentage/case_%` — repeater, 7 cases | half-up rounding, negatives, `2.556`→`256%` | `actions_test.rb#the zoom label tracks the scale` pins 1.5→150% **only** | gap | The zoom label rounds half-away-from-zero and handles negative scales |
| 26 | `text_as_variant` | the copy action's target carries exactly the buffer text | — | gap | The copy button copies the message currently on screen |
| 27 | `text_non_empty` | empty text drives the error-message group's visibility | — | gap | The error dialog hides its message box when there is no message |
| 28 | `decoration_layout_is_inverted/case_%` — repeater, 9 cases | tab bar inverts only when window buttons sit left | — | gap | The tab bar sits on the side the user's button layout implies |
| 29 | `status_as_icon/<flags>` — repeater, 5 cases | remote > playbox > privileged; plain session gets no badge | — | gap | A remote+root tab is badged **remote**; a plain tab not at all |
| 30 | `ringing_as_icon` | a ringing tab gets the bell icon, a quiet one none | — | gap | A tab that rang while you were away shows an attention mark |

**2 ported · 28 gaps**

---

## Suite: templated, spad-source, depot, despatcher — `test-templated.c`, `test-spad-source.c`, `test-depot.c`, `test-despatcher.c` (14)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 31 | `/kgx/spad-source/throw` | throwing emits one signal carrying title/flags/body/content | `actions_test.rb#a toast with details reaches the spad` | **ported** | — |
| 32 | `/kgx/spad-source/throw/unhandled/case_1` | an unhandled error aborts loudly rather than vanishing | — | gap | An error raised with nowhere to display it is never silently swallowed |
| 33 | `/kgx/spad-source/throw/unhandled/case_2` | same, with error content — content does not make it survivable | — | gap | An error with a full body is still surfaced when no dialog is attached |
| 34 | `/kgx/spad-source/new-destroy` | the interface is recognised and finalises cleanly | — | gap | Closing a tab that showed an error frees it |
| 35 | `/kgx/depot/spawn` | an async spawn completes with a train and no error | `integration_test.rb#the shell spawned and has a train` | **ported** | — |
| 36 | `/kgx/depot/get-set` | the depot returns the watcher it was given and always has proxy-info | — | gap | A new tab inherits the app's watcher and proxy settings, so status flags and proxy env are right from the first command |
| 37 | `/kgx/depot/new-destroy` | a depot finalises with no references left | — | gap | Opening and closing tabs repeatedly does not leak spawn machinery |
| 38 | `/kgx/despatcher/new-destroy` | the `OpenURI` portal wrapper constructs and finalises | — | gap | Clicking a link opens the browser, and closing the window leaves nothing running |
| 39 | `/kgx/templated/base/new-destroy` | a templated object builds and finalises with no leftover refs | — | gap | A window opens and closes without leaking its widget tree |
| 40 | `/kgx/templated/base/properties` | template-declared defaults apply on construction | — | gap | Widget defaults declared once are in effect when a window first appears |
| 41 | `/kgx/templated/also/new-destroy` | a subclass disposes both its own and its parent's template | — | gap | Closing a derived dialog frees it completely |
| 42 | `/kgx/templated/also/properties` | a subclass overrides an inherited default and adds its own | — | gap | A derived dialog's own defaults override inherited ones |
| 43 | `/kgx/templated/also/multi-dispose` | disposing twice does not double-free | — | gap | Closing a dialog twice in quick succession does not crash |
| 44 | `/kgx/templated/apply` | applying a template to a live object overwrites its values | — | gap | Re-applying settings to a built widget takes effect |

**2 ported · 12 gaps**

---

## Suite: widgets and behaviour (44)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 1 | `/kgx/window/new-destroy` | a window constructs, presents and tears down cleanly | `integration_test.rb#a window was created` | **ported** | — |
| 2 | `/kgx/window/settings/direct` | `settings` is construct-assignable and notifies on reassign | — | gap | A window built with the app's settings uses them rather than silently defaulting |
| 3 | `/kgx/window/search-mode` | `win.find` toggles search mode both ways | `actions_test.rb#win.find opens the search bar` + `…closes the search bar again` | **ported** | — |
| 4 | `/kgx/window/floating` | `floating` is true until maximised — the signal the transparency rule reads | — | gap | An unmaximised window is treated as floating, which is what lets the background go see-through |
| 5 | `/kgx/window/translucent/direct` | the class is added only when the property is set, not merely notified | — | gap | Turning transparency on makes the background see-through |
| 6 | `/kgx/window/translucent/derived` | transparency AND floating; maximise drops it, restore returns it, no spurious notify | — | gap | A see-through window turns solid when maximised and see-through again when restored |
| 7 | `/kgx/window/realize-unrealize` | a realize/unrealize cycle does not crash | — | gap | A window can be shown and hidden without taking the app down |
| 8 | `/kgx/window/trigger-breakpoints/empty` | crossing 400px on an empty window switches layout | — | gap | A narrow window shows the compact layout, a wide one the desktop tab bar |
| 9 | `/kgx/window/trigger-breakpoints/with-tab` | same crossing with a tab loaded (historically crashed) | — | gap | Resizing a window with a terminal open across the boundary does not crash |
| 10 | `/kgx/window/add_tab` | title is the display name until a tab has one, then follows the newest titled tab | — | gap | The window title shows the current tab's title, falling back to "Console" |
| 11 | `/kgx/window/ringing` | `bell` class appears only when `visual-bell` is on, and is removed when ringing ends | `actions_test.rb#the bell flashes the window` pins only that the class appears | gap | The bell class appears **only** when `visual-bell` is enabled, and clears itself afterwards |
| 12 | `/kgx/window/status` | status maps to `root`/`remote`/`playbox`, including remote+privileged | `actions_test.rb#a privileged status adds the root style class` pins `privileged` only | gap | `remote` and `playbox` classes, and the remote+privileged combination, reach the window |
| 13 | `/kgx/window/get_working_dir` | null with no tabs, else the most recently added tab's path | — | gap | A new tab opens in the directory of the tab you opened it from |
| 14 | `/kgx/spad/new-destroy` | the error dialog constructs and finalises | `actions_test.rb#the error details dialog builds and presents` | **ported** | — |
| 15 | `/kgx/spad/get-set` | flags, body and content read back unchanged | `actions_test.rb#the error message includes the system info when asked` | **ported** | — |
| 16 | `/kgx/spad/build_bundle` | an error carried up keeps title/flags/body/content, no error block when none | — | gap | An error raised while a tab starts reaches the dialog with title, explanation and raw text intact |
| 17 | `/kgx/spad/build_bundle/with_error` | a `GError`'s domain, code and message survive the trip | — | gap | When a spawn fails, the underlying system error reaches what the user can copy |
| 18 | `/kgx/spad/new_from_bundle` | a dialog built from a carried error shows exactly those fields | — | gap | The dialog displays the title, explanation and raw text it was handed |
| 19 | `/kgx/spad/new_from_bundle/no_title` | a missing or whitespace-only title falls back to "Error Details" | — | gap | An untitled error still opens a dialog headed "Error Details" |
| 20 | `/kgx/spad/new_from_bundle/with_error` | the error is appended as `domain (code):\nmessage` | — | gap | The copyable report ends with the system error's name, code and message |
| 21 | `/kgx/train/new-destroy` | a train constructs and finalises | `integration_test.rb#the shell spawned and has a train` | **ported** | — |
| 22 | `/kgx/train/init` | async init preserves the pid and tag | `integration_test.rb#the train knows its pid` | **ported** | — |
| 23 | `/kgx/train/props` | pid/tag/uuid readable, uuid valid, initial status none | — | gap | Each open shell has a stable id and starts with no root/remote/container badge |
| 24 | `/kgx/train/children` | add emits once, re-add emits nothing, remove emits once, re-remove nothing | `integration_test.rb#the train sees its own shell process` pins population only | gap | Re-adding the same child is a no-op and removal fires exactly once |
| 25 | `/kgx/train/died` | `pid-died` fires on real child exit with a clean wait status | — | gap | When the shell actually exits, the tab notices and closes |
| 26 | `/kgx/livery/type` | `KgxLivery` is a boxed value type | — | gap | A colour scheme can be passed around and stored as a value without losing its contents |
| 27 | `/kgx/livery/new` | builds from uuid/name/palettes with correct lifetime | `actions_test.rb#a custom livery persists and can be selected` | **ported** | — |
| 28 | `/kgx/livery/roundtrip` | serialise→deserialise keeps uuid, name, count and every channel | `actions_test.rb#a livery round-trips through its stored form` | **ported** | — |
| 29 | `/kgx/livery/set_palette` | assigning a different livery replaces it and reports the change | — | gap | Picking a different colour scheme repaints the open terminals |
| 30 | `/kgx/livery/set_palette_same` | assigning the identical palette reports no change | — | gap | Re-selecting the current scheme changes nothing on screen |
| 31 | `/kgx/tab/new-destroy` | a tab constructs against an application and finalises | `integration_test.rb#the tab has a terminal` | **ported** | — |
| 32 | `/kgx/tab/working` | a counter: notifies only on 0→1 and 1→0, drives `GApplication` busy | — | gap | While a command runs the app marks itself busy, and stops when the last one ends |
| 33 | `/kgx/tab/bell` | `ringing` goes true and clears itself within 500ms | — | gap | A bell flashes the tab and the flash stops by itself |
| 34 | `/kgx/tab/initial-title` | initial title/path visible as `initial-*` only, expiring after 200ms | — | gap | A new tab shows its requested title/directory, then hands over to the shell |
| 35 | `/kgx/empty/new-destroy` | the placeholder constructs and finalises | — | gap | A window with no output yet shows the placeholder page |
| 36 | `/kgx/empty/map-unmap` | the logo becomes visible on map, spinner stays hidden | — | gap | The logo fades in on the empty page when a window opens |
| 37 | `/kgx/empty/working` | `working` hides the logo then shows the spinner; clearing hides both | — | gap | While a shell starts the user sees a spinner, which disappears once it is up |
| 38 | `/kgx/empty/working-unmap` | a working placeholder survives unmap/remap | — | gap | Switching away from and back to a starting tab leaves no stuck spinner |
| 39 | `/kgx/theme-switcher/new-destroy` | the switcher constructs and finalises | `actions_test.rb#the theme switcher builds` | **ported** | — |
| 40 | `/kgx/theme-switcher/get-set` | `theme` round-trips an 8-step night/day/auto sequence | `actions_test.rb#the theme action switches to day` + `…back to night` + `an auto theme follows the system` | **ported** | — |
| 41 | `/kgx/pages/new-destroy` | the pages container constructs and finalises | `integration_test.rb#the window has one tab` | **ported** | — |
| 42 | `/kgx/pages/initial-state` | fresh container: 0 pages, empty children, no status, not ringing, no selection | — | gap | A window with no tabs shows the plain app title, no badge and no bell |
| 43 | `/kgx/remote/is_remote/case_%` — repeater, 10 cases | ssh/telnet/mosh/et remote; kgx and bare waypipe not; `waypipe ssh` yes, `waypipe kgx` no | — | gap | A shell running ssh/telnet/mosh — including through waypipe — is badged remote, a local one is not |
| 44 | `/kgx/playbox/is_playbox/case_%` — repeater, 7 cases | `toolbox enter` yes; `toolbox list` and bare `toolbox` no; `sh …/distrobox enter` yes | — | gap | A shell *inside* a container is badged as one; running `toolbox list` from a normal shell is not |

**12 ported · 32 gaps**

---

## Suite: pure logic (60)

**9 ported · 51 gaps.** Ported outright: `/kgx/settings/new-destroy`,
`font-scale/get-set`, `font-scale/reset`, `settings/livery`, `palette/new`,
`palette/serialise`, `palette/deserialise`, `utils/filter_arguments/missing`,
`system-info/new-destroy`.

Thirteen further port tests pin part of their counterpart and are gaps here:
font-scale increase/decrease (direction, no clamp, no `scale_can_*`), font
resolution against the system setting, geometry persistence gating, custom-shell
override, theme resolution (3 of 8 cases — the `hacker` alias untested),
audible-bell write-back, flow-control setting→pty wiring, URI locality (2 of 6),
palette transparency/colours/set (one field each), and colour parsing (no length
rejection — the port accepts 3-digit hex upstream refuses).

| Block | Tests | What is owed |
|---|---:|---|
| `proxy-info/apply/*` | 8 | Variable names and both case variants, `http://` even for https and ftp, `socks://` for socks, credentials **only** when `use-authentication` is on, `no_proxy` comma-joining, and a re-read on every apply. The one port test is vacuous |
| `utils/filter_argument*` | 2 (20 runtime cases) | When `-e`/`--command=` is wrapped in `/bin/sh -c`, when a bare binary resolves to an absolute path, and that `--command=` plus `--` is a hard error |
| `utils/set_*_prop` | 5 | An identical write emits no change notification — five upstream tests, zero coverage |
| `settings/font/*`, `custom-font`, `use-system-font` | 5 | System font by default, custom when opted in, system again when the custom string is empty, one notify per real switch |
| `settings/scrollback/*` | 2 (13 runtime cases) | An int64 limit clamped into int range, negatives becoming −1, the stored limit surviving while unlimited is on |
| `utils/str_*` | 3 (8 runtime cases) | Bounded titles ending in `…` only when truncated, and whitespace-only counting as empty |
| `utils/parse_percentage` | 1 (13 runtime cases) | Locale decimal commas, Arabic-Indic digits, rejection of malformed input |
| `palette/serialise_validate` | 1 | Channels compared against literals — the MR !193 regression a symmetric round-trip provably cannot see |
| `palette/opaque`, `set_palette_same` | 2 | `as_opaque` returning the same object when already opaque; re-selecting the current livery repainting nothing |
| `colour-utils/{error_quark,to_string}` | 2 | A named error domain for bad colours, and upper-case six-digit hex |
| `settings/{visual-bell,transparency,always-stop-train}`, `size` | 4 | Each preference surviving a restart; `always-stop-train` notifying only on real change |
| `system-info/monospace-font`, `locale/init` | 2 | A desktop font change re-fonting open terminals live; the process locale actually set |
| Remainder | 14 | Recorded row by row in the working notes |

---

## How this ledger was produced

```sh
REPO=$(basename -s .git "$(git remote get-url origin)")
UP=$(gh api "repos/ruby-gtk-project/$REPO" --jq '.parent.default_branch')
git worktree add --detach ../upstream "origin/$UP"
git worktree add --detach ../port     origin/ruby
test-census.sh ../upstream > upstream-tests.tsv   # 148
test-census.sh ../port     > port-tests.tsv       # 97
```

`ruby` is an orphan branch, so the upstream sha is recorded here rather than
derived. Re-run against `599b703` to compare like with like.

Three census findings worth keeping:

- Upstream registers 20 cases through its own `fixtured_test()` wrapper and three files build every name in a loop, so a naive census reported 115 and three test binaries showed zero. The build-file cross-check caught it.
- The port's 97 tests are **not** 97 units of parity. `actions_test.rb` names its cases on `step`, not `check`; censusing the wrong call gives 1.
- One bijection violation was caught and resolved: `actions_test.rb#a toast with details reaches the spad` was claimed by both `/kgx/spad-source/throw` and `/kgx/spad/new_from_bundle`. A port test may be named by exactly one upstream test, so the second is a gap.
