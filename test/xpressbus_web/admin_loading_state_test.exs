defmodule XpressbusWeb.AdminLoadingStateTest do
  use ExUnit.Case, async: true

  @templates [
    "admin_banner_live.html.heex",
    "admin_bus_operator_live.html.heex",
    "admin_car_hire_live.html.heex",
    "admin_city_live.html.heex",
    "admin_coupon_live.html.heex",
    "admin_pricing_live.html.heex",
    "admin_integration_live.html.heex",
    "admin_agent_applications_live.html.heex"
  ]

  test "every save/delete action in the admin catalogue has a loading label" do
    for template <- @templates do
      html = File.read!("lib/xpressbus_web/live/#{template}")

      save_buttons = Regex.scan(~r/<button\b[^>]*type="submit"[^>]*>/s, html)
      delete_buttons = Regex.scan(~r/<button\b[^>]*phx-click="delete_[^"]*"[^>]*>/s, html)
      status_buttons = Regex.scan(~r/<button\b[^>]*phx-click="update_status"[^>]*>/s, html)

      for [button] <- save_buttons ++ delete_buttons ++ status_buttons do
        assert button =~ "phx-disable-with",
               "#{template} has a save/delete action without a loading label: #{button}"
      end
    end
  end

  test "specific loading labels are present" do
    banner = File.read!("lib/xpressbus_web/live/admin_banner_live.html.heex")
    assert banner =~ ~s(phx-disable-with="Saving...")

    integration = File.read!("lib/xpressbus_web/live/admin_integration_live.html.heex")
    assert integration =~ ~s(phx-disable-with="Saving...")

    agent_applications =
      File.read!("lib/xpressbus_web/live/admin_agent_applications_live.html.heex")

    assert agent_applications =~ ~s(phx-disable-with="Assigning...")
    assert agent_applications =~ ~s(phx-disable-with="Rejecting...")
    assert agent_applications =~ ~s(phx-disable-with="Updating...")
  end
end
