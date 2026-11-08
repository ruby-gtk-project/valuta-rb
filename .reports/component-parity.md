# Component parity — valuta

**Correction, 2026-11-08 (read this before the tables below).** The
`window` and `shortcuts` units below are marked with text-axis "gaps" —
claims that specific strings (`"Main menu"`, `"Source"`, `"About Valuta"`,
`"ECB"`, `"Providers"`, the three shortcut titles, `"General"`) are bare,
unwrapped Ruby literals where upstream translates them. **Read directly
against `lib/window.rb` and `lib/shortcuts.rb` this round, every one of
those specific claims is false of the current code** — each string is
already wrapped (`_('Main menu')`, `_('Source')`, `_('About Valuta')`,
`_('ECB')`, `_('Providers')`, and `p_('shortcuts window', '...')` for all
four shortcuts-dialog strings including `"General"`). `git diff
2bd7118..HEAD -- lib/window.rb lib/shortcuts.rb` is empty, so these files
have not changed since the claims below were written — they were already
false when written, not merely stale. The only genuinely unwrapped string in
either file is `lib/window.rb:26`'s `TITLE = 'Valuta'`, and upstream's own
`_("Valuta")` (`src/window.blp:9`) never made it into upstream's own `.pot`
(no `msgid "Valuta"` exists in `po/io.github.idevecore.Valuta.pot`), so no
locale has ever translated it upstream either — the port's unwrapped literal
is observably identical. Full detail and the msgid-level check is in
`translation-parity.md`'s 2026-11-08 section; the meta-finding (a report
asserting gaps that direct inspection does not support) is in
`accountability-ensurance.md`. **The rows below are kept verbatim, per this
project's rule that rows are never deleted — read the "Text" column of the
`window` and `shortcuts` tables as superseded by this note, not as current
fact.**

