# GettextTs

**Gettext catalogs, generated to TypeScript.** One translation source of
truth for applications split into an Elixir backend and a TypeScript
frontend: the backend translates with Gettext as usual, and
`mix gettext_ts.codegen` emits typed, per-locale TypeScript catalogs the
frontend consumes through a tiny `t()` runtime. No frontend i18n framework,
no parallel JSON catalogs, no drift.

Extracted from the Vulcora apps (the pattern was pioneered in production in
mosis), with the original's known defects fixed:

- **Nested catalogs** (`locale → domain → msgid`) — the same msgid in two
  domains no longer collides.
- **Per-locale, per-domain chunks** with a lazy `loadCatalog(locale, domains?)`
  — the frontend loads one locale, and within it only the domains that route
  tree renders.
- **One interpolation dialect**: `%{var}`, Gettext's own.
- **Runtime overrides** as a first-class layer on both sides — admin-edited
  translations from a database sit on top of the compiled catalog (backend:
  an override MFA consulted by the `t` macro; frontend: an `overrides` prop
  on the provider).

## Install

```elixir
{:gettext_ts, "~> 0.1"}
```

`:gettext` is an optional dep (needed for the `t` macro and `gettext.merge`);
codegen alone only needs `:expo`.

## The loop

```
mix gettext.extract --merge   # backend msgids (dgettext / t-macro calls)
mix gettext_ts.extract        # frontend t("...") msgids → POT + merge
# translate the PO files (by hand, or your own AI-assisted task)
mix gettext_ts.codegen        # PO → TypeScript
```

With Ash, add the extension to a domain and `mix ash.codegen` drives it:

```elixir
use Ash.Domain, extensions: [GettextTs.AshExtension]
```

## Backend

```elixir
use GettextTs.T, backend: MyAppWeb.Gettext

t("default", "Authentication required")
t("notifications", "Level %{level}!", level: 5)
```

The macro expands to `dgettext`, so `mix gettext.extract` sees every msgid —
no catalog-registration module needed. Database-stored overrides plug in via

```elixir
config :gettext_ts, override: {MyApp.TranslationOverrides, :get}
# get(locale, domain, msgid) :: {:ok, string} | :not_found
```

## Frontend

```tsx
import { I18nProvider, useT } from "@/lib/i18n/react";

<I18nProvider locale={locale} overrides={overridesFromApi}>
  <App />
</I18nProvider>

const t = useT();                       // default domain
const tn = useT("notifications");       // another domain
t("Book now");
tn("Level %{level}!", { level: 5 });
```

Keys are typed (`TranslationKey` union) but plain strings are accepted, so
new copy renders in the source language before codegen has run. Domains are
typed exactly: `useT("notifcations")` is a compile error.

### Loading one domain at a time

`catalog/<locale>/<domain>.ts` is a chunk of its own, and `domains` says
which ones a subtree needs:

```tsx
// Public tree: the copy visitors can actually reach.
<I18nProvider locale="en" domains={["default", "errors"]}>

// Admin tree, nested inside it: same locale, one more domain.
<I18nProvider locale="en" domains={["default", "admin"]}>
```

Omit `domains` and the locale arrives whole, as before. This matters when the
domains are lopsided — an admin panel's copy easily outweighs the public
site's, and without the split every visitor downloads a catalog for pages
they cannot open.

The source locale has no chunks at all: msgid IS its copy, and `createT`
falls back to the msgid.

### Server-rendered locales

The catalog is fetched lazily, so a page server-rendered in a non-source
locale ships source-language HTML and swaps after hydration — a crawler
never sees the translation. Seed the first render instead:

```tsx
import nl from "@/lib/i18n/catalog/nl";

<I18nProvider locale="nl" initialCatalog={nl}>
```

Import it in the client component that renders the provider, not in a
server component: a static import puts the catalog in a cacheable JS chunk,
a prop passed across the boundary puts it in every page's payload. The lazy
load still runs afterwards and refreshes the state.

Give that client component to ONE tree. A module exporting both the source-
locale and the translated-locale provider is a single module to the bundler,
so its static import lands in a chunk both trees share — and the source
locale ends up downloading a catalog it never reads.

## Configuration

```elixir
config :gettext_ts,
  gettext_path: "priv/gettext",
  output_path: "assets/js/i18n",
  source_locale: "en",
  default_domain: "default",
  frontend_globs: ["assets/js/**/*.{ts,tsx}"],
  extract_function: "t",
  domain_hook: "useT",                    # binds a file's calls to a domain
  extract_ignore: :defaults,
  react: true
```

`domain_hook` is what makes `const t = useT("admin")` extract into `admin`.
Without it a subtree that moved to its own domain keeps filling the default
POT, and nothing complains — the copy just stays untranslated at runtime.

## Status

Experimental — extracted 2026-08-11, API may change before 1.0. MIT.
