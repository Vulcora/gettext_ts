# Changelog

## [0.2.0] - 2026-08-11

**The domain, not the locale, is the unit of loading.** Measured in
swedishspytours: 573 of 849 msgids were admin-panel copy, and every public
English page downloaded all of them — 30 kB gzipped of a catalog no visitor
can reach.

Breaking:

- Codegen emits `catalog/<locale>/<domain>.ts`, not `catalog/<locale>.ts`.
  Static importers must name the domain.
- `loadCatalog(locale, only?)` takes the domains to load; omitting them loads
  the locale whole, as before.
- `LocaleCatalog` and `Overrides` are `Partial<Record<Domain, DomainCatalog>>`
  and `createT`/`useT` take a `Domain`, not a `string`. A domain typo is now a
  type error; a domain the route tree did not load is not.
- The source locale gets no catalog files. Identity is what msgid passthrough
  already gives, so writing it out only made the source language download its
  own copy. A source locale with real PO files on disk is emitted as before.
- Stale files under `catalog/` are deleted, and reported by `--check`.

Added:

- `I18nProvider` takes a `domains` prop — the chunks that subtree needs. Nest
  a second provider around an admin area to load its domain lazily.
- The extractor understands the domain in the BINDING: every
  `const t = useT("admin")` in a file attributes that file's `t("…")` calls to
  `admin`. Without it, moving a subtree to its own domain kept extracting into
  the default one, and the drift showed up only as untranslated copy at
  runtime. Hook name configurable as `:domain_hook` (default `"useT"`).

## [0.1.1] - 2026-08-11

- `I18nProvider` takes an optional `initialCatalog`, used as the provider's
  initial state. A per-locale server-rendered route tree can now import its
  catalog statically and be translated in the first HTML, instead of shipping
  source language and swapping after hydration. The lazy load is unchanged.

## [0.1.0] - 2026-08-11

Initial extraction from the Vulcora apps (mosis's PO→TypeScript pipeline),
with the production-known defects fixed: nested locale→domain→msgid
catalogs (cross-domain msgid collisions), per-locale output files with lazy
loading (previously one all-locales bundle), a single `%{var}` interpolation
dialect, configurable frontend scanning, and first-class runtime overrides
on both sides (backend override MFA in the `t` macro, `overrides` prop in
the React provider).
