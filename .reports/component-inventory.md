# Valuta — upstream component inventory

Upstream: `origin/main` (Python + PyGObject + blueprint, GTK4/Libadwaita).
Port: `ruby` branch, `lib/`.

Surveyed with the `component-identification` skill. Every `.blp` was read as the
authority for the widget tree, CSS classes and signals; every `.py` was read for
what the blueprint cannot show (runtime widgets, dynamic classes, actions,
repeaters). `scripts/component-scan.sh` was run over a `git archive` of
`origin/main` and its rows are folded in below.

Valuta is a small app: **one window, one page, two list components, one
shortcuts window, one about dialog, one GNOME Shell search provider.** The
widget total upstream is ~40 rows across 6 declarative/source unit pairs.

## State of the port

`lib/` on `ruby` contains only the gem skeleton:

| Path | What it is |
|---|---|
| `lib/valuta.rb` | `require_relative "valuta/application"` |
| `lib/valuta/application.rb` | the kettle-jem stub — `Gtk::Application`, `Adwaita::ApplicationWindow`, one `Adwaita::StatusPage` reading "The Ruby port has not been written yet." |
| `lib/valuta/rb/version.rb` | version constant |

**No user-facing component is ported.** Everything below is missing.

## House shape for the targets

Following the pilot at `gnome-contacts-rb`: the port proper lives in flat
`lib/<thing>.rb` files with top-level classes, `lib/main.rb` is the entry unit,
and the gem stub `lib/valuta/application.rb` stays as packaging plumbing.
One upstream `.py` + its sibling `.blp` collapse into one `lib/*.rb`.

---

## src/application.py — the application singleton → `lib/application.rb`

Kind: **application**. Present: **no**.

`Adw.Application` subclass with `HANDLES_COMMAND_LINE`, `resource_base_path`
`/io/github/idevecore/Valuta` (this is what auto-loads `style.css` — nothing
calls `Gtk.CssProvider` anywhere in the tree, so the Ruby port must load the
stylesheet explicitly).

| Facet | Detail |
|---|---|
| Widgets | none of its own |
| Actions installed | via `actions.py` (below) |
| Command line | `--src-currency-value` (`t`, string) — a value to pre-fill the From entry |
| Behaviour | `do_activate` presents the existing window or builds one; `do_command_line` forwards the value to `window.load_convertion_page` and re-activates |

Bug upstream: `Application.__init__` calls `Adw.ApplicationWindow.__init__` on
itself. Works by accident in PyGObject; do not reproduce.

## src/main.py — launcher → `lib/main.rb`

Kind: **entry point**. Present: **no**. One line: `Application().run(sys.argv)`.

## src/actions.py — application actions and accelerators → `lib/actions.rb`

Kind: **actions**. Present: **no**.

| Action | Accel | Does |
|---|---|---|
| `app.quit` | `<primary>w` | `application.quit()` |
| `app.about` | — | presents the About dialog on the active window |
| `app.switch-currencies` | `<primary>s` | swaps the `src-currency` / `dest-currency` GSettings keys |
| `win.show-help-overlay` | `<Primary>question` | GTK's built-in, shows the shortcuts window |

Bug upstream to decide on deliberately: `set_accels_for_action('app.quit', ...)`
is called twice, so `<primary>q` is **overwritten** by `<primary>w` and Ctrl+Q
does not quit. The shortcuts window still advertises Quit. A faithful port
either reproduces the bug or fixes it and says so.

## src/window.py + src/window.blp — the main window → `lib/window.rb`

Kind: **window**. Present: **no** (the stub window is not this).

`Adw.ApplicationWindow window`, `width-request: 350`, `height-request: 300`,
`default-width: 420`, `default-height: 600`, title `_("Valuta")`.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | — | `set_icon_name(app_id)`; `set_help_overlay(Shortcuts())` |
| `Adw.ToolbarView` | 1 | — | — | content shell |
| `Adw.HeaderBar` | 1 | — | — | `[top]` bar |
| `Gtk.MenuButton` `menu_button` | 1 | — | `menu-model: primary_menu` | `[end]`, `primary: true`, `open-menu-symbolic`, tooltip `_("Main menu")` |
| `Adw.Bin` `content` | 1 | — | — | the page host; `load_convertion_page` swaps its child |
| `Gtk.Box` | 1 | `toolbar` | — | `[bottom]`, horizontal, halign center, margin-top/bottom 6 |
| `Gtk.Label` `info` | 1 | `dim-label` | — | set to `"<date> -" `on `converted` |
| `Gtk.LinkButton` `source` | 1 | (`link` in style.css) | — | tooltip `_("Source")`, `visible: false` until a conversion lands, then label = provider name upper-cased, uri = `disclaimer` |

