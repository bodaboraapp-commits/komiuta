defmodule XpressbusWeb.KeyboardNavigationTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  test "global dialog focus management covers focus trap, Escape and restoration" do
    source = File.read!(Path.join(@root, "assets/js/app.js"))

    assert source =~ "initDialogFocusManagement"
    assert source =~ "focusableIn"
    assert source =~ "event.key === \"Escape\""
    assert source =~ "event.key !== \"Tab\""
    assert source =~ "dialogPreviousFocus.focus"
    assert source =~ "MutationObserver"
  end

  test "dashboard and trip tabs support arrow, Home and End navigation" do
    app = File.read!(Path.join(@root, "assets/js/app.js"))
    tabs = File.read!(Path.join(@root, "lib/xpressbus_web/components/brand_components.ex"))
    trip_tabs = File.read!(Path.join(@root, "lib/xpressbus_web/live/trip_manage_live.html.heex"))

    assert app =~ "initTabArrowNavigation"
    assert app =~ "ArrowRight"
    assert app =~ "ArrowLeft"
    assert app =~ "Home"
    assert app =~ "End"
    assert tabs =~ "tabindex={if @active == @id, do: \"0\", else: \"-1\"}"
    assert trip_tabs =~ "tabindex={if @active_tab == key, do: \"0\", else: \"-1\"}"
  end
end
