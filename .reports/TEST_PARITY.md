# Test parity — console

| | |
|---|---|
| Upstream | `main` @ `599b703` |
| Port | `ruby` @ `37d42da` |
| Upstream tests | 148 |
| Ported | 0 |
| Gaps | 148 |
| Test command | `rake test` |

The port assertion unit is the named `step` in `test/actions_test.rb` and the named `check` in `test/integration_test.rb`; the rescue-path `check` in `actions_test.rb` is harness bookkeeping, not a case.

## Suite: colour-utils (3 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 1 | `tests/test-colour-utils.c#/kgx/colour-utils/error_quark@75` | A person can rely on the app to kgx colour utils error quark. | — | **gap** | A person can rely on the app to kgx colour utils error quark. |
| 2 | `tests/test-colour-utils.c#/kgx/colour-utils/from_string@77` | A person can rely on the app to kgx colour utils from string. | — | **gap** | A person can rely on the app to kgx colour utils from string. |
| 3 | `tests/test-colour-utils.c#/kgx/colour-utils/to_string@76` | A person can rely on the app to kgx colour utils to string. | — | **gap** | A person can rely on the app to kgx colour utils to string. |

## Suite: depot (3 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 4 | `tests/test-depot.c#/kgx/depot/get-set@174` | A person can rely on the app to kgx depot get set. | — | **gap** | A person can rely on the app to kgx depot get set. |
| 5 | `tests/test-depot.c#/kgx/depot/new-destroy@173` | A person can rely on the app to kgx depot new destroy. | — | **gap** | A person can rely on the app to kgx depot new destroy. |
| 6 | `tests/test-depot.c#/kgx/depot/spawn@175` | A person can rely on the app to kgx depot spawn. | — | **gap** | A person can rely on the app to kgx depot spawn. |

## Suite: despatcher (1 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 7 | `tests/test-despatcher.c#/kgx/despatcher/new-destroy@42` | A person can rely on the app to kgx despatcher new destroy. | — | **gap** | A person can rely on the app to kgx despatcher new destroy. |

## Suite: empty (4 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 8 | `tests/test-empty.c#/kgx/empty/map-unmap@252` | A person can rely on the app to kgx empty map unmap. | — | **gap** | A person can rely on the app to kgx empty map unmap. |
| 9 | `tests/test-empty.c#/kgx/empty/new-destroy@251` | A person can rely on the app to kgx empty new destroy. | — | **gap** | A person can rely on the app to kgx empty new destroy. |
| 10 | `tests/test-empty.c#/kgx/empty/working@253` | A person can rely on the app to kgx empty working. | — | **gap** | A person can rely on the app to kgx empty working. |
| 11 | `tests/test-empty.c#/kgx/empty/working-unmap@254` | A person can rely on the app to kgx empty working unmap. | — | **gap** | A person can rely on the app to kgx empty working unmap. |

