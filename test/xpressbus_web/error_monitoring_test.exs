defmodule XpressbusWeb.ErrorMonitoringTest do
  use ExUnit.Case, async: false

  alias XpressbusWeb.ErrorMonitoring

  defp conn(path, opts \\ []) do
    request_id = Keyword.get(opts, :request_id, "req-test-123")

    Plug.Test.conn("GET", path)
    |> Plug.Conn.put_status(500)
    |> Plug.Conn.assign(:request_id, request_id)
  end

  test "critical 500s cast an alert with route and request id" do
    ErrorMonitoring.handle_event(
      [:phoenix, :endpoint, :stop],
      %{duration: 2_000_000},
      %{conn: conn("/dashboard?tab=bus")},
      self()
    )

    assert_receive {:"$gen_cast", {:web_error, details}}, 500
    assert details.path == "/dashboard"
    assert details.method == "GET"
    assert details.status == 500
    assert details.request_id == "req-test-123"
    assert details.query_string == "tab=bus"
    assert ErrorMonitoring.format(details) =~ "request_id=req-test-123"
  end

  test "non-critical routes do not trigger operations alerts" do
    ErrorMonitoring.handle_event(
      [:phoenix, :endpoint, :stop],
      %{duration: 2_000_000},
      %{conn: conn("/blog/some-post")},
      self()
    )

    refute_receive {:"$gen_cast", {:web_error, _details}}, 150
  end

  test "successful responses are ignored" do
    successful =
      Plug.Test.conn("GET", "/dashboard")
      |> Plug.Conn.put_status(200)
      |> Plug.Conn.assign(:request_id, "req-ok")

    ErrorMonitoring.handle_event(
      [:phoenix, :endpoint, :stop],
      %{duration: 2_000_000},
      %{conn: successful},
      self()
    )

    refute_receive {:"$gen_cast", {:web_error, _details}}, 150
  end
end
