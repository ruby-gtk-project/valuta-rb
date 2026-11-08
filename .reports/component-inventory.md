# valuta-rb — component inventory

Upstream is `origin/main` (PyGObject + Blueprint). Survey only — no app code
was written for this report. Per-file component scan, cross-referenced
against the `.blp` templates (which are the authoritative widget trees) and
the `ruby` branch's `lib/`.

Upstream source (`git ls-tree -r --name-only origin/main`, app-relevant subset):

```
src/about.py
src/actions.py
src/application.py
src/components/currency_selector/currency_selector.py
src/components/currency_selector/index.blp
src/components/currency_selector_row/currency_selector_row.py
src/components/currency_selector_row/index.blp
src/components/shortcuts/shortcuts.py
src/components/shortcuts/shortcuts.blp
src/define.in
src/main.py
src/pages/convertion/convertion.py
src/pages/convertion/index.blp
src/requests.py
src/search_provider/search_provider.in
src/utils.py
src/window.py
src/window.blp
data/io.github.idevecore.Valuta.gschema.xml.in
src/valuta.gresource.xml
po/*.po (33 locales) + po/io.github.idevecore.Valuta.pot
```

Overall result: **every upstream file that contributes a component already
has a corresponding `lib/*.rb` on `ruby`, and every one of them carries a
"Ported from upstream's ..." header naming its source.** This is a mature
port, not a fresh scaffold — the table below is a parity check, not a to-do
list. Translations (`po/*.po`) are already present and wired on this branch
(see the Notes section and `.reports/translation-parity.md`, which this
report cross-references rather than restates).

## Window — the application window

**Upstream:** `src/window.py` + `src/window.blp` → **Port:** `lib/window.rb` — exists

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | `close-request` | built from the `Gtk::Application` by composition in the port, since subclassing fails on these bindings (noted in `window.rb`) |
| `Adw.ToolbarView` | 1 | — | — | top bar = header, content = conversion page bin, bottom bar = status toolbar |
| `Adw.HeaderBar` | 1 | — | — | packs the menu button at the end |
| `Gtk.MenuButton` | 1 | — | — | `primary: true`, `menu-model: primary_menu`, icon `open-menu-symbolic` |
| `Adw.Bin` (content) | 1 | — | — | holds the conversion page; swapped by `load_convertion_page` |
| `Gtk.Box` (status bar) | 1 | `toolbar` | — | horizontal, centered, holds info label + source link |
| `Gtk.Label` (info) | 1 | `dim-label` | — | rate-date status text |
| `Gtk.LinkButton` (source) | 1 | — | — | starts `visible: false`; shown once a conversion lands, links to the provider's disclaimer URL |
| menu `primary_menu` | 1 | — | — | Providers section (1 radio item, `window.providers::ecb`) + shortcuts/about section |

Actions installed/targeted here: `window.providers` (via `Gio::SimpleActionGroup` + `Settings#create_action`), `win.show-help-overlay` (built here since the GTK4 Ruby bindings cannot construct `Gtk::ShortcutsWindow`; presents an Adwaita dialog instead), targets `app.about`.

Repeaters: none. Conditional: `source` link button only visible after first successful conversion.

## ConvertionPage — the amount/currency conversion page

**Upstream:** `src/pages/convertion/convertion.py` + `index.blp` → **Port:** `lib/convertion_page.rb` — exists

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToastOverlay` | 1 | — | — | root; shows the "Error converting" toast |
| `Gtk.Box` | 1 | — | — | vertical, `valign: center` wrapper |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` ("From") | 1 | — | — | header-suffix hosts the from-currency selector |
| `Gtk.Entry` (from_currency_entry) | 1 | `f-l` | `changed` | numeric input-purpose; drives `convert` |
| `Adw.PreferencesGroup` (switch) | 1 | — | — | centered |
| `Gtk.Button` (invert_currencies) | 1 | `circular`, `pd` | action `app.switch-currencies` | no explicit `clicked` handler — fires the action directly |
| `Adw.PreferencesGroup` ("To") | 1 | `top-transform` | — | header-suffix hosts the to-currency selector |
| `Adw.Bin` (result wrapper) | 1 | `f-l`, `text-light`, `bg-accent-color`, `rounded` | — | |
| `Gtk.Stack` | 1 | — | — | 3 pages: result / loading / convertion-error |
| `WindowHandle` ×3 | 3 | — | — | one per stack page |
| `Gtk.Label` (to_currency_entry) | 1 | — | — | selectable, result text |
| `Gtk.Box` (loading) | 1 | — | — | centers the spinner |
| `Gtk.Spinner` | 1 | — | `spinning: true` | |
| `Gtk.Box` (error) | 1 | — | — | centers the reload button |
| `Gtk.Button` (reload) | 1 | `circular` | `clicked` | retries the conversion |
| `CurrencySelector` (from) | 1 | — | `notify::selected` | own component, see below |
| `CurrencySelector` (to) | 1 | — | `notify::selected` | own component, see below |