## Suite: file-closures (17 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 12 | `tests/test-file-closures.c#/kgx/file-closures/file_as_display/no_path@234` | A person can rely on the app to kgx file closures file as display no path. | — | **gap** | A person can rely on the app to kgx file closures file as display no path. |
| 13 | `tests/test-file-closures.c#/kgx/file-closures/file_as_display/non_utf8@233` | A person can rely on the app to kgx file closures file as display non utf8. | — | **gap** | A person can rely on the app to kgx file closures file as display non utf8. |
| 14 | `tests/test-file-closures.c#/kgx/file-closures/file_as_display/null_when_null@231` | A person can rely on the app to kgx file closures file as display null when null. | — | **gap** | A person can rely on the app to kgx file closures file as display null when null. |
| 15 | `tests/test-file-closures.c#/kgx/file-closures/file_as_display/utf8@232` | A person can rely on the app to kgx file closures file as display utf8. | — | **gap** | A person can rely on the app to kgx file closures file as display utf8. |
| 16 | `tests/test-file-closures.c#/kgx/file-closures/file_as_display_or_uri/no_path@239` | A person can rely on the app to kgx file closures file as display or uri no path. | — | **gap** | A person can rely on the app to kgx file closures file as display or uri no path. |
| 17 | `tests/test-file-closures.c#/kgx/file-closures/file_as_display_or_uri/non_utf8@238` | A person can rely on the app to kgx file closures file as display or uri non utf8. | — | **gap** | A person can rely on the app to kgx file closures file as display or uri non utf8. |
| 18 | `tests/test-file-closures.c#/kgx/file-closures/file_as_display_or_uri/null_when_null@236` | A person can rely on the app to kgx file closures file as display or uri null when null. | — | **gap** | A person can rely on the app to kgx file closures file as display or uri null when null. |
| 19 | `tests/test-file-closures.c#/kgx/file-closures/file_as_display_or_uri/utf8@237` | A person can rely on the app to kgx file closures file as display or uri utf8. | — | **gap** | A person can rely on the app to kgx file closures file as display or uri utf8. |
| 20 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/in_home@229` | A person can rely on the app to kgx file closures file as subtitle in home. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle in home. |
| 21 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/is_home@228` | A person can rely on the app to kgx file closures file as subtitle is home. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle is home. |
| 22 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/no_path@222` | A person can rely on the app to kgx file closures file as subtitle no path. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle no path. |
| 23 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/non_utf8@224` | A person can rely on the app to kgx file closures file as subtitle non utf8. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle non utf8. |
| 24 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/non_utf8_in_home@225` | A person can rely on the app to kgx file closures file as subtitle non utf8 in home. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle non utf8 in home. |
| 25 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/null_when_null@221` | A person can rely on the app to kgx file closures file as subtitle null when null. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle null when null. |
| 26 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/outside_home@226` | A person can rely on the app to kgx file closures file as subtitle outside home. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle outside home. |
| 27 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/outside_home_prefix@227` | A person can rely on the app to kgx file closures file as subtitle outside home prefix. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle outside home prefix. |
| 28 | `tests/test-file-closures.c#/kgx/file-closures/file_as_subtitle/raw_matches_title@223` | A person can rely on the app to kgx file closures file as subtitle raw matches title. | — | **gap** | A person can rely on the app to kgx file closures file as subtitle raw matches title. |

## Suite: icon-closures (2 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 29 | `tests/test-icon-closures.c#/kgx/icon-closures/ringing_as_icon@82` | A person can rely on the app to kgx icon closures ringing as icon. | — | **gap** | A person can rely on the app to kgx icon closures ringing as icon. |
| 30 | `tests/test-icon-closures.c#/kgx/icon-closures/status_as_icon/@78` | A person can rely on the app to kgx icon closures status as icon. | — | **gap** | A person can rely on the app to kgx icon closures status as icon. |

## Suite: livery (5 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 31 | `tests/test-livery.c#/kgx/livery/new@148` | A person can rely on the app to kgx livery new. | — | **gap** | A person can rely on the app to kgx livery new. |
| 32 | `tests/test-livery.c#/kgx/livery/roundtrip@149` | A person can rely on the app to kgx livery roundtrip. | — | **gap** | A person can rely on the app to kgx livery roundtrip. |
| 33 | `tests/test-livery.c#/kgx/livery/set_palette@150` | A person can rely on the app to kgx livery set palette. | — | **gap** | A person can rely on the app to kgx livery set palette. |
| 34 | `tests/test-livery.c#/kgx/livery/set_palette_same@151` | A person can rely on the app to kgx livery set palette same. | — | **gap** | A person can rely on the app to kgx livery set palette same. |
| 35 | `tests/test-livery.c#/kgx/livery/type@147` | A person can rely on the app to kgx livery type. | — | **gap** | A person can rely on the app to kgx livery type. |

## Suite: locale (1 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 36 | `tests/test-locale.c#/kgx/locale/init@37` | A person can rely on the app to kgx locale init. | — | **gap** | A person can rely on the app to kgx locale init. |

## Suite: pages (2 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 37 | `tests/test-pages.c#/kgx/pages/initial-state@64` | A person can rely on the app to kgx pages initial state. | — | **gap** | A person can rely on the app to kgx pages initial state. |
| 38 | `tests/test-pages.c#/kgx/pages/new-destroy@63` | A person can rely on the app to kgx pages new destroy. | — | **gap** | A person can rely on the app to kgx pages new destroy. |

