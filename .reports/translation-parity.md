# Translation parity — valuta

**Superseded in part.** This document's original pass (below the
`---` marker) found 0/185 parity before gettext infrastructure landed. A
re-audit run 2026-11-07 against current `ruby` HEAD (`0594500`), after
`f9bbc76` wired `gettext` and ported `po/`, found the picture has changed
substantially. The current state is reported first; the original pass is
kept below, unedited, because rows are never deleted.

## Re-audit, 2026-11-08, against `ruby` @ `9df781b`

One translation-relevant commit landed since the last re-audit below
(`49474ac`, "Merge desktop-file translations, add Requests unit specs, fix
inventory claim"), touching
`data/applications/io.github.idevecore.Valuta.desktop`.

**Desktop-file localization: mostly closed, one real gap remains.** The
2026-11-07 re-audit below recorded this file as having *zero*
`Comment[xx]=` entries. Re-checked today — that is no longer true:

```
$ grep -c '^Comment\[' data/applications/io.github.idevecore.Valuta.desktop
29
```

29 of the 33 `po/LINGUAS` locales now have a `Comment[xx]=` line, each
checked against its `.po`'s `msgstr` for `msgid "Convert between currencies"`
and matching. `Name=Valuta` correctly carries **no** `Name[xx]=` lines in
either upstream or the port — confirmed by grepping `po/POTFILES`/the `.pot`:
`Name=` is not one of upstream's translatable desktop-file strings (only
`Comment=` is, at `desktop.in.in:6`), so the port not inventing `Name[xx]=`
entries is correct, not a gap.

The remaining 4 locales — `sv`, `ia`, `ka`, `ro` — are correctly absent: each
has an empty `msgstr ""` for this exact msgid in upstream's own `.po` (i.e.
upstream ships no translation for this string in those languages either;
confirmed by reading `po/sv.po`, `po/ia.po`, `po/ka.po`, `po/ro.po` from
`origin/main` directly). Omitting them matches upstream's actual shipped
behavior.

**`nb_NO` is a real, narrow gap.** `po/nb_NO.po` has a *non-empty* `msgstr`
for `msgid "Convert between currencies"` (`"Kunne ikke hente valutadata"` —
oddly, this reads as "Could not retrieve currency data" rather than an
actual translation of "Convert between currencies"; that mistranslation is
upstream's own `.po` content, not something to fix in the port) but the
port's desktop file has no `Comment[nb_NO]=` line at all. A Norwegian
(Bokmål) user gets the English `Comment=` where upstream's build would have
given them that (admittedly wrong) Norwegian string. This is the one
concrete, actionable translation-parity gap left: add
`Comment[nb_NO]=Kunne ikke hente valutadata` to
`data/applications/io.github.idevecore.Valuta.desktop`.

**Msgid coverage re-walked end to end.** Extracted every `msgid` from
upstream's committed `po/io.github.idevecore.Valuta.pot` (175 non-header
entries) and every `_()`/`N_()`/`p_()`/`P_()`-style call in `lib/` by hand
(not just grep, to account for `p_`/`C_`-style context calls a bare `_(`
regex misses). Three apparent "misses" on a first pass turned out to be
false positives once the actual call sites were read:

- `"Google (unstable)"`, `"Moeda.info"`, and `"Unable to convert currency,
  failed to fetch results from Google."` are upstream `.pot` leftovers from
  a removed feature — `src/requests.py`'s own `providers = {0: ECB}` dict
  (re-read directly from `origin/main` this pass) only ever registers ECB,
  and `data/metainfo/...xml.in`'s own 1.4.2 release notes say "Moeda.info
  removed." The port correctly implements only ECB and correctly has no
  string for providers that no longer exist in either tree.
- `"Search"` (referenced by the `.pot` at `index.blp:19`) no longer exists
  in upstream's *current* `index.blp` at all — the `.pot` is stale relative
  to upstream's own source (confirmed: no `_("Search")` literal anywhere in
  `origin/main`'s `src/components/currency_selector/index.blp` today). This
  is an upstream packaging staleness issue, not a port gap: there is nothing
  live to translate.
- `"General"`, `"Switch currencies"`, `"Quit"` are present and correctly
  wrapped — `lib/shortcuts.rb:29-34` uses `p_('shortcuts window', 'General')`
  etc., matching upstream's `C_("shortcuts window", ...)` context exactly.
  A naive `grep "_('"` misses these because the marker is `p_`, not `_`; this
  is noted explicitly so the next audit doesn't re-report it as a gap (see
  **correction to `component-parity.md`** below).

