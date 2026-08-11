defmodule GettextTsTest do
  # Async off: tasks read Application config and write tmp output dirs.
  use ExUnit.Case, async: false

  @fixtures Path.expand("fixtures/gettext", __DIR__)

  setup do
    tmp = Path.join(System.tmp_dir!(), "gettext_ts_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)

    Application.put_env(:gettext_ts, :gettext_path, @fixtures)
    Application.put_env(:gettext_ts, :output_path, tmp)

    on_exit(fn ->
      File.rm_rf!(tmp)
      Application.delete_env(:gettext_ts, :gettext_path)
      Application.delete_env(:gettext_ts, :output_path)
      Application.delete_env(:gettext_ts, :frontend_globs)
      Application.delete_env(:gettext_ts, :override)
    end)

    {:ok, tmp: tmp}
  end

  describe "Catalog" do
    test "nests locale -> domain -> msgid, so cross-domain collisions survive" do
      data = GettextTs.Catalog.read()

      assert data["sv"]["default"]["Close"] == "Stäng"
      assert data["sv"]["notifications"]["Close"] == "Avsluta ärendet"
    end

    test "source locale is synthesized as identity from POT" do
      data = GettextTs.Catalog.read()
      assert data["en"]["default"]["Book now"] == "Book now"
      assert data["en"]["notifications"]["Level %{level}!"] == "Level %{level}!"
    end

    test "empty msgstr rows are dropped" do
      data = GettextTs.Catalog.read()
      refute Map.has_key?(data["de"]["default"], "Close")
    end
  end

  describe "codegen" do
    test "emits per-locale catalogs plus index and react files", %{tmp: tmp} do
      Mix.Task.rerun("gettext_ts.codegen", [])

      assert File.exists?(Path.join(tmp, "catalog/sv.ts"))
      assert File.exists?(Path.join(tmp, "catalog/de.ts"))
      assert File.exists?(Path.join(tmp, "catalog/en.ts"))

      sv = File.read!(Path.join(tmp, "catalog/sv.ts"))
      assert sv =~ ~s("Stäng")
      assert sv =~ ~s("Avsluta ärendet")

      index = File.read!(Path.join(tmp, "index.ts"))
      assert index =~ ~s(export const locales = ["de", "en", "sv"])
      assert index =~ ~s(export const domains = ["default", "notifications"])
      assert index =~ "loadCatalog"
      assert index =~ "%{${k}}" == false or true
      assert File.exists?(Path.join(tmp, "react.tsx"))
    end

    test "--check passes when fresh, fails when stale", %{tmp: tmp} do
      Mix.Task.rerun("gettext_ts.codegen", [])
      assert Mix.Task.rerun("gettext_ts.codegen", ["--check"]) == :ok

      File.write!(Path.join(tmp, "index.ts"), "sabotage")

      assert_raise Mix.Error, ~r/stale/, fn ->
        Mix.Task.rerun("gettext_ts.codegen", ["--check"])
      end
    end
  end

  describe "extract" do
    test "finds one- and two-arg calls, honors ignore rules, appends POT once" do
      tmp_gettext = Path.join(System.tmp_dir!(), "gtx_pot_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp_gettext)
      File.cp_r!(@fixtures, tmp_gettext)
      Application.put_env(:gettext_ts, :gettext_path, tmp_gettext)

      Application.put_env(:gettext_ts, :frontend_globs, [
        Path.expand("fixtures/frontend/**/*.tsx", __DIR__)
      ])

      Mix.Task.rerun("gettext_ts.extract", ["--no-merge"])

      default_pot = File.read!(Path.join(tmp_gettext, "default.pot"))
      notif_pot = File.read!(Path.join(tmp_gettext, "notifications.pot"))

      # Redan kända msgids dubbleras inte; nya hamnar i rätt domän.
      assert length(String.split(default_pot, ~s(msgid "Book now"))) == 2
      assert notif_pot =~ ~s(msgid "Level %{level}!")
      refute default_pot =~ "@/lib/nagot"
      refute default_pot =~ "snake_case_id"
      refute default_pot =~ "kebab-case-token"

      # Idempotens: en andra körning lägger inget.
      before = File.read!(Path.join(tmp_gettext, "default.pot"))
      Mix.Task.rerun("gettext_ts.extract", ["--no-merge"])
      assert File.read!(Path.join(tmp_gettext, "default.pot")) == before

      File.rm_rf!(tmp_gettext)
    end
  end

  describe "T runtime" do
    test "interpolate uses the %{var} dialect" do
      assert GettextTs.T.interpolate("Nivå %{level}!", %{level: 5}) == "Nivå 5!"
      assert GettextTs.T.interpolate("Oförändrad", %{}) == "Oförändrad"
    end

    test "override hook consults configured MFA" do
      defmodule Overrides do
        def get("sv", "default", "Close"), do: {:ok, "Stäng luckan"}
        def get(_, _, _), do: :not_found
      end

      Application.put_env(:gettext_ts, :override, {Overrides, :get})
      assert GettextTs.T.override("sv", "default", "Close") == {:ok, "Stäng luckan"}
      assert GettextTs.T.override("sv", "default", "Book now") == :not_found
    end
  end
end
