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
