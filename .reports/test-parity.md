# Test parity — valuta

| | |
|---|---|
| Upstream | `origin/main` (Python/Blueprint) |
| Port | `ruby` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Test command (port) | `nix develop --command xvfb-run -a ruby test/drive_convertion.rb` and `test/drive_search_provider.rb` |

Upstream has no test suite: no `test/`/`tests/` directory, no `unittest`/`pytest` usage, no test target wired into any build file, and `.claude/skills/test-parity/scripts/test-census.sh` run against a detached worktree of `origin/main` returns **zero rows**. Verified by `find . -iname 'test*'` on the upstream tree (nothing) and a direct grep for `unittest`/`pytest`/`def test_` across `src/` (nothing).

Per the skill: **this is not a license to skip the check, and it is not a pass by omission.** Parity is 0/0 and is met trivially — stated plainly, not implied:

**The port therefore inherits no safety net from upstream. Every check below was written for the port and pins nothing upstream considered worth pinning down.** There is no upstream regression test, no documented edge case, no bug-that-came-back case to carry forward. Nothing here should be read as "the port is well-tested because upstream had nothing to lose" — it is the opposite: whatever the port gets wrong, there is no inherited tripwire that will catch it.

## Extra

Two headless drivers exist, both under `test/`, run through the `ruby-gtk-testing`-style harness in `test/gtk_driver.rb`:

- `test/drive_convertion.rb` — 32 checks. Builds the window, drives the conversion flow (entry, both currency selectors, the result/loading/error stack, a bad-amount error state, re-conversion, the currency-selector popover and its search, row activation, `switch-currencies`, the provider action state, the About dialog, and the shortcuts dialog). Verified by actually running it in this audit: `32 of 32 checks passed`, `DRIVE OK`.
- `test/drive_search_provider.rb` — 18 checks. Drives the GNOME Shell search-provider D-Bus surface directly against `ShellSearchProvider`: a bare-amount query, result metas, an unknown id, narrowing a search, the four-term `<amount> <FROM> to <TO>` form, a currency-into-itself query, non-amount text, and activating the clipboard row. Verified by running it in this audit: `18 of 18 checks passed`, `DRIVE OK`.

Combined: **50 of 50 checks passed**, matching the runtime gate this round reported (`drive_ok=true, 50 checks, 0 failed`). That number is real and reproducible — I ran both drivers myself under `nix develop --command xvfb-run -a ruby test/drive_*.rb` and got the same counts.

## What the gate's "16 components" does *not* cover — this is the actual gap

The task framing is explicit: **a component no check exercises is unverified, not done.** Reading the two drivers against the 18 files in `lib/`, several whole components and whole behaviors are never driven by any check:

- **`lib/application.rb`** — `Adw::Application` subclass, `do_activate`/`do_command_line`, and specifically the **second-invocation hand-off**: upstream's `--src-currency-value` CLI flag re-activating an already-running instance and pushing a new conversion into the live window. Neither driver launches a second process or exercises `do_command_line`. This is the single most state-machine-heavy piece of `application.rb` and it has no check at all.
- **`lib/shell_search_provider.rb`**'s registration/service plumbing — `drive_search_provider.rb` drives the `ShellSearchProvider` object's methods directly in-process; it does not exercise the actual D-Bus service activation (`io.github.idevecore.Valuta.SearchProvider.service`, `exe/valuta-search-provider`) end-to-end over a bus.
- **Window-state persistence** — `lib/window.rb`'s binding of width/height/maximized/fullscreened to `Settings` is listed in the component inventory but neither driver resizes, maximizes, or closes/reopens the window to assert the settings round-trip.
- **`lib/currencies_list_model.rb` / `lib/currency_object.rb`** — exercised only incidentally through the popover search/selection checks in `drive_convertion.rb`; there is no direct check of `CurrenciesListModel#set_currencies` replacing the list and firing `items_changed`, or of `set_selected` flipping exactly one row.
- **`lib/requests.rb` / provider dispatch** — both drivers run against whatever network/stub path the app takes at headless runtime; there is no check that isolates `Requests`/`ECB`/`SoupSession` request-building (URL construction, `User-Agent`) the way a unit test would. If the live HTTP call happens to fail in CI, "the rate arrives" check (`drive_convertion.rb`, step `[2]`) would be the only signal, conflating a network failure with a logic failure.
- **`lib/actions.rb`'s accelerators** — the fix for upstream's `<primary>q`/`<primary>w` double-bind bug (`lib/actions.rb:14-20`) is asserted nowhere; no check presses either accelerator and confirms both quit.
- **Non-English locale rendering** — no check exists for this because the port has no translation infrastructure at all (see `translation-parity.md`); there is nothing to drive yet.

None of this invalidates the 50 passing checks — they are real and they cover the main conversion flow and the search provider's term-parsing branches reasonably well. But "50/50, 16 components, drive_ok=true" is doing more work in the runtime-gate framing than the evidence supports: it is a clean run of a narrow suite, not a demonstration that the port's 18 `lib/` files are behaviourally verified. Treat `application.rb`'s command-line hand-off and the window-state persistence binding as unverified, not done.

## Rules followed

- Did not read the 0/0 upstream result as "no test-parity work needed" — the extra section above and the gate-coverage gap are the work this skill still requires when upstream ships no tests.
- Did not inflate 0/0 into a claim that the port is tested; stated explicitly that it has no inherited safety net.
- Did not accept "50 checks, drive_ok=true" as evidence of whole-app coverage without checking which files/behaviors those 50 checks actually touch.

