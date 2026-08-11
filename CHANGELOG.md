# Changelog

## [Unreleased]

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