## Suite: palette (10 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 39 | `tests/test-palette.c#/kgx/palette/colours@280` | A person can rely on the app to kgx palette colours. | — | **gap** | A person can rely on the app to kgx palette colours. |
| 40 | `tests/test-palette.c#/kgx/palette/deserialise@283` | A person can rely on the app to kgx palette deserialise. | — | **gap** | A person can rely on the app to kgx palette deserialise. |
| 41 | `tests/test-palette.c#/kgx/palette/new@277` | A person can rely on the app to kgx palette new. | — | **gap** | A person can rely on the app to kgx palette new. |
| 42 | `tests/test-palette.c#/kgx/palette/opaque@279` | A person can rely on the app to kgx palette opaque. | — | **gap** | A person can rely on the app to kgx palette opaque. |
| 43 | `tests/test-palette.c#/kgx/palette/serialise@281` | A person can rely on the app to kgx palette serialise. | — | **gap** | A person can rely on the app to kgx palette serialise. |
| 44 | `tests/test-palette.c#/kgx/palette/serialise_validate@282` | A person can rely on the app to kgx palette serialise validate. | — | **gap** | A person can rely on the app to kgx palette serialise validate. |
| 45 | `tests/test-palette.c#/kgx/palette/set_palette@284` | A person can rely on the app to kgx palette set palette. | — | **gap** | A person can rely on the app to kgx palette set palette. |
| 46 | `tests/test-palette.c#/kgx/palette/set_palette_same@285` | A person can rely on the app to kgx palette set palette same. | — | **gap** | A person can rely on the app to kgx palette set palette same. |
| 47 | `tests/test-palette.c#/kgx/palette/transparency@278` | A person can rely on the app to kgx palette transparency. | — | **gap** | A person can rely on the app to kgx palette transparency. |
| 48 | `tests/test-palette.c#/kgx/palette/type@276` | A person can rely on the app to kgx palette type. | — | **gap** | A person can rely on the app to kgx palette type. |

## Suite: playbox (1 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 49 | `tests/test-playbox.c#/kgx/playbox/is_playbox/case_%@58` | A person can rely on the app to kgx playbox is playbox each table driven case. | — | **gap** | A person can rely on the app to kgx playbox is playbox each table driven case. |

## Suite: proxy-info (9 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 50 | `tests/test-proxy-info.c#/kgx/proxy-info/apply/auto@381` | A person can rely on the app to kgx proxy info apply auto. | — | **gap** | A person can rely on the app to kgx proxy info apply auto. |
| 51 | `tests/test-proxy-info.c#/kgx/proxy-info/apply/manual-ftp@401` | A person can rely on the app to kgx proxy info apply manual ftp. | — | **gap** | A person can rely on the app to kgx proxy info apply manual ftp. |
| 52 | `tests/test-proxy-info.c#/kgx/proxy-info/apply/manual-http@386` | A person can rely on the app to kgx proxy info apply manual http. | — | **gap** | A person can rely on the app to kgx proxy info apply manual http. |
| 53 | `tests/test-proxy-info.c#/kgx/proxy-info/apply/manual-http-auth@391` | A person can rely on the app to kgx proxy info apply manual http auth. | — | **gap** | A person can rely on the app to kgx proxy info apply manual http auth. |
| 54 | `tests/test-proxy-info.c#/kgx/proxy-info/apply/manual-https@396` | A person can rely on the app to kgx proxy info apply manual https. | — | **gap** | A person can rely on the app to kgx proxy info apply manual https. |
| 55 | `tests/test-proxy-info.c#/kgx/proxy-info/apply/manual-socks@406` | A person can rely on the app to kgx proxy info apply manual socks. | — | **gap** | A person can rely on the app to kgx proxy info apply manual socks. |
| 56 | `tests/test-proxy-info.c#/kgx/proxy-info/apply/mode-changed@411` | A person can rely on the app to kgx proxy info apply mode changed. | — | **gap** | A person can rely on the app to kgx proxy info apply mode changed. |
| 57 | `tests/test-proxy-info.c#/kgx/proxy-info/apply/none@376` | A person can rely on the app to kgx proxy info apply none. | — | **gap** | A person can rely on the app to kgx proxy info apply none. |
| 58 | `tests/test-proxy-info.c#/kgx/proxy-info/new-destroy@371` | A person can rely on the app to kgx proxy info new destroy. | — | **gap** | A person can rely on the app to kgx proxy info new destroy. |

