defmodule GettextTs.Catalog do
  @moduledoc """
  Reads the Gettext tree into a nested `locale → domain → msgid → msgstr`
  structure. Nesting is the collision fix: the same msgid may legitimately
  carry different translations in different domains.
  """

  alias GettextTs.Config

  @doc "All locale directories under the gettext path, sorted."
  def locales(root \\ Config.gettext_path()) do
    case File.ls(root) do
      {:ok, entries} ->
        entries |> Enum.filter(&File.dir?(Path.join(root, &1))) |> Enum.sort()

      _ ->
        []
    end
  end

  @doc "All domains, derived from the .pot files, sorted."
  def domains(root \\ Config.gettext_path()) do
    case File.ls(root) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&String.ends_with?(&1, ".pot"))
        |> Enum.map(&String.trim_trailing(&1, ".pot"))
        |> Enum.sort()

      _ ->
        []
    end
  end

  @doc """
  `%{locale => %{domain => %{msgid => msgstr}}}` for every locale on disk,
  plus the source locale synthesized as identity (msgid == msgstr) from the
  POT files — the source language needs no PO catalog.

  ## Options

    * `:include_source` (default `true`) — synthesize the source locale. Pass
      `false` when identity is not worth materializing: `createT` falls back
      to the msgid, so an identity catalog is the copy handed back to itself.
      A source locale that DOES have PO files on disk is read from them
      either way; the option only governs the synthesis.
  """
  def read(root \\ Config.gettext_path(), opts \\ []) do
    domains = domains(root)

    maps =
      for locale <- locales(root), into: %{} do
        by_domain =
          for domain <- domains, into: %{} do
            {domain, po_entries(root, locale, domain)}
          end

        {locale, by_domain}
      end

    if Keyword.get(opts, :include_source, true) do
      source_map =
        for domain <- domains, into: %{} do
          ids = pot_msgids(root, domain)
          {domain, for(id <- ids, into: %{}, do: {id, id})}
        end

      Map.put_new(maps, Config.source_locale(), source_map)
    else
      maps
    end
  end

  @doc "Msgids per domain from the POT files: `%{domain => [msgid]}`, sorted."
  def pot_index(root \\ Config.gettext_path()) do
    for domain <- domains(root), into: %{} do
      {domain, root |> pot_msgids(domain) |> Enum.sort()}
    end
  end

  defp po_entries(root, locale, domain) do
    [root, locale, "LC_MESSAGES", "#{domain}.po"]
    |> Path.join()
    |> parse_singulars()
    |> Enum.reduce(%{}, fn m, acc ->
      msgstr = m.msgstr |> IO.iodata_to_binary()

      if String.trim(msgstr) == "" do
        acc
      else
        Map.put(acc, IO.iodata_to_binary(m.msgid), msgstr)
      end
    end)
  end

  defp pot_msgids(root, domain) do
    [root, "#{domain}.pot"]
    |> Path.join()
    |> parse_singulars()
    |> Enum.map(&IO.iodata_to_binary(&1.msgid))
  end

  defp parse_singulars(path) do
    case Expo.PO.parse_file(path) do
      {:ok, %{messages: messages}} ->
        Enum.filter(messages, &match?(%Expo.Message.Singular{}, &1))

      _ ->
        []
    end
  end
end