So, msgid coverage: **no additional gap found beyond the already-known
`nb_NO` desktop-file line.** The 175-upstream/184-ported counts from the
2026-11-07 pass stand (the small count difference is the currency-name
dict's dynamic re-lookup, already hand-censused there, not a new issue).

### Correction to a claim in `component-parity.md`

That document's current text asserts text-axis gaps in `window.rb` and
`shortcuts.rb` — e.g. "`_("Main menu")` vs bare `'Main menu'`" — claiming the
port left several strings unwrapped. **Read directly against `lib/window.rb`
and `lib/shortcuts.rb` this pass, every one of those specific claims is
false of the current code:**

```
lib/window.rb:101:   button.tooltip_text = _('Main menu')
lib/window.rb:111:   _('Providers'),
lib/window.rb:112:   section.append(_('ECB'), 'window.providers::ecb')
lib/window.rb:119:   section.append(_('About Valuta'), 'app.about')
lib/window.rb:144:   button.tooltip_text = _('Source')
lib/shortcuts.rb:29:  GROUP_TITLE = p_('shortcuts window', 'General')
lib/shortcuts.rb:32-34: p_('shortcuts window', 'Keyboard shortcuts'|'Switch currencies'|'Quit')
```

`git diff 2bd7118..HEAD -- lib/window.rb lib/shortcuts.rb` is empty — these
files have not changed since `component-parity.md`'s claims were written, so
the claims were already false when written, not merely stale. The one real,
narrow miss in this unit is `lib/window.rb:26`'s `TITLE = 'Valuta'`, which is
genuinely unwrapped — but upstream's own `_("Valuta")`
(`src/window.blp:9`) **never made it into upstream's own `.pot`** (confirmed:
no `msgid "Valuta"` anywhere in `po/io.github.idevecore.Valuta.pot`), so no
`.po` file has ever translated it either. The port's unwrapped literal
produces the exact same observable string, in every language, as upstream's
nominally-wrapped-but-never-extracted one. Not a user-visible gap. This
correction is filed here, in `translation-parity.md`, because it is the text
axis the claim is about; `accountability-ensurance.md` carries the
meta-finding that the claim was wrong in the first place.

### Verdict, 2026-11-08

- Desktop-file `Comment[xx]=`: **29/33, correctly so for 29 and for the 4
  deliberately-empty-upstream ones; `nb_NO` is the one real remaining gap.**
- Msgid coverage: **no new gap; three apparent misses resolved as false
  positives (dead code, stale upstream `.pot`, missed `p_()` call sites).**
- `component-parity.md`'s window/shortcuts text-gap claims: **false,
  corrected here and in `accountability-ensurance.md`.**
- `clean` for this document: **false** — `nb_NO` is open, and the
  domain/desktop-build-mechanism history below still applies.

## Re-audit, 2026-11-07

| | |
|---|---|
| Upstream | `origin/main` @ `0c9ee15` |
| Port | `ruby` @ `0594500` |
| Domain (upstream, actual) | `valuta` — see **Domain mismatch** below |
| Domain (port) | `io.github.idevecore.Valuta` |
| Upstream messages | 185 (census: `.claude/skills/translation-parity/scripts/msgid-census.sh`, scanning `src/`, `.blp`, `.desktop.in.in`, `.appdata.xml.in.in`) |
| **Ported** | **184** |
| **Gaps** | **1 — see below; not a real content gap, see explanation** |
| Extra (untranslated port-only strings) | 0 |
| Languages shipped by the port | **33 of 33** (`po/LINGUAS` byte-identical to upstream's; `ls po/*.po` matches upstream's file set exactly, 33 files both sides) |
| Build command | `rake gettext:mo:update` — compiles 33 `.mo` files; ran it in this audit, confirmed 33 `.mo` files produced under `locale/<lang>/LC_MESSAGES/` |
| Non-English rendering, verified on screen | **Yes** — see below |

### The headline numbers

```
184/185 messages · 33/33 languages shipped · domain_matches: false (see below)
```

### The one "gap"

```
comm -23 <upstream keys> <port keys>
!unresolved	gettext(CODES.get(code, '')['name'])         return name if name els...
```