## Suite: remote (1 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 59 | `tests/test-remote.c#/kgx/remote/is_remote/case_%@61` | A person can rely on the app to kgx remote is remote each table driven case. | — | **gap** | A person can rely on the app to kgx remote is remote each table driven case. |

## Suite: settings (22 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 60 | `tests/test-settings.c#/kgx/settings/always-stop-train@806` | A person can rely on the app to kgx settings always stop train. | — | **gap** | A person can rely on the app to kgx settings always stop train. |
| 61 | `tests/test-settings.c#/kgx/settings/audible-bell@790` | A person can rely on the app to kgx settings audible bell. | — | **gap** | A person can rely on the app to kgx settings audible bell. |
| 62 | `tests/test-settings.c#/kgx/settings/custom-font@770` | A person can rely on the app to kgx settings custom font. | — | **gap** | A person can rely on the app to kgx settings custom font. |
| 63 | `tests/test-settings.c#/kgx/settings/custom-shell@777` | A person can rely on the app to kgx settings custom shell. | — | **gap** | A person can rely on the app to kgx settings custom shell. |
| 64 | `tests/test-settings.c#/kgx/settings/custom-size@776` | A person can rely on the app to kgx settings custom size. | — | **gap** | A person can rely on the app to kgx settings custom size. |
| 65 | `tests/test-settings.c#/kgx/settings/font-scale/decrease@768` | A person can rely on the app to kgx settings font scale decrease. | — | **gap** | A person can rely on the app to kgx settings font scale decrease. |
| 66 | `tests/test-settings.c#/kgx/settings/font-scale/get-set@766` | A person can rely on the app to kgx settings font scale get set. | — | **gap** | A person can rely on the app to kgx settings font scale get set. |
| 67 | `tests/test-settings.c#/kgx/settings/font-scale/increase@767` | A person can rely on the app to kgx settings font scale increase. | — | **gap** | A person can rely on the app to kgx settings font scale increase. |
| 68 | `tests/test-settings.c#/kgx/settings/font-scale/reset@769` | A person can rely on the app to kgx settings font scale reset. | — | **gap** | A person can rely on the app to kgx settings font scale reset. |
| 69 | `tests/test-settings.c#/kgx/settings/font/custom-is-null@774` | A person can rely on the app to kgx settings font custom is null. | — | **gap** | A person can rely on the app to kgx settings font custom is null. |
| 70 | `tests/test-settings.c#/kgx/settings/font/default-is-system@772` | A person can rely on the app to kgx settings font default is system. | — | **gap** | A person can rely on the app to kgx settings font default is system. |
| 71 | `tests/test-settings.c#/kgx/settings/font/switch-to-custom@773` | A person can rely on the app to kgx settings font switch to custom. | — | **gap** | A person can rely on the app to kgx settings font switch to custom. |
| 72 | `tests/test-settings.c#/kgx/settings/livery@792` | A person can rely on the app to kgx settings livery. | — | **gap** | A person can rely on the app to kgx settings livery. |
| 73 | `tests/test-settings.c#/kgx/settings/new-destroy@765` | A person can rely on the app to kgx settings new destroy. | — | **gap** | A person can rely on the app to kgx settings new destroy. |
| 74 | `tests/test-settings.c#/kgx/settings/resolve-theme/%s/%s@783` | A person can rely on the app to kgx settings resolve theme each parameterized case each parameterized case. | — | **gap** | A person can rely on the app to kgx settings resolve theme each parameterized case each parameterized case. |
| 75 | `tests/test-settings.c#/kgx/settings/scrollback/basic@794` | A person can rely on the app to kgx settings scrollback basic. | — | **gap** | A person can rely on the app to kgx settings scrollback basic. |
| 76 | `tests/test-settings.c#/kgx/settings/scrollback/resolve/%s/%@797` | A person can rely on the app to kgx settings scrollback resolve each parameterized case each parameterized case. | — | **gap** | A person can rely on the app to kgx settings scrollback resolve each parameterized case each parameterized case. |
| 77 | `tests/test-settings.c#/kgx/settings/size@775` | A person can rely on the app to kgx settings size. | — | **gap** | A person can rely on the app to kgx settings size. |
| 78 | `tests/test-settings.c#/kgx/settings/software-flow-control@804` | A person can rely on the app to kgx settings software flow control. | — | **gap** | A person can rely on the app to kgx settings software flow control. |
| 79 | `tests/test-settings.c#/kgx/settings/transparency@805` | A person can rely on the app to kgx settings transparency. | — | **gap** | A person can rely on the app to kgx settings transparency. |
| 80 | `tests/test-settings.c#/kgx/settings/use-system-font@771` | A person can rely on the app to kgx settings use system font. | — | **gap** | A person can rely on the app to kgx settings use system font. |
| 81 | `tests/test-settings.c#/kgx/settings/visual-bell@791` | A person can rely on the app to kgx settings visual bell. | — | **gap** | A person can rely on the app to kgx settings visual bell. |

