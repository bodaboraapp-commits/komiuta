defmodule XpressbusWeb.PWATest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @priv Path.join(@root, "priv/static")

  defp priv(path), do: File.read!(Path.join(@priv, path))
  defp source(path), do: File.read!(Path.join(@root, path))

  test "web app manifest is valid and installable" do
    manifest = @priv |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()

    assert manifest["name"] =~ "Komiuta"
    assert manifest["short_name"] == "Komiuta"
    assert manifest["start_url"] == "/"
    assert manifest["scope"] == "/"
    assert manifest["display"] == "standalone"
    assert manifest["theme_color"] == "#FF4C00"
    assert manifest["background_color"] == "#ffffff"

    icons = manifest["icons"]
    assert Enum.any?(icons, &(&1["sizes"] == "192x192" and &1["type"] == "image/png"))
    assert Enum.any?(icons, &(&1["sizes"] == "512x512"))
    assert Enum.any?(icons, &(&1["purpose"] == "maskable"))

    for icon <- icons do
      assert File.exists?(Path.join(@priv, String.trim_leading(icon["src"], "/"))),
             "missing manifest icon #{icon["src"]}"
    end

    assert Enum.any?(manifest["shortcuts"], &(&1["url"] == "/tickets"))
    assert "offline.html" in XpressbusWeb.static_paths()
  end

  test "service worker provides an offline shell and leaves HTML uncached" do
    sw = priv("sw.js")

    assert sw =~ "/offline.html"
    assert sw =~ "networkFirstNavigation"
    assert sw =~ "SKIP_WAITING"
    assert sw =~ "staleWhileRevalidate"
    # Never cache navigation responses (stale/personal data) or call a QR API.
    refute sw =~ "caches.match('/')"
    refute sw =~ "qrserver"
    assert File.exists?(Path.join(@priv, "offline.html"))
  end

  test "offline page is branded and self-contained" do
    html = priv("offline.html")

    assert html =~ "You&#39;re offline" or html =~ "You're offline"
    assert html =~ "/images/logo_brand.png"
    refute html =~ "qrserver"
    refute html =~ "http://"
  end

  test "root layout declares the PWA shell and iOS metadata" do
    layout = source("lib/xpressbus_web/components/layouts/root.html.heex")

    assert layout =~ ~s(rel="manifest")
    assert layout =~ "apple-mobile-web-app-capable"
    assert layout =~ "apple-mobile-web-app-title"
    assert layout =~ "apple-touch-icon"
    assert layout =~ "theme-color"
  end

  test "app download section renders a local QR that opens the PWA" do
    template = source("lib/xpressbus_web/live/booking_live.html.heex")
    booking_live = source("lib/xpressbus_web/live/booking_live.ex")

    assert template =~ "@pwa_qr"
    assert template =~ "qr_app_section"
    assert booking_live =~ "pwa_qr()"
    assert booking_live =~ "XpressbusWeb.QRCode.svg"
    refute template =~ "qrserver"
    refute template =~ "api.qr"
  end

  test "install prompt is wired into the existing Download App links" do
    header = source("lib/xpressbus_web/components/brand_components.ex")
    app_js = source("assets/js/app.js")

    # The existing "Download App" links are reused for the install action.
    assert header =~ ~s(id="pwa-download-desktop")
    assert header =~ ~s(id="pwa-download-mobile")
    assert header =~ ~s(phx-hook=".InstallApp")
    # ...and still fall back to the download/store section.
    assert header =~ ~s(href="#app-section")
    refute header =~ ~s(id="pwa-install-desktop")
    refute header =~ ~s(id="pwa-install-mobile")

    assert app_js =~ "beforeinstallprompt"
    assert app_js =~ "serviceWorker.register('/sw.js')"
    assert app_js =~ "controllerchange"
  end
end
