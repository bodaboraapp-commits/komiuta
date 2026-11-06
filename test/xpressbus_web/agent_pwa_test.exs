defmodule XpressbusWeb.AgentPwaTest do
  use XpressbusWeb.ConnCase

  test "agent page exposes the installable Agent PWA", %{conn: conn} do
    html = conn |> get(~p"/agent") |> html_response(200)

    assert html =~ "Komiuta Agent"
    assert html =~ "agent-install-button"
    assert html =~ "Install Agent App"
    assert html =~ ~s(href="/agent-manifest.json")
    assert html =~ "Add Komiuta Agent to your home screen"
    refute html =~ "api.qrserver.com"

    template =
      File.read!("lib/xpressbus_web/live/agent_live.html.heex")

    assert template =~ ~s(phx-hook=".AgentInstall")
    assert template =~ ~s(name=".AgentInstall")
  end

  test "agent manifest is installable and uses the existing app icons", %{conn: conn} do
    manifest =
      conn
      |> get(~p"/agent-manifest.json")
      |> response(200)
      |> Jason.decode!()

    assert manifest["id"] == "/agent"
    assert manifest["name"] == "Komiuta Agent"
    assert manifest["start_url"] == "/agent"
    assert manifest["display"] == "standalone"

    for icon <- manifest["icons"] do
      assert File.exists?(Path.join(["priv", "static", String.trim_leading(icon["src"], "/")]))
    end
  end
end
