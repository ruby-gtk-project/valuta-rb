# Test parity — valuta-rb

Re-audit, 2026-11-08, against `ruby` @ `9df781b` / upstream `origin/main`.
Supersedes the prior pass in this file (kept below the `---` marker, not
deleted) which was run against `ruby` @ `2bd7118` and recorded the RSpec
suite as 0 examples. That is no longer true — see below.

## Upstream has no test suite

Re-confirmed: `git ls-tree -r --name-only origin/main | grep -i test` and
`grep -rl "unittest\|pytest" <(git show origin/main:...)` style checks find
nothing. Upstream ships 0 tests. So "test parity" here cannot mean
file-for-file test porting; it means the port is actually exercised at least
as much as a shipped, trusted app would need to be, and that every claim of
"it works" in this branch's own reports rests on something that actually ran.

## What actually runs, re-executed today

```
nix develop --command xvfb-run -a ruby test/drive_convertion.rb        → 54 of 54 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby test/drive_search_provider.rb   → 18 of 18 checks passed, DRIVE OK
nix develop --command xvfb-run -a ruby -e 'RSpec::Core::Runner.run(...)' → 5 examples, 0 failures
```

54 + 18 = **72 checks, 0 failed** — matches the round's stated runtime gate
exactly. Both drive scripts were re-run in this pass, not taken on faith from
a prior log.

**The RSpec gap is now closed.** The prior pass in this file (and in
`accountability-ensurance.md`) correctly flagged "0 examples, 0 failures" as
a suite that had never executed a single assertion — a real gap, honestly
labelled, not a false green. `spec/requests_spec.rb` (added since, commit
`49474ac`) now gives `Requests::ECB`, `Requests::SoupSession` and
`Requests#get` five real unit assertions: the exact `frankfurter.app` URL
built from an amount/currency pair, the JSON-body-to-response-Hash shape
(including the `info` date string), the default `User-Agent` header and its
override, and that a transport failure (`IOError`) is caught and turned into
the error-message string the window reads rather than propagating. These are
genuine assertions against real inputs/outputs, not tautologies — re-ran them
this pass, all 5 pass.

## Coverage by component — which of the 12 are actually driven

Walking `lib/*.rb` (20 files; `lib/valuta/rb.rb` and `lib/valuta/rb/version.rb`
are gem scaffolding, not app components) against what `drive_convertion.rb`,
`drive_search_provider.rb` and `spec/requests_spec.rb` actually touch:

| Component | Exercised by | How |
|---|---|---|
| `window.rb` | drive_convertion | header menu, providers action, about/shortcuts launch, accelerators |
| `convertion_page.rb` | drive_convertion | amount entry, invert button, result/loading/error stack pages (incl. the error page + reload button, new this round) |
| `convertion.rb` | drive_convertion | cache/staleness driving real + stubbed-failure conversions |
| `currency_selector.rb` | drive_convertion | popover open/search/row-activate |
| `currency_selector_row.rb` | drive_convertion | row selection, label |
| `currencies_list_model.rb` | drive_convertion | load/replace/selection notifications |
| `actions.rb` | drive_convertion | accelerator resolution for all 3 actions |
| `style.rb` | drive_convertion | CSS parses with no swallowed errors, provider installed |
| `settings.rb` | drive_convertion | width/height/is-maximized round-trip through a fresh reader |
| `about_dialog.rb` | drive_convertion | dialog opens, version, debug info |
| `shortcuts.rb` | drive_convertion | dialog opens, is the shortcuts dialog |
| `application.rb` | drive_convertion | second-invocation `--src-currency-value` hand-off to the running window |
| `requests.rb` | drive_convertion (stubbed failure + real network) + requests_spec | URL building, response shaping, header defaults, error path |
| `shell_search_provider.rb` | drive_search_provider | all 8 scenarios: conversion, metas, unknown id, narrowing, 4-term form, self-conversion, non-amount text, clipboard row |
| `currency_object.rb` | indirectly, via currency_selector/selector_row rows built from it | no direct assertion on the class itself |
| `define.rb` | indirectly, via `Define::CODES`/`Define::APP_ID` used throughout | no direct assertion |
| `i18n.rb` | indirectly, every translated string rendered in the driven dialogs | no assertion that `bindtextdomain`/the gettext mixin itself behaves correctly in isolation (e.g. that a non-English `.mo` actually swaps a string — see **gap** below) |
| **`utils.rb`** | **indirectly only, and only its English/default path** | see **gap** below — this is the one real, newly-found coverage hole |
| `valuta.rb`, `main.rb` | not exercised by any check | thin entry-point/version files; `main.rb` is `exe/valuta`'s require chain, not independently asserted |

