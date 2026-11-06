defmodule XpressbusWeb.AgentLive do
  use XpressbusWeb, :live_view

  alias Xpressbus.Agents
  alias Xpressbus.Agents.AgentApplication
  alias Xpressbus.AgentApplicationEmail

  def mount(_params, _session, socket) do
    agent_url = XpressbusWeb.Endpoint.url() <> "/agent"

    {:ok,
     socket
     |> assign(:page_title, "Komiuta Agent — Agent sign-up")
     |> assign(
       :page_description,
       "Join the Komiuta Agent app. Sign up to sell bus tickets, manage bookings and serve travellers."
     )
     |> assign(:page_canonical, agent_url)
     |> assign(:page_manifest, "/agent-manifest.json")
     |> assign(:page_app_name, "Komiuta Agent")
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
        _ = AgentApplicationEmail.deliver_applicant(application)
        _ = AgentApplicationEmail.deliver_admin(application)

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
end