This is not a missing string. `src/pages/convertion/convertion.py:70` calls
`gettext(CODES.get(code, '')['name'])` — a **dynamic** re-lookup of a value
that is itself already the *translated* string, because upstream's
`CODES` dict (`src/define.in`) wraps every currency name in `_(...)` at
dict-definition time (`gettext.install('valuta', ...)` makes `_` global
before `CODES` is built). So this call's argument is never a literal the
census can read, and the census correctly flags it `!unresolved` rather than
silently dropping it — but the actual 160 currency-name messages it operates
over are already counted, under `src/define.in`, among the 184 ported rows:
`lib/define.rb` marks every one of them with `_('<name>')`, byte-identical to
upstream's `src/define.in` literals (verified: `grep -c "_(" lib/define.rb`
→ 161, one more than upstream's 160 named currencies for a non-currency `_()`
call elsewhere in the file). **Nothing here is actually missing a
translation.** The row stays open in the ledger as `unresolved` per the
skill's rule (never write a ledger while `unresolved` is non-zero without
hand-censusing it), and it is hand-censused above: closed by inspection, not
silently dropped.

### Domain mismatch — a real gap

`po/meson.build:1` is `i18n.gettext('valuta', preset: 'glib')` and
`meson.build:1` is `project('valuta', ...)` — upstream's actual gettext
domain is **`valuta`**, confirmed independently at `src/valuta.in:38-39`
(`locale.bindtextdomain('valuta', localedir); locale.textdomain('valuta')`)
and `src/define.in:31` (`gettext.install('valuta', '@localedir@')`).

The port's `lib/i18n.rb` sets `DOMAIN = 'io.github.idevecore.Valuta'`
(the **app ID**, not the project name) and the `Rakefile`'s
`GETTEXT_DOMAIN` constant matches it, so the port is internally
self-consistent — its own `.mo` files are compiled and looked up under the
same (wrong) name, which is why the German-locale check below still works.
But it is not upstream's domain, and `lib/i18n.rb`'s own comment asserts the
opposite of what the code does:

> `lib/i18n.rb:9-10`: "The domain is upstream's own meson project/package
> name, not the port's gem name" — true in principle, false in practice:
> upstream's meson project/package name is `valuta` (`meson.build:1`,
> `po/meson.build:1`), and the constant three lines below is
> `io.github.idevecore.Valuta`, which is neither.

