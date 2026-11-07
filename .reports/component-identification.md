# Component identification — valuta

Scope and method: built on top of the existing `.reports/component-inventory.md`
(file-level mapping, already present on `ruby`), then read the upstream
source/`.blp` for each unit against the corresponding `lib/*.rb` to check
widget type, CSS classes, signals and actions — the five identity facets the
`component-identification` skill requires, not file existence alone. No
`gir-symbols.sh` symbol table was built in this pass (no network access to
confirm GObject-Introspection `.gir` availability in the sandbox beyond what
`nix develop` provides); widget/non-widget classification below is by direct
reading of upstream and port source, file by file, which is slower but is the
fallback the skill itself names when no symbol table exists.

## Units, upstream → port, read in this pass

| Upstream unit | Port file | Read in this pass? |
|---|---|---|
| `src/window.py` + `src/window.blp` | `lib/window.rb` | Yes — full read, see notes |
| `src/components/shortcuts/*` | `lib/shortcuts.rb` | Yes — full read |
| `src/assets/style.css` | `lib/style.rb` | Yes — diffed directly |
| `src/actions.py` | `lib/actions.rb` | Yes — full read |
| `src/utils.py::Settings` | `lib/settings.rb` | Yes — full read |
| `src/components/currency_selector/*` | `lib/currency_selector.rb` | Partial — spot-checked (CSS class resolution only) |
| `src/pages/convertion/*` | `lib/convertion_page.rb` | Partial — read for strings/structure, not driven widget-by-widget here (covered by the drive script instead) |
| `src/search_provider/*` | `lib/shell_search_provider.rb` | Not re-read beyond prior inventory + the drive script's behavioral coverage |
| `src/about.py` | `lib/about_dialog.rb` | Partial — spot-checked for text axis only |
| `src/utils.py::CurrencyObject`, `CurrenciesListModel`, `Convertion` | `lib/currency_object.rb`, `lib/currencies_list_model.rb`, `lib/convertion.rb` | Not re-read beyond prior inventory |
| `src/requests.py` | `lib/requests.rb` | Not re-read beyond prior inventory |
| `src/define.in` | `lib/define.rb` | Not re-read (1146-line generated data table; prior inventory confirms existence, not re-verified cell by cell) |
| Packaging (`.desktop.in.in`, `.appdata.xml.in.in`, `.gschema.xml.in`, icons) | `data/` | Yes — the gaps below come from this |

**This is a partial component-identification pass, not an exhaustive one.**
`lib/currency_selector_row.rb`, the full `convertion_page.rb` widget tree
(three preference groups, the stack states), and `shell_search_provider.rb`'s
term-parsing branches were not independently re-verified widget-by-widget in
this round beyond what the existing `.reports/component-inventory.md` and the
passing drive scripts already establish. Treat those three files as
**unverified on the CSS/signal axes**, not confirmed — the drive scripts
exercise behavior, not a widget/CSS/signal inventory.

## What this pass found, beyond the prior file-level inventory

### `lib/window.rb` — matches upstream on widget/CSS/signal/action axes

