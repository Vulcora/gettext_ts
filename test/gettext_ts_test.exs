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

    test "include_source: false leaves the identity locale out" do
      data = GettextTs.Catalog.read(@fixtures, include_source: false)

      refute Map.has_key?(data, "en")
      assert Map.has_key?(data, "sv")
    end
  end

  describe "codegen" do
    test "emits ONE FILE PER LOCALE AND DOMAIN, plus index and react", %{tmp: tmp} do
      Mix.Task.rerun("gettext_ts.codegen", [])

      assert File.exists?(Path.join(tmp, "catalog/sv/default.ts"))
      assert File.exists?(Path.join(tmp, "catalog/sv/notifications.ts"))
      assert File.exists?(Path.join(tmp, "catalog/de/default.ts"))

      # The domain is the unit of loading: a locale file would put every
      # domain in the bundle of whoever imports one of them.
      refute File.exists?(Path.join(tmp, "catalog/sv.ts"))

      sv_default = File.read!(Path.join(tmp, "catalog/sv/default.ts"))
      sv_notif = File.read!(Path.join(tmp, "catalog/sv/notifications.ts"))
      assert sv_default =~ ~s("Stäng")
      refute sv_default =~ ~s("Avsluta ärendet")
      assert sv_notif =~ ~s("Avsluta ärendet")

      index = File.read!(Path.join(tmp, "index.ts"))
      assert index =~ ~s(export const locales = ["de", "en", "sv"])
      assert index =~ ~s(export const domains = ["default", "notifications"])
      assert index =~ ~s[import("./catalog/sv/notifications")]
      assert File.exists?(Path.join(tmp, "react.tsx"))
    end

    test "the source locale gets no files — identity is what passthrough gives", %{tmp: tmp} do
      Mix.Task.rerun("gettext_ts.codegen", [])

      refute File.exists?(Path.join(tmp, "catalog/en"))

      index = File.read!(Path.join(tmp, "index.ts"))
      # Still a locale of the app, just not a downloadable one.
      assert index =~ ~s("en")
      refute index =~ ~s[import("./catalog/en/default")]
    end

    test "loadCatalog takes the domains to load", %{tmp: tmp} do
      Mix.Task.rerun("gettext_ts.codegen", [])
      index = File.read!(Path.join(tmp, "index.ts"))

      assert index =~ "only?: readonly Domain[]"
      assert index =~ "(only ?? domains)"
      # Partial, because a route tree loading two of five domains is the
      # normal case — a missing domain must not be a type error.
      assert index =~ "export type LocaleCatalog = Partial<Record<Domain, DomainCatalog>>"
      assert index =~ "domain: Domain = \"default\""
    end

    test "the provider accepts initialCatalog and a domains prop", %{tmp: tmp} do
      Mix.Task.rerun("gettext_ts.codegen", [])

      react = File.read!(Path.join(tmp, "react.tsx"))

      assert react =~ "initialCatalog?: LocaleCatalog"
      # Seeded as INITIAL STATE, not merged after mount: the server render has
      # to be translated already, otherwise the prop buys nothing.
      assert react =~ "useState<LocaleCatalog | null>(initialCatalog ?? null)"
      # And the lazy load stays — the prop seeds, it does not replace.
      assert react =~ "loadCatalog(locale, only)"
      assert react =~ "domains?: readonly Domain[]"
      # A fresh array literal must not restart the effect on every render.
      assert react =~ "JSON.stringify(domains ?? null)"
      assert react =~ "[locale, domainKey]"
      assert react =~ "useT(domain: Domain = \"default\")"
    end

    test "--check passes when fresh, fails when stale", %{tmp: tmp} do
      Mix.Task.rerun("gettext_ts.codegen", [])
      assert Mix.Task.rerun("gettext_ts.codegen", ["--check"]) == :ok

      File.write!(Path.join(tmp, "index.ts"), "sabotage")

      assert_raise Mix.Error, ~r/stale/, fn ->
        Mix.Task.rerun("gettext_ts.codegen", ["--check"])
      end
    end

    test "catalog files with no domain behind them are removed", %{tmp: tmp} do
      Mix.Task.rerun("gettext_ts.codegen", [])

      kvarleva = Path.join(tmp, "catalog/sv/borttagen.ts")
      File.write!(kvarleva, "export default {};")
      gammalt_upplagg = Path.join(tmp, "catalog/sv.ts")
      File.write!(gammalt_upplagg, "export default {};")

      # --check reports them rather than removing them.
      assert_raise Mix.Error, ~r/borttagen/, fn ->
        Mix.Task.rerun("gettext_ts.codegen", ["--check"])
      end

      assert File.exists?(kvarleva)

      Mix.Task.rerun("gettext_ts.codegen", [])
      refute File.exists?(kvarleva)
      refute File.exists?(gammalt_upplagg)
      assert File.exists?(Path.join(tmp, "catalog/sv/default.ts"))
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

    test "a domain bound with useT(\"...\") claims that file's calls" do
      tmp_gettext = Path.join(System.tmp_dir!(), "gtx_pot_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp_gettext)
      File.cp_r!(@fixtures, tmp_gettext)
      Application.put_env(:gettext_ts, :gettext_path, tmp_gettext)

      Application.put_env(:gettext_ts, :frontend_globs, [
        Path.expand("fixtures/frontend/panel.tsx", __DIR__)
      ])

      Mix.Task.rerun("gettext_ts.extract", ["--no-merge"])

      default_pot = File.read!(Path.join(tmp_gettext, "default.pot"))
      notif_pot = File.read!(Path.join(tmp_gettext, "notifications.pot"))

      # `const t = useT("notifications")` — the call says nothing about the
      # domain, and landing these in "default" is the silent failure this
      # exists to prevent.
      assert notif_pot =~ ~s(msgid "Case closed")
      refute default_pot =~ ~s(msgid "Case closed")

      # A binding under any other name is scanned too; the plain
      # extract_function name would never have matched `tp(`.
      assert notif_pot =~ ~s(msgid "Case reopened")

      # And a bare useT() is still the default domain.
      refute notif_pot =~ ~s(msgid "Book now")

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