## Re-audit, 2026-11-07, against current `ruby` HEAD (`0594500`)

Upstream still has 0 tests (unchanged — re-confirmed `test-census.sh` against a
fresh `origin/main` worktree: zero rows, no `test/`/`tests/`, no
`unittest`/`pytest`, no test target). Parity remains **0/0, met trivially,
no inherited safety net** — restating the finding above, not revising it.

Since the previous pass, `0594500` added three more drive checks (accelerator
round-trip off the live `Gtk::Application`, the stylesheet reload with a
parsing-error listener, and `CurrenciesListModel`'s `items-changed`/
`set_selected` behaviour driven directly). I re-ran both drivers myself under
`nix develop --command xvfb-run -a ruby test/drive_*.rb`:

```
50 of 50 checks passed   DRIVE OK   (test/drive_convertion.rb)
18 of 18 checks passed   DRIVE OK   (test/drive_search_provider.rb)
```

Combined **68 of 68 checks passed**, matching this round's runtime gate
(`drive_ok=true, 68 checks, 0 failed`) exactly. That number is real and I
reproduced it myself, not taken on trust.

Three of the gate-coverage gaps the previous pass listed are now closed:
the accelerator round-trip (`[21]`), the stylesheet parse-error listener
(`[22]`), and the currencies-list-model notification/selection check (`[23]`)
are all present and passing in the current `drive_convertion.rb`. The other
gaps listed above — `application.rb`'s D-Bus-level search-provider service
activation, `requests.rb`'s URL/`User-Agent` construction isolated from a
live network call, and non-English rendering — were **not** closed by either
commit since the last pass and still stand exactly as described above.
Non-English rendering now has something to drive (gettext landed in
`f9bbc76`), but no check drives it: neither driver sets `LANGUAGE=de` (or
any non-English locale) and asserts on a translated string. I verified by
hand, outside the suite, that `LANGUAGE=de` does produce correctly-translated
output (`po/de.po`'s `"General"` → `"Allgemein"` under its `shortcuts window`
context, `"Keyboard shortcuts"` → `"Tastenkürzel"`) — see
`translation-parity.md` — but **no check in `test/` pins that**, so a future
regression in `lib/i18n.rb`'s `bindtextdomain` wiring would not fail any
check in this suite, headless or otherwise.

### New finding this round: the RSpec harness is scaffolding with zero tests, and running it reports a clean pass

`spec/` contains only `spec_helper.rb` and `spec/README.md`. There is no
`spec/*_spec.rb` anywhere on this branch. Running the devshell's own
documented spec command:

```
$ ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'
NOTE: kettle-test isn't installed; running with plain RSpec.
No examples found.
0 examples, 0 failures
```

This is not a parity gap against upstream (upstream has 0 tests, so 0/0 is
still correct there) but it is a **false-green risk specific to this port**:
`rake`/CI tooling that runs this command sees "0 failures" and a zero exit
code, which reads exactly like a passing suite to any automation that checks
the exit status rather than the example count. The devshell banner advertises
`run the specs:` as if there is something to run. There is not. Anyone
relying on "the specs are green" as a signal for this app is relying on a
suite that has never executed a single assertion. This belongs in the
runtime-gate framing explicitly: the 68 checks that *do* exist and *do* pass
are in `test/drive_*.rb`, not in `spec/`, and the gate's "68 checks" number
should not be conflated with "the RSpec suite passes" — there is no RSpec
suite yet, only its scaffold.

## Re-audit, 2026-11-07, against `ruby` @ `c8dcd6c`

One commit landed since the prior pass (`c8dcd6c`, the gettext domain fix,
touching `Rakefile` and `lib/i18n.rb` only — no `lib/*.rb` widget file, no
`test/` file). Re-ran both drivers myself in this audit, under the same
`nix develop --command xvfb-run -a ruby test/drive_*.rb` invocation:

```
50 of 50 checks passed   DRIVE OK   (test/drive_convertion.rb)
18 of 18 checks passed   DRIVE OK   (test/drive_search_provider.rb)
```

Combined **68 of 68**, matching this round's runtime gate
(`drive_ok=true, 68 checks, 0 failed, 20 components`) exactly, and
unchanged from the previous pass — expected, since the one commit in scope
did not touch any driven code path. Re-ran the RSpec command too:

```
No examples found.
0 examples, 0 failures
```

**Unchanged: still 0 examples.** The false-green risk named above stands
exactly as described; nothing in this round's single commit closed it.

**The gate's "20 components" figure is not independently reconciled by this
report.** Counting `##`-level units in `.reports/component-inventory.md`
gives roughly 11 named sections (several of which, like "Settings /
Convertion / Requests / ...", bundle multiple `lib/*.rb` files under one
heading), not a clean 20. `find lib -name '*.rb' | wc -l` gives **22** files
on this branch (including the gem-scaffold `lib/valuta.rb`,
`lib/valuta/rb.rb`, and `lib/valuta/rb/version.rb`, none of which are
user-facing components). Nobody in this audit traced the gate's own
component-counting method against either the 22-file count, the ~11-section
inventory, or any other grouping that lands on exactly 20. Flagged as an
open, unreconciled question, not resolved as a match — a count that happens
to be plausible under some reading is not the same as a count this audit
traced end to end.