## Suite: shared-closures (11 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 82 | `tests/test-shared-closures.c#/kgx/shared-closures/bool_and@246` | A person can rely on the app to kgx shared closures bool and. | — | **gap** | A person can rely on the app to kgx shared closures bool and. |
| 83 | `tests/test-shared-closures.c#/kgx/shared-closures/decoration_layout_is_inverted/case_%@260` | A person can rely on the app to kgx shared closures decoration layout is inverted each table driven case. | — | **gap** | A person can rely on the app to kgx shared closures decoration layout is inverted each table driven case. |
| 84 | `tests/test-shared-closures.c#/kgx/shared-closures/enum_is@244` | A person can rely on the app to kgx shared closures enum is. | — | **gap** | A person can rely on the app to kgx shared closures enum is. |
| 85 | `tests/test-shared-closures.c#/kgx/shared-closures/flags_includes@245` | A person can rely on the app to kgx shared closures flags includes. | — | **gap** | A person can rely on the app to kgx shared closures flags includes. |
| 86 | `tests/test-shared-closures.c#/kgx/shared-closures/format_percentage/case_%@250` | A person can rely on the app to kgx shared closures format percentage each table driven case. | — | **gap** | A person can rely on the app to kgx shared closures format percentage each table driven case. |
| 87 | `tests/test-shared-closures.c#/kgx/shared-closures/manager_null_when_null@233` | A person can rely on the app to kgx shared closures manager null when null. | — | **gap** | A person can rely on the app to kgx shared closures manager null when null. |
| 88 | `tests/test-shared-closures.c#/kgx/shared-closures/object_or_fallback@243` | A person can rely on the app to kgx shared closures object or fallback. | — | **gap** | A person can rely on the app to kgx shared closures object or fallback. |
| 89 | `tests/test-shared-closures.c#/kgx/shared-closures/settings_null_when_null@234` | A person can rely on the app to kgx shared closures settings null when null. | — | **gap** | A person can rely on the app to kgx shared closures settings null when null. |
| 90 | `tests/test-shared-closures.c#/kgx/shared-closures/text_as_variant@255` | A person can rely on the app to kgx shared closures text as variant. | — | **gap** | A person can rely on the app to kgx shared closures text as variant. |
| 91 | `tests/test-shared-closures.c#/kgx/shared-closures/text_non_empty@256` | A person can rely on the app to kgx shared closures text non empty. | — | **gap** | A person can rely on the app to kgx shared closures text non empty. |
| 92 | `tests/test-shared-closures.c#/kgx/shared-closures/text_or_fallback/case_%@238` | A person can rely on the app to kgx shared closures text or fallback each table driven case. | — | **gap** | A person can rely on the app to kgx shared closures text or fallback each table driven case. |

