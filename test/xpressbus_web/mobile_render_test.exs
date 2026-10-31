defmodule XpressbusWeb.MobileRenderTest do
  @moduledoc """
  Renders the actual pages to make sure the mobile performance changes survive
  compilation of the HEEx templates (source-only checks are not enough — a
  stale compiled template once served an outdated hero).
  """

  use XpressbusWeb.ConnCase

  test "homepage renders the responsive hero and the local icon font", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "<picture"
    assert html =~ ~s(type="image/avif")
    assert html =~ "hero_bg-640.avif 640w"
    assert html =~ ~s(fetchpriority="high")
    assert html =~ "/fonts/material-symbols-subset.woff2"
    assert html =~ "imagesizes="
    refute html =~ "fonts.googleapis.com"
    refute html =~ "fonts.gstatic.com"
  end

  test "chyllz hub renders the desktop-only hero video", %{conn: conn} do
    html = conn |> get(~p"/tour-packages") |> html_response(200)

    assert html =~ ~s(phx-hook="HeroVideo")
    assert html =~ ~s(data-src="/images/hero_video.mp4")
    assert html =~ ~s(poster="/images/hero_bg-1024.webp")
    refute html =~ "autoplay"
    refute html =~ "<source src=\"/images/hero_video.mp4\""
  end
end