This does not currently break anything a user can observe (self-consistency
means the port's own translations work end to end, confirmed below), but it
means `domain_matches: false` in the skill's terms, and it is the kind of
thing that bites the next refresh: pulling a newer `po/` from upstream, or
any future tooling that expects the installed `.mo` to be named `valuta.mo`
(e.g. a system package, a Flatpak manifest mirroring upstream's), would miss
this port's catalogue entirely. Fix is mechanical: `DOMAIN = 'valuta'` in
`lib/i18n.rb`, `GETTEXT_DOMAIN = "valuta"` in the `Rakefile`, recompile.

### Desktop file: the catalogue has the string, the shipped file doesn't

`data/applications/io.github.idevecore.Valuta.desktop` is a flat, static
file with no `Name[xx]=`/`Comment[xx]=` localized entries, for any of the
33 languages. Upstream's equivalent is **built**, not written by hand:
`data/meson.build` runs `i18n.merge_file(... type: 'desktop' ...)` over
`data/io.github.idevecore.Valuta.desktop.in.in`, which merges each
language's translation of `Comment=Convert between currencies` (msgid
confirmed present and translated in `po/de.po` and every other `.po`:
`#: .../desktop.in.in:6 msgid "Convert between currencies"`) into the
installed `.desktop` file at build time. The port has no equivalent build
step, so the one translatable string this file carries is English-only in
the port despite being fully translated in the catalogue the port ships.
This is a **component gap** (no desktop-merge step exists) wearing a
translation-axis symptom; cross-filed here and belongs in
`component-parity.md` as the fix (a small Rake task or a hand-maintained
set of `Comment[xx]=` lines generated from `po/*.po` at build/package time).

### Verified on screen, non-English locale

```
$ LANGUAGE=de nix develop --command xvfb-run -a ruby -e '... p_("shortcuts window","General") ...'
Allgemein
```
and separately `_("Keyboard shortcuts")` → `Tastenkürzel`, both read via the
port's own `I18n`/`lib/shortcuts.rb` wiring, both matching `po/de.po`'s
`msgstr` exactly. **No automated check in `test/` pins this** — see
`test-parity.md`'s "Re-audit" section; it was verified by hand in this audit
only, same as the previous commit's message claimed, and remains something a
regression could silently break.

### What closed since the original pass below

- `po/` (33 `.po`, `LINGUAS`, the `.pot`, `POTFILES`) now exists on `ruby`, copied from upstream and rewritten to Ruby paths.
- `gettext` is a real dependency (`lib/i18n.rb`, `Gemfile`).
- 184 of upstream's 185 messages are marked in `lib/` with byte-identical msgids (`_`, `n_`, `p_`), covering `define.rb`'s 160 currency names, the conversion page, window, shortcuts dialog, currency selector and shell search provider.
- `data/metainfo/io.github.idevecore.Valuta.metainfo.xml.in` now exists (was entirely absent before), closing the "no AppStream file at all" finding from the original pass.
- `rake gettext:mo:update` compiles all 33 languages; ran it in this audit, 33 `.mo` files produced.

### What the original pass's finding should no longer be read as

The original pass below says "Translation parity: 0/185... Not proven, not
partially proven — absent." **That sentence is now false of the current
tree** and must not be read as the current state. It is kept verbatim
because rows are never deleted, not because it still describes `ruby` HEAD.

## Rules followed, this round

- Did not write the ledger while `totals.unresolved` was non-zero without hand-censusing the one unresolved marker (done above).
- Did not count the domain match or the desktop-file gap as closed by the presence of `po/` and `gettext` generally — each was checked at the specific file/constant it depends on.
- Did not claim `summary.parity: true`; it is false, on `domain_matches` and on the desktop-file gap, even though the message-key set is 184/185 effectively 185/185 once the unresolved row is explained.
- Reported the occurrence/uses axis as a lead, not folded into the message-count pass condition.

## Re-audit, 2026-11-07, against `ruby` @ `c8dcd6c`

One commit landed since the previous pass: `c8dcd6c` ("Fix gettext domain
mismatch (valuta, not the app id)"), touching `Rakefile` and `lib/i18n.rb`.

**Domain mismatch: closed.** `lib/i18n.rb:22` now reads `DOMAIN = 'valuta'`,
matching upstream's actual domain confirmed independently at
`po/meson.build:1` (`i18n.gettext('valuta', preset: 'glib')`),
`meson.build:1` (`project('valuta', ...)`), and `src/valuta.in:38-39`
(`locale.bindtextdomain('valuta', localedir)`). The `Rakefile`'s
`GETTEXT_DOMAIN` constant (`Rakefile:174`) is also `"valuta"`, and its
comment now correctly separates the gettext domain from the committed
`.pot` filename (which upstream itself still names after the app id,
`po/io.github.idevecore.Valuta.pot` — not a bug, upstream's own choice).
Rebuilt the catalogue in this audit (`rake gettext:mo:update`) and confirmed
the compiled file is `locale/de/LC_MESSAGES/valuta.mo` (previously
`io.github.idevecore.Valuta.mo`). Re-ran the on-screen German check from the
prior pass directly against `lib/i18n.rb` (not hand-reproduced — the actual
module, `include`d and exercised):

```
$ LANGUAGE=de nix develop --command xvfb-run -a ruby -e '... include I18n; p_("shortcuts window","General"); _("Keyboard shortcuts") ...'
Allgemein
Tastenkürzel
```

Both match `po/de.po`'s `msgstr` exactly, now under the correct domain name.
This closes the one real translation-axis gap this document had open
(`domain_matches` is now `true`).

**Desktop-file localization: still open, unchanged.**
`data/applications/io.github.idevecore.Valuta.desktop` still has no
`Name[xx]=`/`Comment[xx]=` entries for any of the 33 languages (re-verified:
`grep -c '\[' data/applications/io.github.idevecore.Valuta.desktop` →
0). No commit since the prior pass touched this file or added a merge step.
Still a component-axis gap (see `component-parity.md`), still wearing a
translation symptom.

**A claim in `.reports/component-inventory.md` is now stale and false, not
merely unassessed.** The commit that follows the domain fix in history,
`d6cce63` ("Inventory upstream components", committed *after* `f9bbc76`
originally wired translation infra, and after this very document already
recorded 184/185 parity), still asserts in two places that "`ruby` carries
no `po/` directory of its own and no translation-parity work has been done
yet." Both clauses are false of the tree at the commit that wrote them —
`po/` has held 33 `.po` files since `f9bbc76`, and this document's own prior
re-audit section, already committed on this branch, records 184/185. See
`accountability-ensurance.md` for the full trace; recorded here too because
it is this document's own numbers the stale claim contradicts.

No other upstream message or `.po` file changed on `origin/main` since the
prior pass (`git diff 0c9ee15..origin/main -- po/ src/ data/` — confirmed
empty; upstream has not moved). Totals are unchanged: **184/185 messages,
33/33 languages, domain now matches.** The one remaining translation-adjacent
gap is the desktop-file merge step, which is a missing build mechanism, not
a missing message.

---

# Original pass (pre-`f9bbc76`) — kept verbatim, superseded above

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
