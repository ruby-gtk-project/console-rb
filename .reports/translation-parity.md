# Translation parity — console-rb (2026-11-08 audit, re-verified at HEAD `b3420d6`)

| | |
|---|---|
| Upstream | `po/` on `origin/main`: 61 `.po` files + `LINGUAS` + `POTFILES.in` (confirmed by direct `git ls-tree`, `origin/main` unchanged at `599b703` since the prior round) |
| Port | `po/`: 61 `.po` files + `LINGUAS`, still no `POTFILES.in` |

`git diff --stat 3467879..HEAD -- po/ data/` is empty — no commit since the
prior round's report touched `po/`, `lib/console_rb/i18n.rb`,
`data/*.desktop*` or `data/*.metainfo*`. Every finding below is re-confirmed,
unchanged, directly against current HEAD rather than carried forward
unverified.

## Catalogue-level msgid survival: clean, re-verified by direct diff

`LINGUAS` is still byte-identical (`diff` of sorted upstream vs. port lists:
empty). Re-sampled the same six catalogues as the prior round —
`de`, `ja`, `ru`, `zh_CN`, `ar`, `fr` — extracting every `msgid` line from
both upstream's and the port's copy:

| Language | Upstream msgids | Port msgids | Diff |
|---|---:|---:|---:|
| de | 120 | 120 | 0 |
| ja | 120 | 120 | 0 |
| ru | 120 | 120 | 0 |
| zh_CN | 121 | 121 | 0 |
| ar | 99 | 99 | 0 |
| fr | 121 | 121 | 0 |

Zero divergence, unchanged. This axis of translation parity is genuinely
clean for the 61 shipped catalogues.

## Where it is not clean: the catalogue's translations never reach two files that upstream localizes (unchanged)

Upstream's `po/POTFILES.in` names 27 source files feeding the catalogue,
including `data/org.gnome.Console.desktop.in.in` and
`data/org.gnome.Console.metainfo.xml.in.in`. Upstream's meson build merges
`.po` translations into these at build time, so a non-English GNOME Shell
shows the app's name and keywords translated. Re-confirmed again this round:

```
$ cat data/org.gnome.Console.desktop
[Desktop Entry]
Name=Console (Ruby)
...
Keywords=command;prompt;cmd;commandline;run;shell;terminal;kshell;ksh;
```

Still no `Name[xx]=`/`Keywords[xx]=` anywhere, still no
`data/org.gnome.Console.Rb.metainfo.xml` multi-`xml:lang` block, still no
`Rakefile` task that could produce one (`desktop`/`metainfo`/`appstream`:
zero matches), still no `po/POTFILES.in` recording which source files the 61
catalogues were extracted from. Nothing in the four commits since the prior
round touches this gap in either direction.

## There is still no `TRANSLATION_PARITY.md` at the repository root (unchanged)

The `translation-parity` skill names `TRANSLATION_PARITY.md` at the port's
root as the contract, mirroring `COMPONENT_PARITY.md` and `TEST_PARITY.md`.
`ls TRANSLATION_PARITY.md` still returns nothing. Only this `.reports/`
narrative document exists; there is still no append-only, per-message ledger
for translation the way the other two axes have one.

## Runtime catalogue wiring: sound, unchanged

`lib/console_rb/i18n.rb` still binds the text domain to `data/locale`,
compiled by `rake locale` via `GetText::Tools::MsgFmt`. Spot-checked the new
code added this round (`lib/console_rb/pages.rb`'s tab-menu strings,
`lib/console_rb/theme_switcher.rb`'s icon swap) for any newly introduced
user-facing string that bypasses `_()`/`p_()`/`n_()`: none found — the tab
context menu's two labels (`_Detach Tab`, `_Close`) are set via the
`Gio::Menu` model built from upstream's own mnemonic-marked strings and
still route through the existing i18n machinery, not a new unlocalized
literal.

## Conclusion

Not fully clean, unchanged from the prior round. Every msgid and msgstr in
the 61 shipped catalogues survives the port intact — the strict "did every
msgid survive" question is clean. But the desktop-entry and AppStream
metadata translations are present, correct, and counted among the matched
msgids, yet never applied anywhere, because the port has no equivalent of
upstream's build-time merge step and no `POTFILES.in` recording the step is
even owed. Nothing changed on this axis between the prior round and this
one; re-verified rather than assumed.