## Suite: spad-source (4 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 93 | `tests/test-spad-source.c#/kgx/spad-source/new-destroy@162` | A person can rely on the app to kgx spad source new destroy. | — | **gap** | A person can rely on the app to kgx spad source new destroy. |
| 94 | `tests/test-spad-source.c#/kgx/spad-source/throw@163` | A person can rely on the app to kgx spad source throw. | — | **gap** | A person can rely on the app to kgx spad source throw. |
| 95 | `tests/test-spad-source.c#/kgx/spad-source/throw/unhandled/case_1@164` | A person can rely on the app to kgx spad source throw unhandled case 1. | — | **gap** | A person can rely on the app to kgx spad source throw unhandled case 1. |
| 96 | `tests/test-spad-source.c#/kgx/spad-source/throw/unhandled/case_2@165` | A person can rely on the app to kgx spad source throw unhandled case 2. | — | **gap** | A person can rely on the app to kgx spad source throw unhandled case 2. |

## Suite: spad (7 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 97 | `tests/test-spad.c#/kgx/spad/build_bundle@226` | A person can rely on the app to kgx spad build bundle. | — | **gap** | A person can rely on the app to kgx spad build bundle. |
| 98 | `tests/test-spad.c#/kgx/spad/build_bundle/with_error@227` | A person can rely on the app to kgx spad build bundle with error. | — | **gap** | A person can rely on the app to kgx spad build bundle with error. |
| 99 | `tests/test-spad.c#/kgx/spad/get-set@225` | A person can rely on the app to kgx spad get set. | — | **gap** | A person can rely on the app to kgx spad get set. |
| 100 | `tests/test-spad.c#/kgx/spad/new-destroy@224` | A person can rely on the app to kgx spad new destroy. | — | **gap** | A person can rely on the app to kgx spad new destroy. |
| 101 | `tests/test-spad.c#/kgx/spad/new_from_bundle@228` | A person can rely on the app to kgx spad new from bundle. | — | **gap** | A person can rely on the app to kgx spad new from bundle. |
| 102 | `tests/test-spad.c#/kgx/spad/new_from_bundle/no_title@229` | A person can rely on the app to kgx spad new from bundle no title. | — | **gap** | A person can rely on the app to kgx spad new from bundle no title. |
| 103 | `tests/test-spad.c#/kgx/spad/new_from_bundle/with_error@230` | A person can rely on the app to kgx spad new from bundle with error. | — | **gap** | A person can rely on the app to kgx spad new from bundle with error. |

## Suite: system-info (2 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 104 | `tests/test-system-info.c#/kgx/system-info/monospace-font@102` | A person can rely on the app to kgx system info monospace font. | — | **gap** | A person can rely on the app to kgx system info monospace font. |
| 105 | `tests/test-system-info.c#/kgx/system-info/new-destroy@97` | A person can rely on the app to kgx system info new destroy. | — | **gap** | A person can rely on the app to kgx system info new destroy. |

## Suite: tab (4 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 106 | `tests/test-tab.c#/kgx/tab/bell@256` | A person can rely on the app to kgx tab bell. | — | **gap** | A person can rely on the app to kgx tab bell. |
| 107 | `tests/test-tab.c#/kgx/tab/initial-title@257` | A person can rely on the app to kgx tab initial title. | — | **gap** | A person can rely on the app to kgx tab initial title. |
| 108 | `tests/test-tab.c#/kgx/tab/new-destroy@254` | A person can rely on the app to kgx tab new destroy. | — | **gap** | A person can rely on the app to kgx tab new destroy. |
| 109 | `tests/test-tab.c#/kgx/tab/working@255` | A person can rely on the app to kgx tab working. | — | **gap** | A person can rely on the app to kgx tab working. |