`Adw.ApplicationWindow` (built via `Adwaita::ApplicationWindow.new(application)`
composition, not subclassing — a documented bindings correspondence, see the
file's own comment), `Adw.ToolbarView`, `Adw.HeaderBar`, one `Gtk.MenuButton`
(`primary: true`, `open-menu-symbolic`, tooltip "Main menu"), one
`Adw.Bin` content area, one `Gtk.Box` bottom toolbar (`toolbar` CSS class,
`halign: center`, 6px top/bottom margins) holding one `Gtk.Label` (`dim-label`)
and one `Gtk.LinkButton` (hidden until a conversion lands). The primary menu
(`Gio::Menu`) reproduces both sections and all four items
(`window.providers::ecb`, `win.show-help-overlay`, `app.about`) with the same
action/target pairs as `window.blp`'s `menu primary_menu`. `window` action
group with `providers` action from `Settings#create_action`; `show-help-overlay`
registered as a plain `win` action rather than via `Gtk.Window.set_help_overlay`
(upstream's mechanism), which is the one structural divergence — correctly
flagged in the file's own comment as a bindings limitation
(`Gtk::ShortcutsWindow` cannot be constructed from these bindings).

### `lib/shortcuts.rb` — one real structural correspondence, one real text-axis gap

Upstream: `template $Shortcuts : ShortcutsWindow` with one `ShortcutsSection`,
one `ShortcutsGroup` titled `C_("shortcuts window", "General")`, three
`ShortcutsShortcut`s. Port: `Adwaita::ShortcutsDialog` (not
`Gtk::ShortcutsWindow`) with one `Adwaita::ShortcutsSection` titled `'General'`
and three `Adwaita::ShortcutsItem`s bound by `action_name`. Structurally this
is a faithful 1:1 substitution, correctly documented in the file's header
comment as forced by a binding limitation (`Gtk::ShortcutsWindow.new` raises
`"GtkWindow is not subtype of GtkShortcutsWindow"`). **The text axis is a gap
independent of the widget substitution**: all four strings (`General`,
`Keyboard shortcuts`, `Switch currencies`, `Quit`) are upstream `C_("shortcuts
window", ...)` calls and are bare literals in the port — see
`translation-parity.md`.

### `lib/style.rb` — the stylesheet itself is byte-identical; one class-name divergence is real behavior

Diffed `lib/style.rb`'s heredoc against `src/assets/style.css` directly: every
rule is reproduced verbatim (`.pd`, `.rounded`, `.text-light`, `.f-l`,
`.bg-accent-color`, `.top-transform`, `.large-button`, `.search-box`,
`.currency-selector list/row/separator`, `.link`), plus the two
`@define-color` overrides for `accent_color`/`accent_bg_color`, correctly
reproduced from libadwaita's named-palette hex values since the newer
palette-as-custom-properties change means the named colors can't just be
referenced. This axis is clean.

**However**: upstream's `src/components/currency_selector/index.blp:30` applies
the CSS class `"curency-selector"` (upstream's own typo — missing the first
`r`) to the selector popover, which means **upstream's own popover never
matches its own `.currency-selector list/row/separator` rules** — a real
upstream bug. `lib/currency_selector.rb:159-167` applies the correctly spelled
`'currency-selector'` class instead, with a comment explaining the fix. **This
means the port's popover renders with different padding/margins than
upstream's actually does**, which is a real, user-visible rendering
divergence from what upstream ships today — not a bug fix that happens for
free, but a deliberate, documented behavior change. It is very likely the
*intended* behavior and the right call, but `component-parity.md` records it
as a flagged divergence rather than silently treating the CSS axis as clean,
because strict byte-for-upstream-byte parity does not hold here.

### Packaging/data — real, unflagged-as-excused gaps

- `data/applications/io.github.idevecore.Valuta.desktop` exists and matches
  upstream's generated `.desktop` content, but is a plain static file with no
  translated `Name[xx]=`/`Comment[xx]=` sections, where upstream's
  `.desktop.in.in` is `msgfmt --desktop`-processed against all 33 languages.
- **No AppStream metainfo file exists in the port at all.** Upstream ships
  `data/io.github.idevecore.Valuta.appdata.xml.in.in` with a translated
  `<summary>` and `<description>`. There is no `data/metainfo/` directory, no
  `.appdata.xml`, no `.metainfo.xml` anywhere in the port. This is a missing
  component, not a text-axis nit on an existing one.
- **No GSettings schema file is installed.** `lib/settings.rb` replaces
  `Gio.Settings` entirely with a hand-rolled JSON-file store (see
  `component-parity.md` for why this matters beyond labeling).

### A factual correction to the existing `.reports/component-inventory.md`

`.reports/component-inventory.md:26` describes `lib/settings.rb` as:

> Thin subclass of `Gio.Settings` keyed on the app id.

This is **not what the code does**. `lib/settings.rb:22` declares
`class Settings` with no superclass at all — it is a hand-written JSON-file
store under `XDG_CONFIG_HOME`, with its own `get_string`/`get_enum`/`[]=`/
`create_action`/`bind`-equivalent methods, explicitly *not* a `Gio::Settings`
subclass. The file's own comment (`lib/settings.rb:9-16`) says exactly this
and gives a real reason (no install-time schema compilation step needed to
run from a checkout). The design choice is reasonable and well-documented in
the code — but the earlier inventory report describes the wrong class
hierarchy, which is exactly the kind of small inaccuracy that compounds if
nobody rereads the source behind a summary table. See
`accountability-ensurance.md`.

## Re-audit, 2026-11-07, against `ruby` @ `0594500`

Two units in scope here changed state since the prior pass:

- **`data/metainfo/io.github.idevecore.Valuta.metainfo.xml.in`** now exists
  (it did not at the time of the prior pass). Diffed directly against
  upstream's `data/io.github.idevecore.Valuta.appdata.xml.in.in`: identical
  apart from `@app-id@` build-time tokens resolved to the literal app ID —
  a correspondence per the skill's rule on build-time tokens, not a gap.
- **`lib/i18n.rb` + `lib/define.rb`'s `Define` module** are new units this
  pass identifies that did not exist before `f9bbc76`. `Define` now
  `extend`s `I18n`, and every one of the 160 `CODES` currency names is built
  through `_('<name>')` rather than a bare string literal — a behavioural
  change to a unit the prior pass had already inventoried structurally.

No other unit in `lib/` changed shape (widget types, CSS classes, signals)
between the two passes; `0594500` only added test coverage, not new widgets.
The two components not independently re-verified widget-by-widget in the
prior pass — `lib/currency_selector_row.rb` and the full
`convertion_page.rb` widget tree — remain **unverified on the CSS/signal
axes** in this pass too; nothing in the two intervening commits touched
them, and this audit did not re-derive the widget scan from scratch given
the time available. Treat that finding as still open, not newly closed.
