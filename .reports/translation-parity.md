# Translation parity — valuta

| | |
|---|---|
| Upstream | `origin/main` (Python/Blueprint, GNOME app `io.github.idevecore.Valuta`) |
| Port | `ruby` |
| Domain | `io.github.idevecore.Valuta` (upstream's `.mo` domain) |
| Upstream languages | 33 `.po` files (`po/LINGUAS`: ar bg cs de es et fi fr he hi nb_NO nl pl pt pt_BR ru sv tr te uk ja zh_Hans ia ta it be hr eu kw kk ka ro ko) |
| Upstream messages | 178 in the committed `po/io.github.idevecore.Valuta.pot`; 185 distinct call-site msgids found scanning upstream source + `.blp` + `.desktop.in.in` + `.appdata.xml.in.in` + `.gschema.xml.in` directly (`.claude/skills/translation-parity/scripts/msgid-census.sh`) |
| **Ported** | **0** |
| **Gaps** | **185 (every message)** |
| Extra (untranslated) | 4 — see below |
| Languages shipped by the port | **0 of 33** |
| Build/translation command | none exists |

## Finding: translation parity does not exist on this port

This is not a partial gap. The port:

- has **no `po/` directory at all** (`find . -iname '*.po' -o -iname LINGUAS -o -iname '*.pot'` on the `ruby` branch returns nothing),
- has **no `gettext` dependency** (`Gemfile`, `Gemfile.lock`, `valuta-rb.gemspec` — none mention `gettext`, `fast_gettext`, or any i18n gem),
- contains **zero occurrences** of `_(`, `N_(`, `n_(`, `C_(`, `ngettext`, or any translation marker anywhere in `lib/` or `exe/` (`grep -rn "gettext\|_(\|N_(\|n_("` returns nothing),
- builds every user-visible string as a bare Ruby literal: `lib/window.rb:23` `TITLE = 'Valuta'`, `lib/window.rb:98` `button.tooltip_text = 'Main menu'`, `lib/convertion_page.rb:37` `TOAST_MESSAGE = 'Error converting, please try again.'`, `lib/shortcuts.rb:21` `GROUP_TITLE = 'General'`, `lib/shortcuts.rb:24-26` `'Keyboard shortcuts'`/`'Switch currencies'`/`'Quit'`, `lib/about_dialog.rb:89` `'None'`, etc.

Upstream marks every one of these through `_()`/`C_()`/`N_()` in Python and blueprint (e.g. `src/components/shortcuts/shortcuts.blp:9-20` wraps all three shortcut titles in `C_("shortcuts window", ...)`; `src/window.blp` and `src/pages/convertion/convertion.py` do the same for every label this port hardcodes).

Net result: **0 of the 33 languages upstream ships reach a single string in this port.** Every user who is not reading English gets English, with no `po/` for anyone to even contribute a translation to. This is a complete regression from upstream, not an unfinished feature — the donated translation work (33 languages, several hundred translated strings) is entirely discarded.

## The four "extra" messages the port does emit

The census found four marked/extractable strings in the port, all from `data/applications/io.github.idevecore.Valuta.desktop` — a plain key=value `.desktop` file with no `.in`/`.in.in` gettext-processing step and no corresponding `[lang]` sections:

```
Convert between currencies          data/applications/io.github.idevecore.Valuta.desktop:6
Valuta;Converter;Currency;ExchangeRate;  data/applications/io.github.idevecore.Valuta.desktop:10
Valuta                              data/applications/io.github.idevecore.Valuta.desktop:2
Valuta                              data/applications/io.github.idevecore.Valuta.desktop:3
```

These are **not translated** either — the port's `.desktop` file has no localized `Name[xx]=`/`Comment[xx]=` entries, where upstream's `.desktop.in.in` is processed by `msgfmt --desktop` against `po/` to produce exactly those per-language sections. So even this one packaging file the port did write is English-only, with upstream in 33 languages.

## What is entirely missing (not assessed as "n/a" — actually absent)

- **No AppStream metainfo file at all.** Upstream ships `data/io.github.idevecore.Valuta.appdata.xml.in.in` with a translated `<summary>` and `<description><p>`. The port has no `data/metainfo/` or equivalent file anywhere. This is 2+ more messages with zero port counterpart, in zero languages — not a translation decision, a missing component.
- **No GSettings schema file**, hence no translated `<summary>`/`<description>` in a `.gschema.xml` (upstream's schema carries none of substance here, so this is low-stakes, but it is still an absent file, not an assessed correspondence).

## Prior report's false "not yet assessed" framing

`.reports/component-inventory.md:33` records the translation catalogue as:

```
| `po/*.po`, ... | translation catalogue (38 languages) | n/a | **Not yet assessed** | No translation-parity pass has been run against `lib/`; flagged for the `translation-parity` skill, not scored here. |
```

That framing is now obsolete and was already generous: "not yet assessed" invited a reader to treat this as neutral, pending work. Having now run the skill, the honest state is not "unassessed" — it is **0/185, 0/33 languages, fully regressed.** (The row's own language count, 38, is also off; `po/LINGUAS` lists 33.)

## Rules this report follows

- No row is marked `ported` from reading the code — none are, because the census of the port returns effectively nothing translatable from `lib/`.
- No reworded string is treated as an improvement. None were found reworded; they were simply never marked in the first place, which is the same failure one step earlier.
- `summary.parity` is unambiguously `false`: gaps are 185 (not 0), languages_missing is all 33, domain is unconfirmed because no domain exists.

**Translation parity: 0/185 messages · 0/33 languages · 0 strings translated. Not proven, not partially proven — absent.**