| | |
|---|---|
| Upstream | `origin/main` |
| Port | `ruby` |
| Units with full (4-axis) parity confirmed in this pass | 2 / 18 (`lib/actions.rb`, `lib/style.rb`'s rule bodies); after the 2026-11-08 correction above, `lib/window.rb` and `lib/shortcuts.rb` also have full 4-axis parity other than the inconsequential `TITLE` literal |
| Units with count/CSS/signal/action parity but a confirmed text-axis gap | none — see correction above; the two units previously listed here were a misreading |
| Units not independently re-verified on all four axes this round | `lib/convertion_page.rb`, `lib/currency_selector.rb`, `lib/currency_selector_row.rb`, `lib/shell_search_provider.rb`, `lib/about_dialog.rb`, `lib/currency_object.rb`, `lib/currencies_list_model.rb`, `lib/convertion.rb`, `lib/requests.rb`, `lib/define.rb`, `lib/utils.rb`, `lib/application.rb` |
| New this round | `lib/convertion_page.rb`'s `convertion-error` stack page and its reload button are now driven by `test/drive_convertion.rb` (checks added in `9df781b`) — count/behaviour confirmed for that one path; style/text axes for the rest of the file still unverified, see list above |

Four axes, per `component-parity`: count, style, behaviour, text. Reading the
units above against upstream file by file:

## Unit: window — `src/window.py` + `src/window.blp` → `lib/window.rb`

| Widget | Up × | Port × | CSS | Signals/Actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | — | `close-request` ✓ | ✗ title `_("Valuta")` vs bare `'Valuta'` | **gap** (text) |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | — | — | — | parity |
| `Gtk.MenuButton` (header) | 1 | 1 | — | `primary: true` ✓ | ✗ `_("Main menu")` vs bare `'Main menu'` | **gap** (text) |
| `Adw.Bin` (content) | 1 | 1 | — | — | — | parity |
| `Gtk.Box` (bottom toolbar) | 1 | 1 | ✓ `toolbar` | — | — | parity |
| `Gtk.Label` (info) | 1 | 1 | ✓ `dim-label` | — | — | parity (label text is computed at runtime, not upstream's empty `_("")` literal — not a gap) |
| `Gtk.LinkButton` (source) | 1 | 1 | — | `visible: false` ✓ | ✗ `_("Source")` tooltip vs bare `'Source'` | **gap** (text) |
| `window.providers` action | 1 | 1 | — | ✓ wired to `Settings#create_action` | — | parity |
| `win.show-help-overlay` | 1 | 1 | — | ✓, but via a plain action instead of `Gtk.Window.set_help_overlay` | — | **correspondence**, not a gap — forced by a documented binding limitation |
| `app.about` menu item | 1 | 1 | — | ✓ | ✗ `_("About Valuta")` vs `'About Valuta'` | **gap** (text) |
| `window.providers::ecb` menu item | 1 | 1 | — | ✓ | ✗ `_("ECB")`/`_("Providers")` vs bare | **gap** (text) |

Count/style/behaviour axes: **parity.** Text axis: **gap, every string in the
unit.**

## Unit: shortcuts — `src/components/shortcuts/*` → `lib/shortcuts.rb`

| Widget | Up × | Port × | CSS | Signals/Actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| Shortcuts window/dialog | 1 | 1 | `modal: true` not re-settable on `Adwaita::ShortcutsDialog` from the port's code — not verified either way | — | — | **correspondence**, forced substitution, documented |
| `ShortcutsSection`/`Adwaita::ShortcutsSection` | 1 | 1 | — | — | — | parity |
| `ShortcutsGroup`/section title | 1 | 1 | — | — | ✗ `C_("shortcuts window", "General")` vs `'General'` | **gap** (text) |
| `ShortcutsShortcut` ×3 | 3 | 3 | — | ✓ all three `action-name`s match | ✗ all three titles unmarked and lose their `"shortcuts window"` msgctxt | **gap** (text, ×3) |

Count/behaviour axes: **parity** (all three shortcuts present, correct
actions). Text axis: **gap on all four strings.**

## Unit: actions — `src/actions.py` → `lib/actions.rb`

| Action | Upstream accels | Port accels | Verdict |
|---|---|---|---|
| `app.quit` | `<primary>q`, then `<primary>w` (second call overwrites the first — upstream bug, only Ctrl+W actually quits) | `<primary>q` **and** `<primary>w` both bound | **correspondence, upstream bug fixed and documented** |
| `app.about` | — | — | parity |
| `app.switch-currencies` | `<primary>s` | `<primary>s` | parity |
| `win.show-help-overlay` | `<Primary>question` | `<Primary>question` | parity |

No translatable text in this unit (action names are not user-visible
strings). **Full 4-axis parity**, including the one place the port correctly
diverges from upstream's *actual* runtime behavior and says so in a comment.

## Unit: stylesheet — `src/assets/style.css` → `lib/style.rb`

Rule bodies are byte-identical (direct diff, see
`component-identification.md`). **Style axis: parity for rule content.**
Attachment is a mixed finding:

- `lib/currency_selector.rb` attaches `'currency-selector'` (corrected
  spelling) where upstream's `index.blp:30` attaches `'curency-selector'`
  (upstream's own typo). The port's popover will render **differently from
  upstream's actual shipped popover** — upstream's `.currency-selector
  list/row/separator` rules never fire upstream, and they will fire in the
  port. This is a real, user-visible divergence from upstream-as-shipped. It
  is not recorded as a "style gap" in the pass/fail sense (the port's result
  is arguably *more correct*), but it is recorded here because
  component-parity is about matching what upstream actually does, and this
  wasn't flagged anywhere before this audit, nor was it acknowledged as an
  intentional deviation in any ledger prior to this one.

## Unit: settings — `src/utils.py::Settings` → `lib/settings.rb`

Not a `Gio.Settings` subclass as the prior `.reports/component-inventory.md`
claimed (see `component-identification.md`'s correction) — it's a hand-rolled
JSON-backed store. Functionally the keys, defaults and enum (`providers`:
`ecb`) match the upstream schema's keys
(`providers`, `width`, `height`, `is-maximized`, `is-fullscreen`,
`src-currency`, `dest-currency`). This is a legitimate, documented
correspondence on the **mechanism** axis. It is **not independently verified
in this pass** that `create_action`/`bind`/`apply_to` reproduce every
observable behavior `Gio::Settings.create_action` provides (e.g. whether an
external `gsettings set io.github.idevecore.Valuta providers ecb` from the
CLI would be picked up — it would not, since there is no real schema
registered anywhere on the system). That is a real, if narrow, behavioral
gap: anything outside the app itself that expects this to be a real
GSettings-backed app (a GNOME Settings panel entry, `gsettings` CLI,
`dconf-editor`) finds nothing, where upstream is a normal GSettings app.

## What this pass did not cover

Per `component-identification.md`'s scope note, `lib/convertion_page.rb`
(three preference groups + stack states), `lib/currency_selector.rb`'s/
`lib/currency_selector_row.rb`'s full widget trees, and
`lib/shell_search_provider.rb`'s term-parsing branches were **not**
independently re-verified on the CSS/signal axes in this round. The passing
drive scripts (see `test-parity.md`) give behavioral confidence for the paths
they exercise, but a passing behavioral check is not the same claim as a
verified CSS-class/signal inventory — a button could respond to `clicked` and
still be missing a CSS class the scan would have caught. **Treat these units
as unverified on those axes, not as confirmed parity.**

## Rules followed

- No app-wide total is reported as "parity" — findings are per unit, per
  widget, per axis.
- The CSS-typo divergence and the accelerator-bug fix are both named,
  located by file:line, and recorded as correspondences/divergences rather
  than silently folded into "parity" or silently treated as gaps.
- Every text-axis gap found here is cross-filed in `translation-parity.md`
  against the same message, per the skill's rule that a text gap is recorded
  in both ledgers.
- The prior `.reports/component-inventory.md`'s factual error about
  `Settings`'s superclass is named and corrected rather than repeated.

## Re-audit, 2026-11-07, against `ruby` @ `0594500`

Text axis: cross-filing `translation-parity.md`'s re-audit, 184 of 185
upstream messages now carry a byte-identical, correctly-marked counterpart
in the corresponding `lib/*.rb` file (the remaining row is explained there,
not a real gap). This closes essentially all of the text-axis gaps the
original `translation-parity.md` pass had opened against this document's
units. Two exceptions carried over as open component gaps, not translation
gaps:

- **`data/applications/io.github.idevecore.Valuta.desktop`** has no
  per-language `Comment[xx]=`/`Name[xx]=` entries. Upstream builds this file
  via `i18n.merge_file(... type: 'desktop' ...)` at package time; the port
  has no equivalent build step and ships a static, English-only file. This
  is a missing **mechanism** (a desktop-file merge/generation step), not a
  missing translation — the string is in the catalogue and translated in
  all 33 `.po` files. Gap, component axis.
- **`lib/i18n.rb`'s `DOMAIN` constant** (`io.github.idevecore.Valuta`) does
  not match upstream's actual gettext domain (`valuta`, per
  `meson.build:1`/`po/meson.build:1`/`src/valuta.in:38-39`). The port is
  internally self-consistent (verified: German-locale strings render
  correctly end to end under the port's own, differently-named domain), so
  this is not a behavioural gap a user can observe today, but it is a real
  divergence from upstream's naming and the stated rationale in
  `lib/i18n.rb`'s own comment is factually wrong about what the constant is
  set to. See `translation-parity.md`'s "Domain mismatch" section for the
  full trace.

No other widget/CSS/signal axis in the units already covered above changed
between the two commits since the prior pass (`f9bbc76`, `0594500`) touched
translation wiring and test coverage, not widget trees. The open items from
the prior pass — `lib/currency_selector_row.rb`, the full
`convertion_page.rb` tree, and `lib/shell_search_provider.rb`'s
term-parsing branches, all listed as not independently re-verified on the
CSS/signal axes — remain open; this re-audit did not have scope to redo that
work and is not claiming to.

## Re-audit, 2026-11-07, against `ruby` @ `c8dcd6c`

Only one commit landed since the prior pass (`c8dcd6c`), scoped to
`Rakefile` and `lib/i18n.rb`. **The domain-mismatch item listed above is
closed**: `lib/i18n.rb:22` is now `DOMAIN = 'valuta'`, matching upstream
(full trace in `translation-parity.md`'s re-audit). This was a text/
mechanism-axis divergence, not a widget/CSS/signal one, so it does not
change any row of the per-unit tables above.

**Still open, unchanged:** the desktop-file merge step
(`data/applications/io.github.idevecore.Valuta.desktop` has no
per-language `Name[xx]=`/`Comment[xx]=` sections; re-verified this round,
file unchanged by `c8dcd6c`) and every "not independently re-verified this
round" item from the prior two passes — `lib/currency_selector_row.rb`,
the full `convertion_page.rb` widget tree, `lib/shell_search_provider.rb`'s
term-parsing branches, and the settings mechanism's lack of a real
installed GSettings schema (so no `gsettings`/`dconf-editor`/GNOME Settings
visibility, still true, still unverified beyond the in-app path). None of
these were touched by the one commit in scope this round, and none were
re-derived from scratch in this pass either — they remain **unverified**,
not newly confirmed, consistent with this skill's own rule against treating
silence as a pass.

## Re-audit, 2026-11-08, against `ruby` @ `9df781b`

Two commits landed since the prior pass: `49474ac` (desktop-file
translations, `Requests` unit specs, an inventory-claim fix) and `9df781b`
(drives the `convertion-error` stack page and its reload button).

**Desktop-file merge step: mostly closed.** Re-verified directly — the file
now carries 29 `Comment[xx]=` lines (was 0 at the prior pass). This closes
the "no per-language entries at all" framing above; it is not full closure.
Full detail, including the one remaining locale (`nb_NO`) that upstream
translates and the port's file still omits, is in
`translation-parity.md`'s 2026-11-08 section — not re-derived here to avoid
drifting out of sync with that document's numbers.

**`convertion_page.rb`'s error-page path: now behaviourally driven.**
`test/drive_convertion.rb` (via `9df781b`) stubs `Requests#get` to return
the failure-string shape the real class returns on a network error, forces
a real (non-cached) conversion, and asserts the `Gtk.Stack` shows
`convertion-error`, that a reload button is visible, that activating it
retries over the real network, and that the stack returns to `result`. This
confirms **count and behaviour** for that one stack page and its button,
which were previously entirely undriven (every prior pass's "not
independently re-verified" list included this page). **Style (CSS classes
on the error page / reload button) and text (any label on that page) are
still not independently checked** — the new drive checks assert
`visible_child_name` and button visibility, not CSS classes or label text —
so this unit moves from "untested" to "behaviourally tested, style/text
axis still open," not to full 4-axis parity.

**Correction filed above, re-stated for the changelog:** the "text-axis gap"
rows for `window` and `shortcuts` earlier in this document were found false
on direct inspection this round (strings are correctly wrapped in `_()`/
`p_()` already) — see the correction note at the top of this file and
`translation-parity.md`'s 2026-11-08 section for the full trace.

**New gap found this round, filed primarily in `test-parity.md`:**
`lib/utils.rb`'s `SEPARATORS` table — the hand-transcribed CLDR
grouping/decimal separators for all 33 locales, replacing upstream's Babel
call — has no test or drive check exercising any locale but the
English/default one. This is a behaviour-axis gap on a component (locale
number formatting) that the runtime gate's 72 checks never touch, not a
widget/CSS gap, so it is recorded fully in `test-parity.md` and only
cross-referenced here.

**Still open, unchanged from the prior pass:** `lib/currency_selector_row.rb`,
the rest of `convertion_page.rb`'s widget tree (style/text axes), the full
`lib/shell_search_provider.rb` term-parsing branches on the style/text axes,
and the settings mechanism's lack of a real installed GSettings schema.