Behaviour, none of it in the blueprint:
- GSettings binds, `Gio.SettingsBindFlags.DEFAULT`: `width`→`default-width`,
  `height`→`default-height`, `is-maximized`→`maximized`,
  `is-fullscreen`→`fullscreened`.
- Installs action group `window` holding `settings.create_action('providers')`
  — this is what the Providers radio section in the menu targets.
- Subscribes to the `Convertion` object's `converted` event to fill `info` and
  reveal `source`.
- Dead code: `string_to_color` and the `open_uri` helper are defined and never
  used; there is no colour-scheme setting in the schema.

### `menu primary_menu` (inside src/window.blp) → folded into `lib/window.rb`

Kind: **menu model**. Present: **no**.

| Section | Item | Action | Target |
|---|---|---|---|
| `_("Providers")` → nested section | `_("ECB")` | `window.providers` | `ecb` |
| (second section) | `_("Keyboard shortcuts")` | `win.show-help-overlay` | — |
| | `_("About Valuta")` | `app.about` | — |

Only one provider exists; the nested radio section still has to be built so a
second provider drops in.

## src/pages/convertion/convertion.py + index.blp — the conversion page → `lib/convertion_page.rb`

Kind: **page**. Present: **no**. This is the whole app's UI.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | — | the page root; also the error surface |
| `Gtk.Box` | 1 | — | — | vertical, valign center |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` (From) | 1 | — | — | title `_("From")`, margins 24/24/20, `header-suffix` box holding `$CurrencySelector from_currency_selector` |
| `Gtk.Entry` `from_currency_entry` | 1 | `f-l`, **`error` (dynamic)** | `changed` → convert | xalign .50, height-request 70, `input-purpose: number`; `error` added when the text does not parse as a number in the current locale, removed when it does |
| `Adw.PreferencesGroup` (switch) | 1 | — | — | halign/valign center |
| `Gtk.Button` `invert_currencies` | 1 | `circular`, `pd` | `action-name: app.switch-currencies` | icon `vertical-arrows-symbolic`, tooltip `_("Switch")` |
| `Adw.PreferencesGroup` (To) | 1 | `top-transform` | — | title `_("To")`, margins 24/24 |
| `Gtk.Box` (To header-suffix) | 1 | — | — | holds `$CurrencySelector to_currency_selector` |
| `Adw.Bin` | 1 | `f-l`, `text-light`, `bg-accent-color`, `rounded` | — | the green result plate |
| `Gtk.Stack` `stack` | 1 | — | — | `transition-type: crossfade`; three pages, see below |
| `Gtk.WindowHandle` | 3 | — | — | one per stack page, so the plate drags the window |
| `Gtk.Label` `to_currency_entry` | 1 | — | — | page `result`; selectable, xalign .50, height-request 70 |
| `Gtk.Spinner` | 1 | — | — | page `loading`; spinning, 25×25 |
| `Gtk.Button` `reload` | 1 | `circular` | `clicked` → re-convert | page `convertion-error`; icon `refresh-large-symbolic`, tooltip `_("Reload")` |
| `Adw.Toast` | 1 (runtime) | — | — | `_("Error converting, please try again.")` on a failed conversion |

Stack pages — **the three states that are the app's whole error/empty story**:
`result`, `loading` (shown while a `Gio.Task` thread is in flight and on every
provider change), `convertion-error` (plus the toast).

Repeaters: two `CurrencySelector`s, each bound to a `CurrenciesListModel` of
the currencies whose `providers` field contains the active provider index.
With ECB (`0`) that is ~30 of the 160 codes.

Behaviour to reproduce:
- `load_currencies(provider)` rebuilds both models; if either stored currency
  is not offered by the provider, resets to `USD`/`EUR`.
- `convert` parses with the locale (babel `parse_decimal`), formats with
  `format_number`, short-circuits when the cached conversion already matches
  from/to/provider unless `force`.
- Signals: `from_currency_entry::changed`, both selectors'
  `notify::selected`, `reload::clicked`, the convertion object's `converted`,
  and GSettings `changed::providers`, `changed::src-currency`,
  `changed::dest-currency`, `changed::high-precision`.
- **`changed::high-precision` has no key in the GSettings schema** — a dead
  subscription upstream. Do not invent the key; note it and move on.
- Initial text is the `--src-currency-value` value if given, else `"1"`.

## src/components/currency_selector/{currency_selector.py,index.blp} — the currency dropdown → `lib/currency_selector.rb`

Kind: **widget (composite)**. Present: **no**. Used twice per page.

`template $CurrencySelector : Adw.Bin`, with a `selected` string GObject
property and its own `user-selection-changed` signal.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | `notify::selected` → `_on_selected_changed` | |
| `Gtk.MenuButton` `button` | 1 | `rised`, `flat` | — | `always-show-arrow`, valign/halign center |
| `Gtk.Box` (button child) | 1 | — | — | spacing 3 |
| `Gtk.Label` `label` | 1 | — | — | the selected code; ellipsize end, xalign 0 |
| `Gtk.Label` `insight` | 1 | — | — | `(Currency Name)`, only ever filled when `selected == 'auto'`; blanked on every selection |
| `Gtk.Popover` `popover` | 1 | **`curency-selector`**, `menu` | `show` → grab focus on search; `closed` → scroll to 0 and clear search | 300×300 |
| `Gtk.Box` | 1 | — | — | vertical |
| `Gtk.Box` `search_box` | 1 | `search-box` | — | |
| `Gtk.SearchEntry` `search` | 1 | — | `changed` → re-run filter; `activate` → activate row 0 | placeholder `_("Search Currencies")`; `set_key_capture_widget(popover)` |
| `Gtk.ScrolledWindow` `scroll` | 1 | — | — | vexpand |
| `Gtk.ListBox` `currency_list` | 1 | — | `row-activated` → popdown, set `selected`, emit `user-selection-changed` | `selection-mode: single`; `bind_model` over a `SortListModel`(name, case-insensitive) wrapped in a `FilterListModel`(`Gtk.CustomFilter`, regex over `"CODE - Name"`, case-insensitive) |

Controller (behaviour, not a widget): `Gtk.EventControllerKey` on the search
entry — `Escape` pops the popover down, `Down` is swallowed (`EVENT_STOP`).

**CSS mismatch worth fixing or at least recording:** the popover carries
`curency-selector` (one `r`) while `style.css` defines `.currency-selector`.
Every `.currency-selector list/row/separator` rule upstream is therefore dead.

Also dead upstream: `set_insight` and the `user-selection-changed` signal are
emitted/defined but nothing connects to them.

## src/components/currency_selector_row/{currency_selector_row.py,index.blp} — one currency row → `lib/currency_selector_row.rb`

Kind: **row**. Present: **no**. One per currency in an open popover.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (template root) | 1 | — | — | holds the `CurrencyObject` |
| `Gtk.Box` | 1 | — | — | spacing 6 |
| `Gtk.Label` `name` | 1 | — | — | `"CODE – Name"`, name shortened to 30 chars with `...` |
| `Gtk.Image` `selection` | 1 | — | — | `object-select-symbolic`, `visible: false`, bound `SYNC_CREATE` to the currency's `selected` property |

The commented-out line shows the flag emoji was dropped from the label; keep it
dropped.

## src/components/shortcuts/{shortcuts.py,shortcuts.blp} — keyboard shortcuts → `lib/shortcuts.rb`

Kind: **window (help overlay)**. Present: **no**.

`Gtk.ShortcutsWindow`, `modal: true`, one `ShortcutsSection`
(`section-name: "shortcuts"`, `max-height: 10`) with one `ShortcutsGroup`
titled `C_("shortcuts window", "General")` and three `ShortcutsShortcut`s:

| Title (msgctxt `shortcuts window`) | Action |
|---|---|
| Keyboard shortcuts | `win.show-help-overlay` |
| Switch currencies | `app.switch-currencies` |
| Quit | `app.quit` |

Note for the port: `Gtk::ShortcutsWindow` is deprecated in GTK 4.18+; the pilot
uses `Adwaita::ShortcutsDialog`. Decide once and record it — the accelerators
shown must still be the ones `lib/actions.rb` actually binds.

## src/about.py — the About dialog → `lib/about_dialog.rb`

Kind: **dialog**. Present: **no**.

`Adw.AboutDialog`: application name `_("Valuta")`, icon = app id, developer
name `Ideve Core`, developers `["Ideve Core"]`, designers
`["Brage Fuglseth https://bragefuglseth.dev"]`, issue url
`https://github.com/ideveCore/valuta/issues`, licence `GPL_3_0`,
copyright `© 2023 Ideve Core`, and a `debug_info` block of eight lines:
app id + version, OS id + version, PyGObject version, Adw major, Gtk major,
GLib version, Flatpak version (read from `/.flatpak-info`, `Instance` →
`flatpak-version`), Blueprint version. The Ruby port's debug block should name
the Ruby bindings and `Gtk::Version` instead (`Gtk::VERSION` does not exist).

