defmodule XpressbusWeb.UiPolishTest do
  use ExUnit.Case, async: true

  @emoji_ranges [0x1F300..0x1FAFF, 0x2600..0x27BF]

  test "UI templates do not use emoji as icons" do
    offenders =
      Path.wildcard("lib/**/*.heex")
      |> Enum.filter(fn path ->
        path
        |> File.read!()
        |> String.to_charlist()
        |> Enum.any?(fn codepoint ->
          Enum.any?(@emoji_ranges, &(codepoint in &1))
        end)
      end)

    assert offenders == [], "emoji icons remain in: #{Enum.join(offenders, ", ")}"
  end

  test "AI builder protects unsaved itinerary changes" do
    html = File.read!("lib/xpressbus_web/live/ai_trip_builder_live.html.heex")
    js = File.read!("assets/js/app.js")

    assert html =~ ~s(phx-hook="UnsavedChanges")
    assert html =~ ~s|data-dirty={to_string(@dirty)}|
    assert html =~ "Discard unsaved changes"
    assert js =~ "beforeunload"
    assert js =~ "UnsavedChanges"
  end

  test "signup, AI save/refine and Manage Itinerary emit analytics events" do
    signup = File.read!("lib/xpressbus_web/controllers/user_html/registration.html.heex")
    ai = File.read!("lib/xpressbus_web/live/ai_trip_builder_live.html.heex")
    itineraries = File.read!("lib/xpressbus_web/components/itinerary_components.ex")
    trip_cards = File.read!("lib/xpressbus_web/components/chyllz_account_components.ex")
    analytics = File.read!("assets/js/analytics.js")

    assert signup =~ ~s(data-track="signup_gmail_clicked")
    assert signup =~ ~s(data-track-view="signup_details_view")
    assert signup =~ ~s(data-track="signup_account_created")
    assert ai =~ ~s(data-track="ai_itinerary_saved")
    assert ai =~ ~s(data-track="ai_refine_clicked")
    assert itineraries =~ ~s(data-track="manage_itinerary_open")
    assert trip_cards =~ ~s(data-track="manage_itinerary_open")
    assert analytics =~ "data-track-view"
  end

  test "flash messages are accessible, dismissible success toasts" do
    source = File.read!("lib/xpressbus_web/components/core_components.ex")

    assert source =~ ~s(phx-hook="FlashAutoDismiss")
    assert source =~ ~s(role="status")
    assert source =~ ~s|aria-label={gettext("Close notification")}|
    refute source =~ "ℹ️"
    refute source =~ "⚠️"
  end
end
