# Valuta component inventory

Surveyed against `origin/main` (upstream Python/Blueprint) for the full-parity
port on `ruby`. One row per upstream unit, in the order a user meets it:
application, window, its page, the components the page composes, dialogs,
settings/actions/shell integration, then non-UI support files. No app code
was written for this survey.

| Upstream file(s) | Kind | → `lib/*.rb` | Exists on `ruby`? | Notes |
|---|---|---|---|---|
| `src/main.py` | entry point | `lib/main.rb` | Yes | Builds and runs the `Application`. |
| `src/application.py` | app singleton (`Adw.Application`) | `lib/application.rb` | Yes | `do_activate`/`do_command_line`, owns `Utils`, wires `application_actions`, handles the `--src-currency-value` CLI option for second-invocation hand-off into the already-open window. |
| `src/actions.py` | app-level actions + accels | `lib/actions.rb` | Yes | Installs `app.quit`, `app.about`, `app.switch-currencies`; accels `<primary>q`/`<primary>w` (quit), `<primary>s` (switch), `<Primary>question` (`win.show-help-overlay`). |
| `src/about.py` | dialog (`Adw.AboutDialog`) | `lib/about_dialog.rb` | Yes | App metadata, developers/designers, debug info string, GPL-3.0 license. |
| `src/window.py` + `src/window.blp` | window (`Adw.ApplicationWindow`) | `lib/window.rb` | Yes | `Adw.ToolbarView`: header bar with `menu_button` (primary menu); content bin holding the conversion page; bottom toolbar box with `info` label (dim-label) and `source` `Gtk.LinkButton` (hidden until a conversion lands). Installs the `window` action group (`window.providers` from GSettings) and binds window-state settings (width/height/maximized/fullscreened). `primary_menu`: Providers section (ECB → `window.providers::ecb`), then `win.show-help-overlay` and `app.about`. |
| `src/pages/convertion/convertion.py` + `index.blp` | page | `lib/convertion_page.rb` | Yes | The app's only page. `Adw.ToastOverlay` → `Adw.PreferencesPage` with 3 groups: **From** (amount `Gtk.Entry` + `from_currency_selector` in the group header suffix), a centered group holding the circular `app.switch-currencies` button, **To** (accent `Adw.Bin` wrapping a `Gtk.Stack` of `result`/`loading`/`convertion-error` pages, each inside a `WindowHandle`, + `to_currency_selector` in the group header suffix). Toast on conversion failure. |
| `src/components/currency_selector/currency_selector.py` + `index.blp` | component (`Adw.Bin` template) | `lib/currency_selector.rb` | Yes | `MenuButton` (styles `rised flat`) showing a code label + an "auto" insight label, opening a `Popover` (styles `menu`, `curency-selector`) with a `SearchEntry` and a `ListBox` of `CurrencySelectorRow`s over a sorted+filtered model. Emits `user-selection-changed`; `selected` is a bindable property. Handles Escape (popdown) and Down (stop propagation) on the search entry. |
| `src/components/currency_selector_row/currency_selector_row.py` + `index.blp` | component (`Gtk.ListBoxRow` template) | `lib/currency_selector_row.rb` | Yes | One row: a `Label` (`CODE – shortened name`) + a selection checkmark `Image` bound to the currency object's `selected` property. |
| `src/components/shortcuts/shortcuts.py` + `shortcuts.blp` | dialog (`Gtk.ShortcutsWindow` template) | `lib/shortcuts.rb` | Yes | One group "General": keyboard shortcuts (`win.show-help-overlay`), switch currencies (`app.switch-currencies`), quit (`app.quit`). Note: `Gtk.ShortcutsWindow` can't be subclassed/built the same way from these Ruby bindings — `lib/window.rb`'s own comment flags that `show-help-overlay` is wired as a plain action presenting an Adwaita dialog instead; verify `lib/shortcuts.rb` still reproduces the same three shortcut rows as a real window/dialog. |
| `src/utils.py` → class `CurrencyObject` | model (`GObject.Object`) | `lib/currency_object.rb` | Yes | `code`, `name`, `selected` (bool) properties; `__str__` → code. |
| `src/utils.py` → class `CurrenciesListModel` | model (`Gio.ListModel`) | `lib/currencies_list_model.rb` | Yes | Wraps an array of `CurrencyObject`; `set_currencies` replaces the list and fires `items_changed`; `set_selected` flips the `selected` flag that drives the row checkmark. |
| `src/utils.py` → class `Convertion` | service / event bus | `lib/convertion.rb` | Yes | Caches the last converted pair+provider; `convert` re-fetches only when the pair/provider changed or the previous fetch failed, otherwise re-multiplies locally; `convert_raw` (no cache, no event) is what the search provider uses; emits `"converted"` to any number of listeners. |
| `src/utils.py` → class `Settings` | model (`Gio.Settings` subclass) | `lib/settings.rb` | Yes | Thin subclass of `Gio.Settings` keyed on the app id. |
| `src/utils.py` → class `Utils` | service | `lib/utils.rb` | Yes | Owns `settings`/`convertion`, locale resolution, `CODES`, `providers` map, and locale-aware `format_number`/`parse_number` (Babel-backed upstream). |
| `src/requests.py` | service (HTTP) | `lib/requests.rb` | Yes | `Providers`/`ECB` build the Frankfurter URL and parse the response into `{base, from, to, amount, info, disclaimer, provider}`; `SoupSession` wraps `Soup.Session` with a fixed `User-Agent`; `Requests` dispatches by provider id. |
| `src/define.in` | generated constants (`APP_ID`, `VERSION`, `PROFILE`, `RES_PATH`, `BASE_URL_LANG_PREFIX`, `CODES` currency table) | `lib/define.rb` | Yes | 1146 lines — almost entirely the `CODES` currency table (code → name/providers/etc.), same role as upstream's generated `define.py`. |
| `src/valuta.in` (meson-generated launcher) | launcher | `lib/valuta.rb` / `lib/valuta` | Yes | Entry script analogous to the generated `valuta` launcher. |
| `src/search_provider/search_provider.in` + `.../io.github.idevecore.Valuta.SearchProvider.ini` | GNOME Shell search provider (D-Bus service) | `lib/shell_search_provider.rb` | Yes | Implements `org.gnome.Shell.SearchProvider2` (`GetInitialResultSet`, `GetSubsearchResultSet`, `GetResultMetas`, `ActivateResult`, `LaunchSearch`): parses `"<amount> <FROM> to <TO>"` or a bare amount against the currently-set pair, returns a converted-value result plus a "copy to clipboard" result, and can relaunch the app with `--src-currency-value`. Worth a close re-check against upstream's exact term-parsing branches (4-token form vs. bare amount, `on_currencies_changed` cache invalidation) since this is the easiest piece to under-port. |
| `src/assets/style.css` | stylesheet | `lib/style.rb` | Yes | Ruby has no CSS file by house style; classes referenced across the app (`f-l`, `pd`, `rounded`, `top-transform`, `curency-selector`, etc.) must all still resolve — confirm `lib/style.rb` defines every class the ported widgets apply, not just the ones used so far. |
| `data/io.github.idevecore.Valuta.gschema.xml.in` | GSettings schema | consumed via `lib/settings.rb` | Yes (no separate `.gschema.xml` needed in the gem; bound via `Settings`/`Gio::Settings`) | Keys: `providers` (enum, default `ecb`), `width`/`height`/`is-maximized`/`is-fullscreen` (window state), `src-currency` (default `USD`), `dest-currency` (default `EUR`). **Gap to double check:** `convertion.py` connects `settings.connect("changed::high-precision", …)` but the schema shown has no `high-precision` key — likely dead/vestigial upstream code, not a missing port feature; confirm before porting a `high-precision` setting that doesn't actually exist. |
| `data/io.github.idevecore.Valuta.desktop.in.in`, `.appdata.xml.in.in`, `.service.in`, icons under `data/icons/**` | packaging metadata, not UI code | n/a (Flatpak/meson concern) | n/a | Out of scope for `lib/`; only relevant if/when this port gets its own packaging. |
| `src/valuta.gresource.xml` | GResource manifest (bundles the `.ui`/`.blp`-compiled files + CSS + icons) | n/a | n/a | The Ruby house style has no `.ui`/GResource layer — widgets are built directly in `lib/*.rb`, so this file has no port target by design. |
| `po/*.po`, `po/io.github.idevecore.Valuta.pot`, `po/LINGUAS`, `po/POTFILES` | translation catalogue (38 languages) | n/a | **Not yet assessed** | No translation-parity pass has been run against `lib/`; flagged for the `translation-parity` skill, not scored here. |

