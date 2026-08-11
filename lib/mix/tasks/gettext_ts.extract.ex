defmodule Mix.Tasks.GettextTs.Extract do
  @moduledoc """
  Extracts `t("...")` msgids from frontend TypeScript/TSX files into the
  default domain's POT, then runs `mix gettext.merge` so every locale's PO
  picks them up.

  Both call shapes are recognized: `t("msgid")` (default domain) and
  `t("domain", "msgid")`. Globs, function name and ignore rules come from
  config (see `GettextTs`).

      mix gettext_ts.extract             # scan + POT + merge
      mix gettext_ts.extract --dry-run   # show findings only
      mix gettext_ts.extract --no-merge  # skip gettext.merge (tests/CI)
  """
  use Mix.Task

  @shortdoc "Extract frontend t() msgids into POT files"

  alias GettextTs.Config

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [dry_run: :boolean, merge: :boolean])

    found = scan()

    if opts[:dry_run] do
      for {domain, ids} <- found, id <- Enum.sort(ids) do
        Mix.shell().info("  #{domain}: #{String.slice(id, 0, 90)}")
      end
    else
      changed =
        for {domain, ids} <- found, reduce: 0 do
          acc -> acc + append_new(domain, ids)
        end

      if changed > 0 do
        Mix.shell().info("gettext_ts: added #{changed} msgid(s)")

        unless opts[:merge] == false do
          Mix.Task.run("gettext.merge", [Config.gettext_path(), "--no-fuzzy"])
        end
      end
    end
  end

  defp scan do
    fun = Regex.escape(Config.extract_function())
    two_arg = ~r/\b#{fun}\(\s*"([^"]+)"\s*,\s*"([^"]+)"/
    one_arg = ~r/\b#{fun}\(\s*"([^"]+)"/
    ignores = Config.extract_ignore()

    Config.frontend_globs()
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.flat_map(fn file ->
      case File.read(file) do
        {:ok, content} ->
          two = Regex.scan(two_arg, content) |> Enum.map(fn [_, d, id] -> {d, id} end)

          covered = MapSet.new(two, fn {_d, id} -> id end)

          one =
            Regex.scan(one_arg, content)
            |> Enum.map(fn [_, id] -> id end)
            |> Enum.reject(&MapSet.member?(covered, &1))
            |> Enum.map(&{Config.default_domain(), &1})

          two ++ one

        _ ->
          []
      end
    end)
    |> Enum.reject(fn {_d, id} -> Enum.any?(ignores, &Regex.match?(&1, id)) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {d, ids} -> {d, Enum.uniq(ids)} end)
  end

  defp append_new(domain, ids) do
    pot = Path.join(Config.gettext_path(), "#{domain}.pot")

    existing =
      case Expo.PO.parse_file(pot) do
        {:ok, %{messages: messages}} ->
          MapSet.new(
            for %Expo.Message.Singular{msgid: id} <- messages, do: IO.iodata_to_binary(id)
          )

        _ ->
          MapSet.new()
      end

    new = Enum.reject(ids, &MapSet.member?(existing, &1))

    if new == [] do
      0
    else
      base =
        case Expo.PO.parse_file(pot) do
          {:ok, po} -> po
          _ -> %Expo.Messages{messages: [], headers: []}
        end

      messages =
        Enum.map(new, fn id ->
          %Expo.Message.Singular{
            msgid: [id],
            msgstr: [""],
            comments: ["# Frontend: auto-extracted by mix gettext_ts.extract"]
          }
        end)

      File.mkdir_p!(Path.dirname(pot))
      File.write!(pot, Expo.PO.compose(%{base | messages: base.messages ++ messages}))
      length(new)
    end
  end
end
