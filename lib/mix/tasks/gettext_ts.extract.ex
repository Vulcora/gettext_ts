defmodule Mix.Tasks.GettextTs.Extract do
  @moduledoc """
  Extracts `t("...")` msgids from frontend TypeScript/TSX files into the
  default domain's POT, then runs `mix gettext.merge` so every locale's PO
  picks them up.

  Both call shapes are recognized: `t("msgid")` (default domain) and
  `t("domain", "msgid")`. Globs, function name and ignore rules come from
  config (see `GettextTs`).

  A third shape carries the domain in the BINDING rather than the call:

      const tp = useT("admin");
      tp("Participant list");

  Every `const|let|var <name> = useT("<domain>")` in a file is picked up, and
  calls through that name are attributed to that domain. Without it a file
  that switched to a non-default domain would keep extracting into the
  default one — silently, since the msgid still lands in A catalog and the
  drift only shows as untranslated copy at runtime. The hook name is
  `:domain_hook` (default `"useT"`, the name the React emitter generates).

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
    ignores = Config.extract_ignore()

    Config.frontend_globs()
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.flat_map(fn file ->
      case File.read(file) do
        {:ok, content} -> scan_content(content)
        _ -> []
      end
    end)
    |> Enum.reject(fn {_d, id} -> Enum.any?(ignores, &Regex.match?(&1, id)) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {d, ids} -> {d, Enum.uniq(ids)} end)
  end

  @doc false
  # One file's `{domain, msgid}` pairs. Public for testing; the ignore rules
  # are applied by the caller.
  def scan_content(content) do
    fun = Config.extract_function()
    default = Config.default_domain()

    two_arg = ~r/\b#{Regex.escape(fun)}\(\s*"([^"]+)"\s*,\s*"([^"]+)"/
    two = Regex.scan(two_arg, content) |> Enum.map(fn [_, d, id] -> {d, id} end)

    # A msgid already claimed by a two-arg call must not be claimed again by
    # the one-arg pass reading the same characters.
    covered = MapSet.new(two, fn {_d, id} -> id end)

    bindings = Map.put_new(domain_bindings(content, default), fun, default)

    one =
      Enum.flat_map(bindings, fn {name, domain} ->
        ~r/\b#{Regex.escape(name)}\(\s*"([^"]+)"/
        |> Regex.scan(content)
        |> Enum.map(fn [_, id] -> id end)
        |> Enum.reject(&MapSet.member?(covered, &1))
        |> Enum.map(&{domain, &1})
      end)

    two ++ one
  end

  # `const t = useT("admin")` → `%{"t" => "admin"}`. A bare `useT()` binds the
  # default domain, which is also what an unbound call name gets — spelling it
  # out keeps the two paths one path.
  defp domain_bindings(content, default) do
    hook = Regex.escape(Config.domain_hook())

    ~r/(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*#{hook}\(\s*(?:"([^"]+)")?\s*\)/
    |> Regex.scan(content)
    |> Map.new(fn
      [_, name, domain] -> {name, domain}
      [_, name] -> {name, default}
    end)
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
