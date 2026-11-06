defmodule XpressbusWeb.PWATest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @priv Path.join(@root, "priv/static")

  defp priv(path), do: File.read!(Path.join(@priv, path))
  defp source(path), do: File.read!(Path.join(@root, path))

  test "web app manifest is valid and installable" do
    manifest = @priv |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()

    assert manifest["name"] == "KOMIUTA APP"
    assert manifest["short_name"] == "KOMIUTA"
    assert manifest["start_url"] == "/"
    assert manifest["scope"] == "/"
    assert manifest["display"] == "standalone"
    assert manifest["theme_color"] == "#FF4C00"
    assert manifest["background_color"] == "#FF4C00"

    icons = manifest["icons"]
    assert Enum.any?(icons, &(&1["sizes"] == "192x192" and &1["type"] == "image/png"))
    assert Enum.any?(icons, &(&1["sizes"] == "512x512"))
    assert Enum.any?(icons, &(&1["purpose"] == "maskable"))
    assert Enum.any?(icons, &(&1["src"] == "/images/app-icon-192.png"))

    for icon <- icons do
      assert File.exists?(Path.join(@priv, String.trim_leading(icon["src"], "/"))),
             "missing manifest icon #{icon["src"]}"
    end

    assert Enum.any?(manifest["shortcuts"], &(&1["url"] == "/tickets"))
    assert "offline.html" in XpressbusWeb.static_paths()
  end

  test "the two installable PWAs have distinct colour identities" do
    main = @priv |> Path.join("manifest.json") |> File.read!() |> Jason.decode!()
    agent = @priv |> Path.join("agent-manifest.json") |> File.read!() |> Jason.decode!()

    # KOMIUTA (main app): brand orange chrome + orange splash/icon.
    assert main["name"] == "KOMIUTA APP"
    assert main["theme_color"] == "#FF4C00"
    assert main["background_color"] == "#FF4C00"
    assert Enum.any?(main["icons"], &(&1["src"] == "/images/app-icon-192.png"))

    # KOMIUTA Agent: white chrome + white splash/icon so it is easy to tell
    # the two installed apps apart on a phone home screen.
    assert agent["name"] == "KOMIUTA Agent"
    assert agent["start_url"] == "/agent"
    assert agent["scope"] == "/agent"
    assert agent["theme_color"] == "#ffffff"
    assert agent["background_color"] == "#ffffff"
    assert Enum.any?(agent["icons"], &(&1["src"] == "/images/agent-icon-192.png"))

    for icon <- agent["icons"] do
      assert File.exists?(Path.join(@priv, String.trim_leading(icon["src"], "/"))),
             "missing agent manifest icon #{icon["src"]}"
    end

    # The icon artwork itself differs: orange background vs white background.
    assert File.read!(Path.join(@priv, "images/app-icon-192.png")) !=
             File.read!(Path.join(@priv, "images/agent-icon-192.png"))

    assert File.read!(Path.join(@priv, "images/app-icon-512.png")) !=
             File.read!(Path.join(@priv, "images/agent-icon-512.png"))

    assert File.read!(Path.join(@priv, "images/app-icon-maskable-512.png")) !=
             File.read!(Path.join(@priv, "images/agent-icon-maskable-512.png"))

    # Agent pages pin the white identity, including the iOS status bar icon.
    agent_live = source("lib/xpressbus_web/live/agent_live.ex")
    agent_controller = source("lib/xpressbus_web/controllers/agent_session_controller.ex")

    for agent_source <- [agent_live, agent_controller] do
      assert agent_source =~ ~s("/agent-manifest.json")
      assert agent_source =~ ~s("#ffffff")
      assert agent_source =~ ~s(/images/agent-icon-180.png)
    end
  end

  test "OTP fields autofill from SMS WebOTP and email code links" do
    js = source("assets/js/otp_autofill.js")
    app_js = source("assets/js/app.js")

    assert js =~ "OTPCredential"
    assert js =~ "navigator.credentials"
    assert js =~ "one-time-code"
    assert js =~ "#code"
    assert js =~ "clipboard"
    assert app_js =~ "initOtpAutofill"

    assert source("lib/xpressbus_web/controllers/user_html/verify.html.heex") =~
             ~s(autocomplete="one-time-code")

    assert source("lib/xpressbus_web/controllers/agent_session_html/verify.html.heex") =~
             ~s(autocomplete="one-time-code")
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
