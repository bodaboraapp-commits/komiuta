defmodule XpressbusWeb.DeviceCompatibilityTest do
  use XpressbusWeb.ConnCase

  alias XpressbusWeb.AssistantComponents
  alias XpressbusWeb.Plugs.EnsureViewport

  @mobile_viewport ~s(<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />)

  test "serves a real mobile viewport instead of a release marker", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~r/<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"/
    refute html =~ ~r/<meta name="viewport" content="20\d{2}-/
  end

  test "response safeguard repairs a viewport clobbered by release tooling" do
    conn =
      build_conn()
      |> Plug.Conn.put_resp_content_type("text/html")
      |> EnsureViewport.call([])
      |> Plug.Conn.send_resp(
        200,
        ~s(<html><head><meta name="viewport" content="2026-11-10.40-release" /></head></html>)
      )

    assert conn.resp_body =~ @mobile_viewport
    refute conn.resp_body =~ "2026-11-10.40-release"
  end

  test "the global assistant launcher stays off the AI trip builder" do
    refute AssistantComponents.show_global_launcher?("/trip/build-with-ai")
    assert AssistantComponents.show_global_launcher?("/")
  end
end