## Summary

Every upstream user-facing unit (app, window, page, both selector components,
the shortcuts dialog, the about dialog, actions, settings/convertion/requests
services, the currency data table, and the shell search provider) already has
a corresponding non-empty file under `lib/` on `ruby`. This survey did not
diff behavior line-by-line (that is `component-parity`'s job); it only
confirms unit-level coverage and calls out three things worth a parity pass
before calling the port done:

1. **Shortcuts window** (`lib/shortcuts.rb` / `lib/window.rb`) — upstream uses
   a real `Gtk.ShortcutsWindow` template; the port's own comment says that
   can't be built the same way from these bindings and substitutes something
   else presented from an action. Confirm the substitute still shows all
   three shortcut rows (keyboard shortcuts, switch currencies, quit).
2. **Shell search provider** (`lib/shell_search_provider.rb`) — the most
   state-machine-heavy file upstream (term parsing, result caching,
   relaunching with `--src-currency-value`); worth a dedicated parity pass.
3. **`high-precision` GSettings key** referenced in `convertion.py` but absent
   from the current `gschema.xml.in` — confirm it's dead upstream code before
   treating it as a missing port feature.

No missing `lib/` file was found; no action, in this survey's reading, is
required to *create* a new component file. Behavioral parity per file is the
next step (`component-parity` skill), not covered here.
