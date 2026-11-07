# console-rb component inventory

Surveyed against upstream GNOME Console (`kgx`) at `origin/main`. This is an
inventory, not a parity audit — it says what exists and where it should live,
not whether each existing file reproduces every widget/CSS class/signal from
its upstream source. That comparison is `component-parity`'s job, run after
this.

Upstream totals: 70 files under `src/`, 7 under `data/`, 61 `po/*.po`
catalogues, 23 test files under `tests/`.

## Already ported (upstream file → `lib/console_rb/*.rb`)

| Upstream | `lib/` | Kind | Present |
|---|---|---|---|
| `src/kgx-application.c/.h` | `application.rb` | application class (actions, accelerators, app-menu) | yes |
| `src/main.c` | `launcher.rb` | entry point | yes |
| `src/kgx-window.c/.h/.ui` | `window.rb` | window | yes |
| `src/kgx-pages.c/.h/.ui`, `src/kgx-page-expression.ui` | `pages.rb` | tab view/page-switcher widget | yes |
| `src/kgx-tab.c/.h/.ui` | `tab.rb` | tab base class | yes |
| `src/kgx-simple-tab.c/.h/.ui` | `simple_tab.rb` | tab subclass | yes |
| `src/kgx-terminal.c/.h/.ui` | `terminal.rb` | terminal widget (VTE wrapper) | yes |
| `src/kgx-empty.c/.h/.ui` | `empty.rb` | empty state (logo/spinner) | yes |
| `src/kgx-fullscreen-box.c/.h/.ui` | `fullscreen_box.rb` | fullscreen header reveal widget | yes |
| `src/kgx-about.c/.h` | `about_dialog.rb` | about dialog + `--version`/`--about` output | yes |
| `src/kgx-close-dialog.c/.h` | `close_dialog.rb` | confirm-close dialog | yes |
| `src/kgx-paste-dialog.c/.h` | `paste_dialog.rb` | paste-confirmation dialog | yes |
| `src/kgx-spad.c/.h/.ui` | `spad.rb` | error-details dialog | yes |
| `src/kgx-spad-source.c/.h` | `spad_source.rb` | GLib source backing spad | yes |
| `src/preferences/kgx-preferences-window.c/.h/.ui` | `preferences_dialog.rb` | preferences window | yes |
| `src/preferences/kgx-font-picker.c/.h/.ui` | `font_picker.rb` | font-picker widget | yes |
| `src/kgx-theme-switcher.c/.h/.ui` | `theme_switcher.rb` | light/system/dark selector | yes |
| `src/shortcuts-dialog.ui` | `shortcuts_dialog.rb` | keyboard shortcuts window | yes |
| `src/kgx-drop-target.c/.h` | `drop_target.rb` | drag-and-drop controller | yes |
| `src/kgx-depot.c/.h` | `depot.rb` | shell/environment lookup | yes |
| `src/kgx-despatcher.c/.h` | `despatcher.rb` | FileManager1 D-Bus bridge | yes |
| `src/kgx-watcher.c/.h` | `watcher.rb` | child-process exit watcher | yes |
| `src/kgx-train.c/.h` | `train.rb` | foreground-process tracking | yes |
| `src/pids/kgx-pids.c/.h`, `src/pids/kgx-gtop.c/.h` | `process_info.rb` | process snapshot — reads `/proc` directly; see Finding below | yes |
| `src/kgx-system-info.c/.h` | `system_info.rb` | OS/version banner text | yes |
| `src/kgx-proxy-info.c/.h` | `proxy_info.rb` | desktop proxy → env vars | yes |
| `src/kgx-palette.c/.h` | `palette.rb` | 16-colour terminal palette | yes |
| `src/kgx-livery.c/.h` | `livery.rb` | built-in theme/livery definitions | yes |
| `src/kgx-livery-manager.c/.h` | `livery_manager.rb` | livery persistence/lookup | yes |
| `src/kgx-colour-utils.c/.h` | folded into `palette.rb`/`livery.rb` | colour-space helpers | yes (merged, not standalone) |
| `src/kgx-settings.c/.h/.ui.in`, `data/org.gnome.Console.gschema.xml.in` | `settings.rb`, `data/schemas/org.gnome.Console.Rb.gschema.xml` | GSettings wrapper + schema | yes |
| `src/main.c` (arg parsing) | `cli.rb` | command-line parsing | yes |
| (no single upstream file — Ruby-only glue) | `i18n.rb` | gettext lookup sharing upstream's catalogue | yes |
| (no single upstream file — Ruby-only glue) | `regex.rb` | VTE regex construction workaround | yes |
| (no single upstream file — Ruby-only glue) | `termios.rb` | PTY IXON/IXOFF clearing workaround | yes |
| (no single upstream file — Ruby-only glue) | `shortcuts.rb` | accelerator → `Gtk::ShortcutTrigger` builder | yes |
| (no single upstream file) | `version.rb` | gem version + app id/schema id (renamed to `org.gnome.Console.Rb`, see Finding) | yes |

