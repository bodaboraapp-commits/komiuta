defmodule XpressbusWeb.AgentLive do
  use XpressbusWeb, :live_view

  import XpressbusWeb.BrandComponents

  def mount(_params, _session, socket) do
    agent_url = XpressbusWeb.Endpoint.url() <> "/agent"

    {:ok,
     socket
     |> assign(:page_title, "Komiuta Agent App — Install the Agent PWA")
     |> assign(
       :page_description,
       "Install the Komiuta Agent PWA to sell bus tickets, manage bookings and support travellers from your phone or desktop."
     )
     |> assign(:page_canonical, agent_url)
     |> assign(:page_manifest, "/agent-manifest.json")
     |> assign(:page_app_name, "Komiuta Agent")
     |> assign(:page_robots, "index,follow")
     |> assign(:agent_url, agent_url)
     |> assign(
       :agent_qr,
       XpressbusWeb.QRCode.svg(agent_url,
         aria_label: "Scan to open and install the Komiuta Agent app",
         size: 176
       )
     )
     |> assign(:step, :agent)
     |> assign(:current_user, nil)
     |> assign(:footer_tab, "about")}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end
end