## src/utils.py — model and conversion layer → `lib/currency_object.rb`, `lib/currencies_list_model.rb`, `lib/convertion.rb`, `lib/settings.rb`, `lib/utils.rb`

Kind: **model / support** (no widgets). Present: **no**.

| Upstream class | Target | What it is |
|---|---|---|
| `CurrencyObject` | `lib/currency_object.rb` | GObject with `code`, `name`, `selected` properties |
| `CurrenciesListModel` | `lib/currencies_list_model.rb` | a `Gio.ListModel` of `CurrencyObject`s, `set_currencies`, `set_selected`, `items_changed` |
| `Convertion` | `lib/convertion.rb` | the conversion cache + its own hand-rolled `connect`/`converted` event bus; `convert`, `convert_raw`, `match_data`, `get_convertion` |
| `Settings` / `Utils` | `lib/settings.rb`, `lib/utils.rb` | `Gio.Settings` wrapper, locale variants, the `{"0" => "ECB"}` provider table, `format_number` / `parse_number` (babel; Ruby needs an equivalent locale-aware number formatter — **blocker, see below**) |

## src/requests.py — the provider HTTP layer → `lib/requests.rb`

Kind: **network**. Present: **no**.

`Providers` base + `ECB` subclass against
`https://api.frankfurter.app/latest?amount=&from=&to=`, a `Soup.Session`
wrapper, a `Requests` facade, a `providers = {0: ECB}` registry, and
`create_info` formatting the rate date as `"%B %e, %Y"` via `GLib.DateTime`.
The response dict is the contract the page and the window both read:
`base`, `from`, `to`, `amount`, `info`, `disclaimer`, `provider`, `converted`.

