defmodule XpressbusWeb.AdminPricingLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Bookings.PricingSettings

  defp admin_conn(conn) do
    Plug.Test.init_test_session(conn, %{admin_id: 1})
  end

  test "admin sees the configured convenience fee and tax rate", %{conn: conn} do
    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/pricing")

    assert html =~ "Checkout Pricing"
    assert has_element?(view, "#pricing-form")
    assert has_element?(view, "input[name='pricing[convenience_fee]'][value='50']")
    assert has_element?(view, "input[name='pricing[tax_rate]'][value='0.0']")
  end

  test "sidebar starts with every section collapsed except Settings", %{conn: conn} do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/pricing")

    html = render(view)

    # Bus and Chyllz category bodies are hidden; only Settings is expanded.
    hidden_bodies = Regex.scan(~r/class="mt-2 hidden"/, html) |> length()
    assert hidden_bodies >= 2
    assert html =~ ~s(class="mt-2 block")
  end

  test "admin can update convenience fee and tax rate", %{conn: conn} do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/pricing")

    view
    |> form("#pricing-form",
      pricing: %{"convenience_fee" => "75", "tax_rate" => "16"}
    )
    |> render_submit()

    assert PricingSettings.get() == %{convenience_fee: 75, tax_rate: 16.0}
    assert render(view) =~ "Pricing settings saved"
  end

  test "invalid values are rejected", %{conn: conn} do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/pricing")

    view
    |> form("#pricing-form", pricing: %{"convenience_fee" => "-5", "tax_rate" => "16"})
    |> render_submit()

    assert PricingSettings.get() == %{convenience_fee: 50, tax_rate: 0.0}
    assert render(view) =~ "Please correct the highlighted fields"
  end
end