12 of these are the "12 components" the gate counts; the table above is the
honest accounting of which lib files back them, not a 1:1 relabeling.

## Gap: `Utils`'s locale-separator table is untested outside the English path

`lib/utils.rb`'s `SEPARATORS` constant hand-ports Babel/CLDR's grouping and
decimal separators for all 33 locales upstream ships translations for (e.g.
`'de' => ['.', ',']`, `'fr' => [NARROW_NO_BREAK_SPACE, ',']`). Upstream
delegates this to `babel.numbers.format_number`/`parse_decimal`
(`src/utils.py:22,162,173` — confirmed by reading it this pass), so this
table is upstream's actual decimal-formatting behavior, hand-transcribed.

**Nothing in `test/` or `spec/` ever runs the app, or calls `format_number`/
`parse_number` directly, under any locale but the default.** `drive_convertion.rb`
and `drive_search_provider.rb` both run under whatever `GLib.language_names`
resolves to in the Xvfb/nix-develop environment (English/`C` locale in every
run observed this pass and the prior one), which exercises `Utils#language`
returning `"en"`/unset and falls through to `DEFAULT_SEPARATORS`. The other
32 rows of the table — the actual locale-specific behavior upstream has —
are never read by any check. A transposed digit, a missing entry, or a wrong
separator pair for any of those 32 locales would pass every one of the 72
checks and both suites. This is exactly the shape of gap the task description
calls out: a component (locale-aware number formatting) that no check
exercises is unverified, not done, and this was not caught by any prior pass
in this `.reports/` directory.

**Fix:** a `spec/utils_spec.rb` that constructs `Utils` (or calls
`format_number`/`parse_number` against a stubbed `GLib.language_names`) for
at least a decimal-comma locale (`de`/`fr`) and a non-Latin-grouping one, and
asserts the grouped string and the round-trip parse. This does not need a
display or Xvfb — it is pure Ruby — so it belongs in `spec/`, not `test/`.

## Build/package surface — still not driven by anything

Re-confirmed, matching the prior pass: there is no check anywhere (`rake`,
`ruby -c`, drive, or spec) that `exe/valuta`/`exe/valuta-search-provider`
actually boot standalone, that `rake gettext:mo:update` succeeds, or that the
Flatpak/`.desktop`/`.service` files are internally consistent (app id,
D-Bus names). The drive scripts construct `Gtk::Application` objects
in-process; they do not fork `exe/valuta`. Low risk, but still unverified.

## Verdict

- Drive gate: **re-verified, 72/72, 0 failed.** Not taken on faith.
- Unit suite: **re-verified, 5/5, real assertions, no longer a false-green
  risk** — the prior "0 examples" gap is genuinely closed, not relabeled.
- New gap found this pass: **`Utils`'s 32 non-default locale separator rows
  have zero test coverage**, despite backing real, translated, user-facing
  number formatting in 32 of the 33 languages the port otherwise claims
  parity for.
- `clean` for this document: **false** — the Utils gap is open, and the
  entry-point files (`exe/*`, `rake gettext:mo:update`) remain unverified.

---

## Prior pass (superseded, kept for history)

Re-audit, 2026-11-07, against `ruby` @ `2bd7118`.

Upstream: 0 tests, confirmed via `test-census.sh`. Port: drive scripts gave
54 checks (`drive_convertion.rb`) + separately-confirmed search-provider
checks, all passing — re-verified again this pass, unchanged in count.

**The RSpec scaffold was still 0 examples, 0 failures at that point** — a
suite present in `Gemfile`/`spec/spec_helper.rb` but never given anything to
assert, which is the textbook shape of a false-green risk: "there is a test
suite" reads as reassurance until someone runs it and sees 0/0. This report
flagged it as a gap rather than passing it through as a pass, which was the
correct call — the suite now has real content (see above), closing exactly
this gap and no other.
