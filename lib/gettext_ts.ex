defmodule GettextTs do
  @moduledoc """
  Gettext catalogs, generated to TypeScript.

  For applications that split into an Elixir backend and a TypeScript
  frontend and want ONE translation source of truth: the Gettext PO files.
  The backend translates with Gettext as usual; `mix gettext_ts.codegen`
  emits typed, per-locale TypeScript catalogs the frontend consumes with a
  tiny `t()` runtime — no i18n framework, no parallel JSON catalogs, no
  drift.

  Extracted from the Vulcora apps (mosis pioneered the pattern), with the
  original's known defects fixed:

  * Catalogs are nested `locale → domain → msgid` — the same msgid in two
    domains no longer collides.
  * One TypeScript file per locale plus a lazy `loadCatalog/1` index — the
    frontend loads the locale it needs, not every locale at once.
  * One interpolation dialect throughout: `%{var}` (Gettext's).

  ## The loop

      mix gettext.extract --merge   # backend msgids (dgettext/t-macro calls)
      mix gettext_ts.extract        # frontend t("...") msgids → POT + merge
      # ...translate the PO files however you like...
      mix gettext_ts.codegen        # PO → TypeScript

  With Ash, add `GettextTs.AshExtension` to a domain's extensions and
  `mix ash.codegen` runs the codegen automatically.

  ## Configuration

      config :gettext_ts,
        gettext_path: "priv/gettext",           # PO/POT root
        output_path: "assets/js/i18n",          # where TS lands
        source_locale: "en",                    # msgid == msgstr identity locale
        default_domain: "default",              # frontend t()'s domain
        frontend_globs: ["assets/js/**/*.{ts,tsx}"],
        extract_function: "t",
        extract_ignore: :defaults,              # or a list of regexes/prefixes
        react: true                             # also emit react.tsx

  All keys can be overridden per invocation with task switches.
  """
end
