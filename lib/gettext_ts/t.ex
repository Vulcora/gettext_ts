defmodule GettextTs.T do
  @moduledoc """
  The extractable translation macro, with a runtime override hook.

  `t(domain, msgid, bindings)` expands to a `dgettext` call — that is what
  `mix gettext.extract` sees in the AST, so no separate catalog module is
  needed. Before the compiled Gettext lookup, an optional override source is
  consulted: `config :gettext_ts, override: {Mod, :fun}` where
  `fun(locale, domain, msgid)` returns `{:ok, string}` or `:not_found`.
  That is the hook for admin-edited translations stored in a database
  (the pattern mosis proved with its ETS-cached TranslationOverride).

      use GettextTs.T, backend: MyAppWeb.Gettext

      t("default", "Authentication required")
      t("notifications", "Level %{level}!", level: 5)
  """

  defmacro __using__(opts) do
    backend = Keyword.fetch!(opts, :backend)

    quote do
      use Gettext, backend: unquote(backend)
      import GettextTs.T, only: [t: 2, t: 3]
      @gettext_ts_backend unquote(backend)
    end
  end

  defmacro t(domain, msgid, bindings \\ Macro.escape(%{})) do
    quote do
      locale = Gettext.get_locale(@gettext_ts_backend)

      case GettextTs.T.override(locale, unquote(domain), unquote(msgid)) do
        {:ok, override} ->
          GettextTs.T.interpolate(override, Map.new(unquote(bindings)))

        :not_found ->
          dgettext(unquote(domain), unquote(msgid), unquote(bindings))
      end
    end
  end

  @doc false
  def override(locale, domain, msgid) do
    case Application.get_env(:gettext_ts, :override) do
      {mod, fun} -> apply(mod, fun, [locale, domain, msgid])
      nil -> :not_found
    end
  end

  @doc "`%{var}` interpolation for override values — Gettext's dialect."
  def interpolate(string, bindings) when map_size(bindings) == 0, do: string

  def interpolate(string, bindings) do
    Enum.reduce(bindings, string, fn {key, val}, acc ->
      String.replace(acc, "%{#{key}}", to_string(val))
    end)
  end
end
