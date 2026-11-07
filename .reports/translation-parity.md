# Translation parity — console-rb (2026-11-07 audit)

| | |
|---|---|
| Upstream | `po/` on `origin/main`: 61 `.po` files + `LINGUAS` + `POTFILES.in` (confirmed by direct `git ls-tree`) |
| Port | `po/`: 61 `.po` files + `LINGUAS`, no `POTFILES.in` |

## Catalogue-level msgid survival: clean, verified by direct diff

`LINGUAS` is byte-identical (`diff` of sorted upstream vs. port lists: empty).
Sampled six catalogues spanning different plural rules and scripts —
`de`, `ja`, `ru`, `zh_CN`, `ar` — by extracting every `msgid` line from both
upstream's and the port's copy and diffing the sorted sets:

| Language | Upstream msgids | Port msgids | Diff |
|---|---:|---:|---:|
| de | 120 | 120 | 0 |
| ja | 120 | 120 | 0 |
| ru | 120 | 120 | 0 |
| zh_CN | 121 | 121 | 0 |
| ar | 99 | 99 | 0 |
| fr (spot-checked earlier in this audit) | 121 | 121 | 0 |

Zero divergence in every sample. Spot-checked one full entry
(`msgid "Find in Terminal"` / `msgstr "Im Terminal suchen"` in `de.po`) and it
is byte-identical between upstream and port, `msgstr` included — the port is
not just preserving the msgid list, the actual human translation text carries
over unchanged. This axis of translation parity is genuinely clean for the 61
shipped catalogues.

## Where it is not clean: the catalogue's translations never reach two files that upstream localizes

Upstream's `po/POTFILES.in` (read directly from `origin/main`) names 27 source
files whose translatable strings feed the catalogue, including:

```
data/org.gnome.Console.desktop.in.in
data/org.gnome.Console.metainfo.xml.in.in
```

Upstream's meson build merges the `.po` translations into these two files at
build time (the `.in.in` naming is the `intltool`/`msgfmt --desktop` /
`itstool` convention — a second `.in` strip happens after translation
merging), producing a real, installed `.desktop` file with
`Name[de]=Konsole`-style per-language keys and a metainfo file with
`<name xml:lang="de">`-style blocks, so a French or Japanese GNOME Shell shows
the app's name, generic name and search keywords in the user's own language.

The port ships **plain, single-language files with no per-language keys at
all**:

```
$ cat data/org.gnome.Console.desktop
[Desktop Entry]
Name=Console (Ruby)
...
Keywords=command;prompt;cmd;commandline;run;shell;terminal;kshell;ksh;
```

No `Name[xx]=`, no `Keywords[xx]=`, anywhere. Confirmed by reading the whole
file — it is static English with no translation markers of any kind.
`data/org.gnome.Console.Rb.metainfo.xml` is the same: a plain, single-language
XML file, not the multi-`xml:lang` block upstream ships.

There is also **no build step that could produce one**: `Rakefile` has no
`desktop`, `metainfo` or `appstream` task (confirmed by grep — zero matches),
and the port has no `po/POTFILES.in` at all, so there is no record even of
*which* source files the 61 catalogues were extracted from, let alone a
pipeline that merges them back into the desktop/metainfo files.

**The practical consequence:** the catalogue strings for these two files exist
in all 61 `.po` files and are byte-identical to upstream's translations (they
are included in the matched msgid sets above — desktop/metainfo strings are
part of the same catalogue, not a separate one) — but every one of those
translations is dead weight. They are shipped, correct, and never read by
anything, because nothing in this port merges them into the files a desktop
environment actually displays. A French user who has never run the app yet
sees "Console (Ruby)" in GNOME's app grid, in English, with no keyword match
on the French search terms upstream ships translated — identical to running
with zero translation work done, for this one surface.

## Runtime catalogue wiring: sound

`lib/console_rb/i18n.rb` binds the text domain to `data/locale`, compiled by
`rake locale` via `GetText::Tools::MsgFmt` (not system `msgfmt`, specifically
to avoid a `.mo` format-revision mismatch the `gettext` gem's own reader
rejects for `ar`/`fa` — a real, documented workaround, not a shortcut). Spot
checks of in-code `_()` call sites (`window.rb`) against the catalogue confirm
the Ruby source's translation markers match the catalogue's msgids exactly
for ordinary UI strings. This half of translation parity is sound.

## Conclusion

Not fully clean. **Every msgid and every msgstr in the 61 shipped `.po`
catalogues survives the port intact** — the strict "did every msgid survive"
question has a clean answer for the strings the Ruby code actually displays
through `_()`/`p_()`/`n_()`. But the catalogue is only half of what "every
translated string reaches the user" means: the desktop-entry and AppStream
metadata translations — present, correct, and counted among the matched
msgids above — are never applied anywhere, because the port has no equivalent
of upstream's build-time merge step and no `POTFILES.in` recording that the
step is even owed.