Behaviour wired at this level: `Gio.Task`-backed background fetch (port note: "fetched off the main thread, as upstream does with a Gio.Task"), `settings.connect("changed::providers"/"changed::src-currency"/"changed::dest-currency"/"changed::high-precision")`, `convertion.connect("converted")`.

Repeaters: none (fixed 3-page stack). Conditional: stack page selection is state-driven (loading / result / error), not a widget presence gap.

## CurrencySelector — the popover currency picker (used twice, from/to)

**Upstream:** `src/components/currency_selector/currency_selector.py` + `index.blp` → **Port:** `lib/currency_selector.rb` — exists

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | `notify::selected` → `_on_selected_changed` | |
| `Gtk.MenuButton` | 1 | `rised`, `flat` | — | `always-show-arrow: true` |
| `Gtk.Box` (button child) | 1 | — | — | spacing 3 |
| `Gtk.Label` (label) | 1 | — | — | ellipsize end |
| `Gtk.Label` (insight) | 1 | — | — | ellipsize end; shows "(name)" when `selected == 'auto'` |
| `Gtk.Popover` | 1 | `curency-selector`, `menu` | `show` → `_popover_show`; `closed` → `_popover_closed` | 300×300 |
| `Gtk.Box` (popover body) | 1 | — | — | vertical |
| `Gtk.Box` (search_box) | 1 | `search-box` | — | |
| `Gtk.SearchEntry` | 1 | — | `changed` → `_on_search`; `activate` → `_on_search_activate` | |
| `Gtk.ScrolledWindow` | 1 | — | — | `vexpand: true` |
| `Gtk.ListBox` (currency_list) | 1 | — | `row-activated` → `_activated` | `selection-mode: single`; bound to a filtered/sorted model |
| `Gtk.EventControllerKey` | 1 (controller) | — | `key-pressed` | Escape closes popover, Down stops propagation — attached to `search` |
| `Gtk.CustomFilter` / `Gtk.CustomSorter` / `Gtk.SortListModel` / `Gtk.FilterListModel` | — | — | — | non-widget model plumbing, not counted as widgets |

Signal: custom `user-selection-changed` GObject signal emitted from `_activated`.

Repeaters: `currency_list` rows are built one `CurrencySelectorRow` per filtered/sorted model item via `bind_model`/`create_currency_row` — a repeater, not a fixed count.

## CurrencySelectorRow — one row in the currency popover's list

**Upstream:** `src/components/currency_selector_row/currency_selector_row.py` + `index.blp` → **Port:** `lib/currency_selector_row.rb` — exists

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (template root) | 1 | — | — | holds `currency` (a `CurrencyObject`) |
| `Gtk.Box` | 1 | — | — | spacing 6 |
| `Gtk.Label` (name) | 1 | — | — | `"{code} – {truncated name}"`, truncated to 30 chars with `...` |
| `Gtk.Image` (selection) | 1 | — | — | `object-select-symbolic`, visibility bound (`GObject.BindingFlags.SYNC_CREATE`) to `currency.selected` |

Repeaters: none per-row (this *is* the repeated unit, counted at the `CurrencySelector` level).

## Shortcuts — the keyboard shortcuts window

**Upstream:** `src/components/shortcuts/shortcuts.py` + `shortcuts.blp` → **Port:** `lib/shortcuts.rb` — exists

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ShortcutsWindow` (template root) | 1 | — | — | `modal: true`; port note says GTK4 Ruby bindings can't construct this directly, builds an Adwaita dialog substitute instead — see `window.rb`'s `show_help_overlay_action` |
| `Gtk.ShortcutsSection` | 1 | — | — | `max-height: 10` |
| `Gtk.ShortcutsGroup` ("General") | 1 | — | — | |
| `Gtk.ShortcutsShortcut` | 3 | — | — | Keyboard shortcuts / Switch currencies / Quit, each bound to an action name (`win.show-help-overlay`, `app.switch-currencies`, `app.quit`) rather than an accelerator string |

Repeaters: none (fixed 3 shortcuts).

## AboutDialog — the app.about dialog

**Upstream:** `src/about.py` → **Port:** `lib/about_dialog.rb` — exists

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.AboutDialog` | 1 | — | — | app name, icon, developer/designer credits, issue URL, debug info block (app id/version, OS info, bindings version, Adw/Gtk/GLib versions, Flatpak info), `Gtk.License.GPL_3_0` |