## Suite: templated (6 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 110 | `tests/test-templated.c#/kgx/templated/also/multi-dispose@413` | A person can rely on the app to kgx templated also multi dispose. | — | **gap** | A person can rely on the app to kgx templated also multi dispose. |
| 111 | `tests/test-templated.c#/kgx/templated/also/new-destroy@411` | A person can rely on the app to kgx templated also new destroy. | — | **gap** | A person can rely on the app to kgx templated also new destroy. |
| 112 | `tests/test-templated.c#/kgx/templated/also/properties@412` | A person can rely on the app to kgx templated also properties. | — | **gap** | A person can rely on the app to kgx templated also properties. |
| 113 | `tests/test-templated.c#/kgx/templated/apply@414` | A person can rely on the app to kgx templated apply. | — | **gap** | A person can rely on the app to kgx templated apply. |
| 114 | `tests/test-templated.c#/kgx/templated/base/new-destroy@409` | A person can rely on the app to kgx templated base new destroy. | — | **gap** | A person can rely on the app to kgx templated base new destroy. |
| 115 | `tests/test-templated.c#/kgx/templated/base/properties@410` | A person can rely on the app to kgx templated base properties. | — | **gap** | A person can rely on the app to kgx templated base properties. |

## Suite: theme-switcher (2 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 116 | `tests/test-theme-switcher.c#/kgx/theme-switcher/get-set@69` | A person can rely on the app to kgx theme switcher get set. | — | **gap** | A person can rely on the app to kgx theme switcher get set. |
| 117 | `tests/test-theme-switcher.c#/kgx/theme-switcher/new-destroy@68` | A person can rely on the app to kgx theme switcher new destroy. | — | **gap** | A person can rely on the app to kgx theme switcher new destroy. |

## Suite: train (5 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 118 | `tests/test-train.c#/kgx/train/children@279` | A person can rely on the app to kgx train children. | — | **gap** | A person can rely on the app to kgx train children. |
| 119 | `tests/test-train.c#/kgx/train/died@284` | A person can rely on the app to kgx train died. | — | **gap** | A person can rely on the app to kgx train died. |
| 120 | `tests/test-train.c#/kgx/train/init@269` | A person can rely on the app to kgx train init. | — | **gap** | A person can rely on the app to kgx train init. |
| 121 | `tests/test-train.c#/kgx/train/new-destroy@268` | A person can rely on the app to kgx train new destroy. | — | **gap** | A person can rely on the app to kgx train new destroy. |
| 122 | `tests/test-train.c#/kgx/train/props@274` | A person can rely on the app to kgx train props. | — | **gap** | A person can rely on the app to kgx train props. |

## Suite: utils (13 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 123 | `tests/test-utils.c#/kgx/utils/filter_argument/case_%@653` | A person can rely on the app to kgx utils filter argument each table driven case. | — | **gap** | A person can rely on the app to kgx utils filter argument each table driven case. |
| 124 | `tests/test-utils.c#/kgx/utils/filter_arguments/both@657` | A person can rely on the app to kgx utils filter arguments both. | — | **gap** | A person can rely on the app to kgx utils filter arguments both. |
| 125 | `tests/test-utils.c#/kgx/utils/filter_arguments/missing@658` | A person can rely on the app to kgx utils filter arguments missing. | — | **gap** | A person can rely on the app to kgx utils filter arguments missing. |
| 126 | `tests/test-utils.c#/kgx/utils/parse_percentage/case_%@676` | A person can rely on the app to kgx utils parse percentage each table driven case. | — | **gap** | A person can rely on the app to kgx utils parse percentage each table driven case. |
| 127 | `tests/test-utils.c#/kgx/utils/set_boolean@645` | A person can rely on the app to kgx utils set boolean. | — | **gap** | A person can rely on the app to kgx utils set boolean. |
| 128 | `tests/test-utils.c#/kgx/utils/set_enum@649` | A person can rely on the app to kgx utils set enum. | — | **gap** | A person can rely on the app to kgx utils set enum. |
| 129 | `tests/test-utils.c#/kgx/utils/set_flags@648` | A person can rely on the app to kgx utils set flags. | — | **gap** | A person can rely on the app to kgx utils set flags. |
| 130 | `tests/test-utils.c#/kgx/utils/set_int64@646` | A person can rely on the app to kgx utils set int64. | — | **gap** | A person can rely on the app to kgx utils set int64. |
| 131 | `tests/test-utils.c#/kgx/utils/set_str@647` | A person can rely on the app to kgx utils set str. | — | **gap** | A person can rely on the app to kgx utils set str. |
| 132 | `tests/test-utils.c#/kgx/utils/str_constrained_append@659` | A person can rely on the app to kgx utils str constrained append. | — | **gap** | A person can rely on the app to kgx utils str constrained append. |
| 133 | `tests/test-utils.c#/kgx/utils/str_constrained_dup/case_%@662` | A person can rely on the app to kgx utils str constrained dup each table driven case. | — | **gap** | A person can rely on the app to kgx utils str constrained dup each table driven case. |
| 134 | `tests/test-utils.c#/kgx/utils/str_non_empty/case_%@669` | A person can rely on the app to kgx utils str non empty each table driven case. | — | **gap** | A person can rely on the app to kgx utils str non empty each table driven case. |
| 135 | `tests/test-utils.c#/kgx/utils/uri_is_non_local_file/case_%@683` | A person can rely on the app to kgx utils uri is non local file each table driven case. | — | **gap** | A person can rely on the app to kgx utils uri is non local file each table driven case. |

