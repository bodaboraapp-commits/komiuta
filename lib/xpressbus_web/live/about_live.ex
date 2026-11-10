defmodule XpressbusWeb.AboutLive do
  @moduledoc """
  About KOMIUTA: company story, what the platform does, coverage, payment
  security and support — the E-E-A-T/trust page for search and AI answers.
  """

  use XpressbusWeb, :live_view

  import XpressbusWeb.BrandComponents

  alias XpressbusWeb.SEO

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:step, :about)
     |> assign(:footer_tab, "about")
     |> assign(:current_user, session["user_id"])
     |> assign(:page_title, "About KOMIUTA — Bus Ticket Booking in East Africa")
     |> assign(
       :page_description,
       "KOMIUTA is an East African bus booking platform connecting travellers with 100+ bus operators across Kenya, Uganda and Tanzania. Compare fares, pick seats and pay with M-PESA, card or mobile money."
     )
     |> assign(:page_canonical, SEO.base_url() <> "/about")
     |> assign(:page_robots, "index,follow")
     |> assign(:page_json_ld, about_json_ld())}
  end

  @impl true
  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  defp about_json_ld do
    [
      SEO.organization(),
      %{
        "@context" => "https://schema.org",
        "@type" => "AboutPage",
        "name" => "About KOMIUTA",
        "url" => SEO.base_url() <> "/about",
        "description" =>
          "KOMIUTA is an East African bus booking platform connecting travellers with 100+ operators across Kenya, Uganda and Tanzania.",
        "mainEntity" => %{"@type" => "Organization", "name" => "KOMIUTA", "url" => SEO.base_url()}
      },
      SEO.breadcrumb([
        {"Home", SEO.base_url() <> "/"},
        {"About KOMIUTA", SEO.base_url() <> "/about"}
      ])
    ]
  end
end
