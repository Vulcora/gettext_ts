defmodule GettextTs.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/Vulcora/gettext_ts"

  def project do
    [
      app: :gettext_ts,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "Gettext catalogs generated to TypeScript — backend-derived i18n for split Elixir/TS apps",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:expo, "~> 1.0"},
      {:gettext, "~> 0.26 or ~> 1.0", optional: true},
      {:spark, "~> 2.0", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "gettext_ts",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [main: "readme", source_ref: "v#{@version}", extras: ["README.md", "CHANGELOG.md"]]
  end
end