## Suite: window (13 tests)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 136 | `tests/test-window.c#/kgx/window/add_tab@583` | A person can rely on the app to kgx window add tab. | — | **gap** | A person can rely on the app to kgx window add tab. |
| 137 | `tests/test-window.c#/kgx/window/floating@577` | A person can rely on the app to kgx window floating. | — | **gap** | A person can rely on the app to kgx window floating. |
| 138 | `tests/test-window.c#/kgx/window/get_working_dir@586` | A person can rely on the app to kgx window get working dir. | — | **gap** | A person can rely on the app to kgx window get working dir. |
| 139 | `tests/test-window.c#/kgx/window/new-destroy@574` | A person can rely on the app to kgx window new destroy. | — | **gap** | A person can rely on the app to kgx window new destroy. |
| 140 | `tests/test-window.c#/kgx/window/realize-unrealize@580` | A person can rely on the app to kgx window realize unrealize. | — | **gap** | A person can rely on the app to kgx window realize unrealize. |
| 141 | `tests/test-window.c#/kgx/window/ringing@584` | A person can rely on the app to kgx window ringing. | — | **gap** | A person can rely on the app to kgx window ringing. |
| 142 | `tests/test-window.c#/kgx/window/search-mode@576` | A person can rely on the app to kgx window search mode. | — | **gap** | A person can rely on the app to kgx window search mode. |
| 143 | `tests/test-window.c#/kgx/window/settings/direct@575` | A person can rely on the app to kgx window settings direct. | — | **gap** | A person can rely on the app to kgx window settings direct. |
| 144 | `tests/test-window.c#/kgx/window/status@585` | A person can rely on the app to kgx window status. | — | **gap** | A person can rely on the app to kgx window status. |
| 145 | `tests/test-window.c#/kgx/window/translucent/derived@579` | A person can rely on the app to kgx window translucent derived. | — | **gap** | A person can rely on the app to kgx window translucent derived. |
| 146 | `tests/test-window.c#/kgx/window/translucent/direct@578` | A person can rely on the app to kgx window translucent direct. | — | **gap** | A person can rely on the app to kgx window translucent direct. |
| 147 | `tests/test-window.c#/kgx/window/trigger-breakpoints/empty@581` | A person can rely on the app to kgx window trigger breakpoints empty. | — | **gap** | A person can rely on the app to kgx window trigger breakpoints empty. |
| 148 | `tests/test-window.c#/kgx/window/trigger-breakpoints/with-tab@582` | A person can rely on the app to kgx window trigger breakpoints with tab. | — | **gap** | A person can rely on the app to kgx window trigger breakpoints with tab. |

## Extra

- `test/actions_test.rb` — 71 named action steps that exercise application actions and dialogs; none is a one-to-one port of an upstream unit test.
- `test/integration_test.rb` — 25 named integration checks covering startup, PTY execution, settings, palettes, regexes, process inspection and train state; none is a one-to-one port of an upstream unit test.
