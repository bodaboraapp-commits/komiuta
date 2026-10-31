defmodule XpressbusWeb.MobilePerfTest do
  @moduledoc """
  Guards the mobile loading fixes: responsive hero images, desktop-only hero
  video, subsetted local icon font, and lazy-loaded below-the-fold images.

  These are source-level regression checks so a future template edit cannot
  silently reintroduce a multi-megabyte phone download.
  """

  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @static Path.join(@root, "priv/static")

  defp source(path), do: File.read!(Path.join(@root, path))

  test "hero uses responsive AVIF/WebP sources and preloads the LCP image" do
    template = source("lib/xpressbus_web/live/booking_live.html.heex")
    layout = source("lib/xpressbus_web/components/layouts/root.html.heex")

    assert template =~ ~s(<picture)
    assert template =~ ~s(type="image/avif")
    assert template =~ ~s(type="image/webp")
    assert template =~ "hero_bg-640.avif 640w"
    assert template =~ "hero_bg-1573.avif 1573w"
    assert template =~ ~s(width="1573")
    assert template =~ ~s(height="452")
    assert template =~ ~s(fetchpriority="high")
    assert template =~ ~s(decoding="async")

    # Preload must use the same source set or the browser downloads it twice.
    assert layout =~ ~s(imagesizes="100vw")
    assert layout =~ "hero_bg-640.avif 640w"
    assert layout =~ "hero_bg-1024.webp"

    for width <- [640, 1024, 1573],
        ext <- ["avif", "webp"] do
      path = Path.join(@static, "images/hero_bg-#{width}.#{ext}")
      assert File.exists?(path), "missing #{Path.basename(path)}"
    end
  end

  test "hero video is a desktop-only enhancement (no phone download)" do
    chyllz = source("lib/xpressbus_web/live/chyllz_live.ex")
    app_js = source("assets/js/app.js")

    refute chyllz =~ ~s(<video\s+autoplay)
    refute chyllz =~ "<source src=\"/images/hero_video.mp4\""
    assert chyllz =~ ~s(phx-hook="HeroVideo")
    assert chyllz =~ ~s(data-src="/images/hero_video.mp4")
    assert chyllz =~ ~s(preload="none")
    assert chyllz =~ ~s(poster="/images/hero_bg-1024.webp")

    assert app_js =~ "const HeroVideo"
    assert app_js =~ "min-width: 768px"
    assert app_js =~ "saveData"
    assert app_js =~ "prefers-reduced-motion"
  end

  test "Material Symbols is a small self-hosted subset" do
    css = source("assets/css/app.css")
    layout = source("lib/xpressbus_web/components/layouts/root.html.heex")
    font = Path.join(@static, "fonts/material-symbols-subset.woff2")
    icons = Path.join(@root, "scripts/material-symbols-icons.txt")

    refute css =~ "fonts.googleapis.com"
    refute layout =~ "fonts.googleapis.com"
    assert css =~ ~s(font-family: "Material Symbols Outlined")
    assert css =~ "/fonts/material-symbols-subset.woff2"
    assert layout =~ "/fonts/material-symbols-subset.woff2"
    assert File.exists?(font)
    assert File.stat!(font).size > 3_000
    assert File.exists?(icons)

    # The about page uses the `verified` badge icon; make sure it is included in
    # the subset (a missing glyph falls back to the literal word "verified").
    icon_names = icons |> File.read!() |> String.split()
    assert "verified" in icon_names
  end

  test "below-the-fold images are lazy loaded with intrinsic dimensions" do
    template = source("lib/xpressbus_web/live/booking_live.html.heex")

    assert template =~ ~s(loading="lazy")
    assert template =~ ~s(fetchpriority="low")
    assert template =~ ~s(width="40")
    assert template =~ ~s(height="40")
    assert template =~ ~s(width="190")
    assert template =~ ~s(height="52")
  end

  test "room fallback images use compressed WebP" do
    chyllz = source("lib/xpressbus_web/live/chyllz_live.ex")

    assert chyllz =~ "/images/room_1.webp"
    assert chyllz =~ "/images/room_3.webp"

    for index <- 1..3 do
      path = Path.join(@static, "images/room_#{index}.webp")
      assert File.exists?(path)
      assert File.stat!(path).size < 40_000
    end
  end
end