## src/define.in — currency table and build-time defines → `lib/define.rb`

Kind: **data**. Present: **no**.

**160 currency entries**, each with a translated `name`, a `flag` emoji, a
`providers` string (`"0,1,2"` — ECB is `0`), a `symbol` and an `about`
Wikipedia url. Also `APP_ID`, `VERSION`, `PROFILE`, `IS_DEVEL`, `RES_PATH`,
`SUFFIX`, `BASE_URL_LANG_PREFIX`, and the `gettext.install` call. The 160
names are the bulk of the translatable strings.

## data/io.github.idevecore.Valuta.gschema.xml.in — GSettings schema → `lib/settings.rb`

Kind: **settings schema**. Present: **no**.

| Key | Type | Default |
|---|---|---|
| `providers` | enum `Window` (`ecb` = 0) | `'ecb'` |
| `width` | i | 420 |
| `height` | i | 600 |
| `is-maximized` | b | false |
| `is-fullscreen` | b | false |
| `src-currency` | s | `'USD'` |
| `dest-currency` | s | `'EUR'` |

No `high-precision` key despite the page subscribing to it.

## src/assets/style.css — the stylesheet → `lib/style.rb`

Kind: **stylesheet**. Present: **no**.

Redefines `accent_color`/`accent_bg_color` to the Adwaita greens, restyles
`selection`, and defines `.pd`, `.rounded`, `.text-light`, `.f-l`,
`.bg-accent-color`, `.top-transform`, `.large-button`, `.search-box`,
`.currency-selector list|row|separator`, `.link`.