## Application — the app singleton, actions and accelerators

**Upstream:** `src/application.py` (window/app lifecycle) + `src/actions.py` (actions) → **Port:** `lib/application.rb` + `lib/actions.rb` — both exist

| Item | Kind | Notes |
|---|---|---|
| `Adw.Application` | type (owner) | `--src-currency-value` CLI option, `do_activate`/`do_command_line` lifecycle, singleton active-window reuse |
| `app.quit` | action | accel `<primary>q`, `<primary>w` (port fixes upstream's accidental accel overwrite — see `actions.rb` comment) |
| `app.about` | action | presents `AboutDialog` |
| `app.switch-currencies` | action | accel `<primary>s`; swaps `src-currency`/`dest-currency` settings |
| `win.show-help-overlay` | accel only (`<Primary>question`) | action itself is installed per-window in `window.rb` |

## Settings / Convertion / Requests / CurrenciesListModel / CurrencyObject / Utils / Style / Define / I18n — non-widget support

These carry no on-screen components of their own (GSettings wrapper, HTTP
client, list model, data object, number formatting, CSS provider,
compile-time constants, gettext binding) but are components' *dependencies*
and are already ported 1:1:

| Upstream | Port | Exists |
|---|---|---|
| `data/io.github.idevecore.Valuta.gschema.xml.in` + `Settings` in `src/utils.py` | `lib/settings.rb` | yes |
| `Convertion` class in `src/utils.py` | `lib/convertion.rb` | yes |
| `src/requests.py` | `lib/requests.rb` (uses `soup3`'s `Soup::Session`/`Soup::Message` — see Notes) | yes |
| `CurrenciesListModel` in `src/utils.py` | `lib/currencies_list_model.rb` | yes |
| `CurrencyObject` in `src/utils.py` | `lib/currency_object.rb` | yes |
| `Utils` class in `src/utils.py` | `lib/utils.rb` | yes |
| `src/assets/style.css` | `lib/style.rb` | yes |
| `src/define.in` (CODES table + constants) | `lib/define.rb` | yes |
| gettext setup in `src/define.in` | `lib/i18n.rb` | yes |
| `src/main.py` | `lib/main.rb` | yes |

## ShellSearchProvider — the GNOME Shell search provider D-Bus service

**Upstream:** `src/search_provider/search_provider.in` (+ `.ini`/`.service.in`/`meson.build`) → **Port:** `lib/shell_search_provider.rb` — exists

Not a widget component (no GTK on this path) but a user-facing surface
(Shell search results: initial/subsearch result sets, result metas,
activate/launch-search, clipboard-copy result). D-Bus interface
`org.gnome.Shell.SearchProvider2`, methods `GetInitialResultSet`,
`GetSubsearchResultSet`, `GetResultMetas`, `ActivateResult`, `LaunchSearch`.
Confirmed present in `lib/shell_search_provider.rb` with a "Ported from the
ConvertionService class in upstream's ..." header.

## GResource manifest

`src/valuta.gresource.xml` lists `window.ui`, the three component `.ui`s, the
conversion page `.ui`, the stylesheet, and 7 symbolic icon SVGs. All of it
maps onto widgets/CSS already inventoried above; the icons
(`arrow1-{up,down}`, `code`, `dark-mode`, `help-about`, `refresh-large`,
`sonar`, `vertical-arrows`) back icon-name references already used (e.g.
`refresh-large-symbolic` on the reload button, `vertical-arrows-symbolic` on
invert_currencies).

## Notes

- **`soup3` gem.** `lib/requests.rb` already `require`s `soup3` and drives
  `Soup::Session`/`Soup::Message` on the live HTTP path (the ECB rate fetch).
  The gemspec declares `spec.add_dependency("soup3")`. Nothing in `lib/`
  hand-rolls an HTTP client in its place. This wiring was not regressed.
- **Translations (`po/*.po`, 33 locales + the `.pot`).** The `ruby` branch
  already carries its own `po/` directory (all 33 upstream locales plus the
  `.pot`), and `lib/i18n.rb` binds the gettext domain to `valuta` — matching
  upstream's own domain (fixed in commit `c8dcd6c`, after an earlier mismatch
  against the app id). `.reports/translation-parity.md` documents 184/185
  messages ported and the domain fix independently verified (rebuilt `.mo`
  files, `LANGUAGE=de` renders translated strings). This inventory does not
  restate that work further; see that report for the authoritative state.
- **No gap found.** Every upstream file that owns a component already has a
  corresponding, correctly-attributed `lib/*.rb`. This survey found no
  missing component to scaffold. If a later pass finds a behavioural gap
  (signal not wired, CSS class not applied, dynamic class value missing),
  that is `component-parity` work, not `component-identification` work.
