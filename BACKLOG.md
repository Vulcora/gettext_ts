# Backlog

## From the first real consumer migration (2026-08-11)

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
4. **The extractor only adds.** Rewrite a msgid and the old one stays in POT
   and PO forever; six had to be cleaned by hand in fas 3b and one more
   ("Historik") surfaced in fas 6. A `--prune` that reports msgids no scan
   found would have caught all seven.
5. **Only single-line double-quoted literals are seen.** Multi-line copy and
   template literals fall outside the scanner, and the workaround is to
   mirror them in a backend module with `dgettext_noop` plus a test that
   fails when the mirrors drift.

## From the a client app fas 6 migration (2026-08-11)

6. **No way to ask what a chunk costs.** The per-domain split was sized by
   parsing the bundler's output by hand. A `mix gettext_ts.codegen --stats`
   printing msgids and bytes per locale/domain would make the decision to
   split a domain a measurement rather than a guess.