Applied upstream: `f-l`, `pd`, `rounded`, `text-light`, `bg-accent-color`,
`top-transform`, `search-box`. **Dead:** `.large-button` (never applied),
`.currency-selector *` (the widget misspells the class), `.link` (only reaches
the `LinkButton` through GTK's own `link` class). Loaded implicitly by
`resource_base_path`; the Ruby port must install a `Gtk::CssProvider` by hand.

## src/search_provider/search_provider.in — GNOME Shell search provider → `lib/shell_search_provider.rb`

Kind: **service (D-Bus)**. Present: **no**.

A `Gio.Application` with `IS_SERVICE` and a 10s inactivity timeout exporting
`org.gnome.Shell.SearchProvider2`: `GetInitialResultSet`,
`GetSubsearchResultSet`, `GetResultMetas`, `ActivateResult`, `LaunchSearch`.

User-facing behaviour: typing a bare number converts it with the stored
currency pair; typing `100 USD to EUR` (4 terms, codes 2nd and 4th) sets the
pair in GSettings first. Results carry `_("Copy")` / `_("Copy convertion to
clipboard")` with `clipboardText`, a description `_("According to") ECB`, and
an error id prefixed `translation-error`. Activating a non-clipboard result
spawns `valuta --src-currency-value <n>`.

Shipped alongside: `io.github.idevecore.Valuta.SearchProvider.ini`
(`Version=2`) and the `.service.in` D-Bus activation file — both are packaging,
targets `data/` in the port.

## src/assets/icons/*.svg — bundled icons → `data/icons/`

Kind: **assets**. Present: **no**.

Eight symbolic icons ship in the GResource. **Used:**
`vertical-arrows-symbolic` (switch button), `refresh-large-symbolic` (reload
button). **Unused upstream:** `arrow1-down`, `arrow1-up`, `code`, `dark-mode`,
`help-about`, `sonar`. Also needed from the system theme:
`open-menu-symbolic`, `object-select-symbolic`.

## src/valuta.gresource.xml — resource manifest → no port target

Kind: **build**. Present: **n/a**. Lists the five compiled `.ui` files, the
stylesheet and the eight icons. The Ruby port has no GResource by design
(widgets are built in code), so this file maps to nothing — but it is the
authoritative list of the five declarative units, and matches the five found
above.

## po/ — translation catalogue → `po/` + a gettext bootstrap

Kind: **i18n**. Present: **no**.

34 locales in `LINGUAS`, a `.pot`, and 17 entries in `POTFILES`. Translatable
strings live in the five `.blp` files, the five `.py` files, `define.in` (the
160 currency names), the appdata, the desktop file and the gschema. Three use
`msgctxt`/`C_("shortcuts window", ...)`. The port needs an equivalent
`gettext` bootstrap and its own POTFILES pointing at `lib/*.rb`; see the
`translation-parity` skill before touching this.

---

## Totals

| | Upstream | `ruby` branch |
|---|---:|---:|
| Declarative units (`.blp`) | 5 | 0 (none by design) |
| Widget rows | ~40 | 4 (the stub) |
| Distinct widget types | 20 | 4 |
| Distinct CSS classes applied | 14 | 0 |
| Distinct signals | ~16 | 1 (`activate`) |
| Actions | 5 (`app.quit`, `app.about`, `app.switch-currencies`, `win.show-help-overlay`, `window.providers`) | 0 |
| Currency entries | 160 | 0 |
| Locales | 34 | 0 |

## Blockers and decisions to settle before writing code

1. **Locale-aware number formatting.** Upstream leans on Python `babel`
   (`format_number`, `parse_decimal`) for both the From entry's parsing and the
   result's formatting, and the `error` CSS class on the entry depends on it.
   Ruby has no drop-in babel. Options: `GLib`/`ICU` via the bindings, the
   `twitter_cldr` gem, or a hand-rolled formatter driven by the locale
   separators. Pick one before `lib/utils.rb`.
2. **`Gtk::ShortcutsWindow` is deprecated** in the GTK the fork builds against.
   The pilot ports the equivalent to `Adwaita::ShortcutsDialog`. Decide and
   record, because `window.set_help_overlay` only accepts the old type.
3. **`Convertion`'s event bus is not GObject signals.** Upstream hand-rolls
   `connect`/`__event`. In Ruby either keep a plain observer list or make it a
   real `GObject` — but the window and the page both subscribe to `converted`,
   so the choice shows up in two files.
4. **Threading.** The conversion runs in a `Gio.Task` worker thread and touches
   widgets from `converted`. The Ruby bindings need the UI work marshalled back
   to the main loop (`GLib::Idle.add`) — do not call widget setters from the
   worker.
5. **The GSettings schema has to be installed** for `Gio::Settings.new(app_id)`
   to work at all; the dev shell needs a compiled schema dir on
   `GSETTINGS_SCHEMA_DIR`, or the port needs a fallback store.
6. **Three upstream bugs**, each needing a conscious port-or-fix call:
   `<primary>q` lost to a duplicated `set_accels_for_action`; the popover's
   `curency-selector` typo killing the stylesheet rules; and the page
   subscribing to a `high-precision` key that does not exist.
7. **Search provider is out of scope for a first pass** but is genuinely
   user-facing (it is how most people hit this app). Schedule it after the
   window and page land, and note it needs D-Bus on the session bus, which the
   `xvfb-run` harness does not give for free.
