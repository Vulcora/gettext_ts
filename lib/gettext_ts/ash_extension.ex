if Code.ensure_loaded?(Spark.Dsl.Extension) do
  defmodule GettextTs.AshExtension do
    @moduledoc """
    Registers `mix gettext_ts.codegen` with `mix ash.codegen` via Ash's
    generic codegen callback. Add to any domain:

        use Ash.Domain, extensions: [GettextTs.AshExtension]
    """
    use Spark.Dsl.Extension

    def codegen(args) do
      Mix.Task.reenable("gettext_ts.codegen")
      Mix.Task.run("gettext_ts.codegen", args)
    end
  end
end
