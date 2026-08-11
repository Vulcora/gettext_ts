defmodule GettextTs.Config do
  @moduledoc "Configuration access with defaults. All keys under `:gettext_ts`."

  def gettext_path, do: get(:gettext_path, "priv/gettext")
  def output_path, do: get(:output_path, "assets/js/i18n")
  def source_locale, do: get(:source_locale, "en")
  def default_domain, do: get(:default_domain, "default")
  def frontend_globs, do: get(:frontend_globs, ["assets/js/**/*.{ts,tsx}"])
  def extract_function, do: get(:extract_function, "t")
  def domain_hook, do: get(:domain_hook, "useT")
  def react?, do: get(:react, true)

  @default_ignores [
    ~r|^@?/|,
    ~r|^\.\.?/|,
    ~r/^[a-z][a-z0-9_]*$/,
    ~r/^[a-z]+-[a-z]+/,
    ~r/\n/
  ]

  @doc """
  Ignore rules for the frontend scanner: import paths, bare identifiers,
  kebab-case tokens and multiline strings are not copy. `:defaults` uses the
  built-in list; a custom list of regexes replaces it entirely.
  """
  def extract_ignore do
    case get(:extract_ignore, :defaults) do
      :defaults -> @default_ignores
      list when is_list(list) -> list
    end
  end

  defp get(key, default), do: Application.get_env(:gettext_ts, key, default)
end
