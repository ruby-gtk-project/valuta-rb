# Findings — valuta-rb

Binding quirks and deliberate upstream-vs-port divergences found while
porting, recorded so a later pass does not rediscover or silently "fix" them
back to a bug.

## Intentional divergence: `currency-selector` CSS class

**Upstream's own blueprint never applies its CSS rule.**
`src/components/currency_selector/index.blp` sets the popover's style class
with a typo:

```
styles ["curency-selector", "menu"]
```

(`curency-selector`, missing the second `r`), while `src/assets/style.css`
defines the rule under the correctly-spelled `.currency-selector`. Upstream
ships this mismatch today, so the rule has never matched any widget upstream
builds, and whatever `.currency-selector` draws (see `lib/style.rb` for the
port's equivalent) has never rendered for any upstream user.

`lib/currency_selector.rb`'s `popover` method applies the corrected spelling:

```ruby
pop.add_css_class('currency-selector')
```

This is a deliberate port decision, not an oversight: the stylesheet's
intent is unambiguous (one class, one rule, one off-by-one-letter typo
between them), and reproducing the typo would mean deliberately building a
popover the port's own `lib/style.rb` rule can never reach, for no reason but
mirroring a bug. The method's inline comment names the divergence; this
entry exists so it is also findable without reading that file first.

**Risk if this is ever revisited:** if upstream's CSS or blueprint changes to
rely on the *mismatch itself*, the port's corrected class name would start
applying styling upstream never showed its users. No evidence of that today
— the only plausible reading of the typo is "nobody noticed" — so the fix
stands until shown otherwise.

## gettext: msgctxt arguments must be literals, not constants

The `gettext` gem's Ruby extractor (`rxgettext`) reads a marker's arguments
by regex over the source text, not by evaluating Ruby. A call like
`p_(SOME_CONSTANT, 'General')` extracts the msgid fine but leaves the
msgctxt unresolved, and the entry that reaches `GetText::Tools::XGetText`
is then flagged as "a kind of msgctxt" with no actual context string —
`create_pot` raises `GetText::POEntry::NoMsgctxtError` ("This POEntry is a
kind of msgctxt but the msgctxt property is nil") the first time anything
tries to serialize it. `lib/shortcuts.rb` hit this with a `SHORTCUTS_CTXT`
constant; the fix is to spell the context literal (`'shortcuts window'`) at
every call site, matching upstream's own repeated `msgctxt "shortcuts
window"` in `shortcuts.blp`.

## `GetText::Tools::Task`'s po layout is not upstream's layout

`GetText::Tools::Task` (the Rake task the `gettext` gem ships) hardcodes
`po/<locale>/<domain>.po` — a per-locale subdirectory — with no flat-layout
option. Upstream (and this port's copied catalogue) uses meson's flat
`po/<locale>.po`. Pointing the stock task at `po_base_directory: "po"`
silently creates empty `po/<locale>/` subdirectories and compiles `.mo`
files from those (near-empty) new files instead of the real, translated
flat ones — no error, just a `.mo` with far fewer messages than the `.po` it
was supposed to read. `Rakefile`'s `gettext:mo:update` task does not use
`GetText::Tools::Task`; it calls `GetText::Tools::MsgFmt.run` directly, once
per `po/<lang>.po` named in `po/LINGUAS`, which respects the flat layout.