## Upstream files with no component counterpart needed

These are build/plumbing files whose job the Ruby side does not need a
separate file for, or whose content is already folded into a ported file
above — not a parity gap:

| Upstream | Why no separate `lib/` file |
|---|---|
| `src/kgx-templated.c/.h` | GtkBuilder template-loading base class with no screen behaviour of its own; the Ruby house style builds widgets declaratively with memoized methods instead of loading `.ui` templates, so the construct it supports does not exist on this side |
| `src/kgx-marshals.list` | generated GLib signal-marshaller code, not behaviour — it exists so C can call a handler with the right argument types |
| `src/kgx-file-closures.h`, `src/kgx-icon-closures.h`, `src/kgx-shared-closures.h` | GTask/GClosure type-safety headers for C callbacks, not behaviour — Ruby's dynamic dispatch does not need a generated-closure-struct equivalent for this specific plumbing |
| `src/kgx-git-tag.h.in` | Meson build-time version stamp; equivalent is `version.rb`'s `VERSION` constant |
| `src/kgx-utils.c/.h` | small C string/array helpers; behaviour is inlined at each Ruby call site rather than centralised (worth confirming at parity-review time that none were dropped, not just inlined) |
| `src/kgx-playbox.h`, `src/kgx-remote.h` | header-only interfaces (no `.c`); their behaviour is implemented directly in `pages.rb`/`window.rb`/`train.rb`/`process_info.rb`/`drop_target.rb`/`tab.rb` |
| `src/rgba.h` | RGBA struct macros; folded into `palette.rb` |
| `src/org.freedesktop.FileManager1.xml` | D-Bus interface introspection XML; `despatcher.rb` talks to the interface directly by name/path without needing the XML at runtime |
| `src/logo.txt` | ASCII-art logo; inlined as the `LOGO` constant in `about_dialog.rb` |
| `src/style.css` | present at `data/style.css` |
| `data/org.gnome.Console.desktop.in.in` | present at `data/org.gnome.Console.desktop` |
| `data/org.gnome.Console.metainfo.xml.in.in` | present at `data/org.gnome.Console.Rb.metainfo.xml` |
| `data/org.gnome.Console.service.in` | present at `data/org.gnome.Console.Rb.service` |
| `data/org.gnome.Console.gschema.xml.in` | present at `data/schemas/org.gnome.Console.Rb.gschema.xml` |
| `data/org.gnome.Console*.svg` (app icon, symbolic icon) | present under `data/icons/hicolor/...` |
| `src/icons/scalable/status/*.svg` | present under `data/icons/hicolor/scalable/status/` |
| `po/*.po` (61 catalogues) | present as compiled `.mo` under `data/locale/<lang>/LC_MESSAGES/console-rb.mo`, same 61 languages |
| `tests/*` (23 files) | test-suite parity is `test-parity`'s job, not this inventory's |

## Findings for the accountability pass

- **`process_info.rb` cannot use the `GTop` gem.** Per the fleet-wide finding,
  `libgtop`'s records are lowercase and ruby-gnome resolves argument types by
  the raw GI name, so every `GTop` call raises `NameError`. `process_info.rb`
  reads `/proc` directly instead and says so in its header comment — this is
  the documented, not hidden, workaround; confirmed by inspection, not newly
  found here.
- **App ID and schema deliberately differ from upstream** (`org.gnome.Console.Rb`
  vs `org.gnome.Console`). `version.rb` states this is so the port installs
  side by side with the real app rather than fighting over dconf keys — a
  reasonable packaging choice, not a parity gap, but flagged here since it
  means the `.desktop`/`.service`/`.metainfo`/gschema IDs all differ from
  upstream's by name even though their content otherwise matches.
- **`src/kgx-utils.c/.h` has no single Ruby counterpart to point to** — its
  helpers appear inlined at call sites across the port. This inventory did
  not verify each one was actually carried over; that check belongs to
  `component-parity`, not here.

## Scope not covered by this inventory

This is a file-level existence survey, not a widget/CSS/signal parity audit.
For each file marked "yes" above, `component-parity` still needs to confirm
the widget tree, CSS classes, signals and actions inside it match upstream's
`.c`/`.ui` pair line for line — a file existing is necessary, not sufficient.
