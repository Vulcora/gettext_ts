# Backlog

## From the swedishspytours fas 3 migration (2026-08-11)

1. **Default `extract_ignore` is too aggressive for Swedish copy.** The
   `~r/^[a-z][a-z0-9_]*$/` rule silently drops every single lowercase-word
   msgid ("till", "kvar", month abbreviations) — no warning, the string
   just never reaches the catalog. Consider: only ignore when the word
   contains `_`, and/or log dropped candidates so the silence isn't
   invisible.
2. **No `msgctxt` support.** The same source string with different
   translations in different contexts ("Avbryt" → Cancel vs "Ställ in" →
   Cancel date) forces app-side wording workarounds. Expo carries msgctxt;
   the emitter, key type and t() runtime need a context dimension.
3. **Extractor reads raw source including comments** — a `t("…")` inside a
   comment becomes a msgid (bit two separate migration passes). Strip
   comments before scanning, or document loudly.
