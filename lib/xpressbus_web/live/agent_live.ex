defmodule XpressbusWeb.AgentLive do
  use XpressbusWeb, :live_view

  alias Xpressbus.Agents
  alias Xpressbus.Agents.AgentApplication
  alias Xpressbus.AgentNotifications

  def mount(_params, session, socket) do
    if session["agent_id"] do
      {:ok, redirect(socket, to: "/agent/account")}
    else
      agent_url = agent_origin(socket) <> "/agent"

      {:ok,
       socket
       |> assign(:page_title, "KOMIUTA Agent — Agent sign-up")
       |> assign(
         :page_description,
         "Join the KOMIUTA Agent app. Sign up to sell bus tickets, manage bookings and serve travellers."
       )
       |> assign(:page_canonical, agent_url)
       |> assign(:page_manifest, "/agent-manifest.json")
       |> assign(:page_app_name, "KOMIUTA Agent")
       |> assign(:page_apple_touch_icon, "/images/agent-icon-180.png")
       |> assign(:page_theme_color, "#ffffff")
       |> assign(:page_robots, "index,follow")
       |> assign(:agent_url, agent_url)
       |> assign(
         :agent_qr,
         XpressbusWeb.QRCode.svg(agent_url,
           aria_label: "Scan to open the Komiuta Agent sign-up app",
           size: 148
         )
       )
       |> assign(:submitted, nil)
       |> assign_application_form()}
    end
  end

  def handle_event("validate", %{"agent_application" => attrs}, socket) do
    form =
      %AgentApplication{}
      |> AgentApplication.changeset(attrs)
      |> to_form(action: :validate)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit", %{"agent_application" => attrs}, socket) do
    case Agents.create_application(attrs) do
      {:ok, application} ->
        _ = AgentNotifications.notify(application, :registered)

        {:noreply,
         assign(socket,
           submitted: application,
           form: to_form(AgentApplication.changeset(%AgentApplication{}, %{}))
         )}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Please check the highlighted details and try again.")
         |> assign(:form, to_form(changeset))}
    end
  end

  def handle_event("new_application", _params, socket) do
    {:noreply, assign(socket, submitted: nil) |> assign_application_form()}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  defp assign_application_form(socket) do
    assign(
      socket,
      :form,
      %AgentApplication{}
      |> AgentApplication.changeset(%{})
      |> to_form()
    )
  end

  defp agent_origin(%{host_uri: %URI{host: host}}) when is_binary(host) do
    if String.starts_with?(host, "agent.") do
      "https://" <> host
    else
      XpressbusWeb.Endpoint.url()
    end
  end

  defp agent_origin(_socket), do: XpressbusWeb.Endpoint.url()
end
