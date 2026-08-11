# Changelog

## [0.1.0] - 2026-08-11

Initial extraction from the Vulcora apps (mosis's PO→TypeScript pipeline),
with the production-known defects fixed: nested locale→domain→msgid
catalogs (cross-domain msgid collisions), per-locale output files with lazy
loading (previously one all-locales bundle), a single `%{var}` interpolation
dialect, configurable frontend scanning, and first-class runtime overrides
on both sides (backend override MFA in the `t` macro, `overrides` prop in
the React provider).
