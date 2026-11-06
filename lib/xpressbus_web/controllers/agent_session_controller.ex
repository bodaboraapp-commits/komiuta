defmodule XpressbusWeb.AgentSessionController do
  use XpressbusWeb, :controller

  alias Xpressbus.Agents

  def login(conn, _params) do
    if get_session(conn, :agent_id) do
      redirect(conn, to: "/agent/account")
    else
      render(conn, :login,
        page_title: "KOMIUTA Agent — Log in",
        page_manifest: "/agent-manifest.json",
        page_app_name: "KOMIUTA Agent",
        page_theme_color: "#ffffff",
        identifier: ""
      )
    end
  end

  def authenticate(conn, %{"agent" => params}) do
    identifier = String.trim(to_string(params["identifier"] || ""))
    password = to_string(params["password"] || "")

    case Agents.authenticate(identifier, password) do
      {:ok, application} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:agent_id, application.id)
        |> put_flash(
          :info,
          "Welcome back, #{first_name(application.full_name)}."
        )
        |> redirect(to: "/agent/account")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email/phone or password.")
        |> render(:login,
          page_title: "KOMIUTA Agent — Log in",
          page_manifest: "/agent-manifest.json",
          page_app_name: "KOMIUTA Agent",
          page_theme_color: "#ffffff",
          identifier: identifier
        )
    end
  end

  def account(conn, _params) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, application} ->
        render(conn, :account,
          page_title: "KOMIUTA Agent — Account",
          page_manifest: "/agent-manifest.json",
          page_app_name: "KOMIUTA Agent",
          page_theme_color: "#ffffff",
          agent: application
        )

      :error ->
        conn
        |> put_flash(:error, "Please log in to view your agent account.")
        |> redirect(to: "/agent/login")
    end
  end

  def set_password(conn, _params) do
    render(conn, :set_password,
      page_title: "KOMIUTA Agent — Set password",
      page_manifest: "/agent-manifest.json",
      page_app_name: "KOMIUTA Agent",
      page_theme_color: "#ffffff",
      identifier: "",
      reference: ""
    )
  end

  def update_password(conn, %{"agent" => params}) do
    identifier = String.trim(to_string(params["identifier"] || ""))
    reference = String.trim(to_string(params["reference"] || ""))

    attrs = %{
      "password" => to_string(params["password"] || ""),
      "password_confirmation" => to_string(params["password_confirmation"] || "")
    }

    case Agents.activate(identifier, reference, attrs) do
      {:ok, _application} ->
        conn
        |> put_flash(:info, "Password set. Log in with your new password.")
        |> redirect(to: "/agent/login")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "We could not match that email/phone and application reference.")
        |> render(:set_password,
          page_title: "KOMIUTA Agent — Set password",
          page_manifest: "/agent-manifest.json",
          page_app_name: "KOMIUTA Agent",
          page_theme_color: "#ffffff",
          identifier: identifier,
          reference: reference
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, changeset_error(changeset))
        |> render(:set_password,
          page_title: "KOMIUTA Agent — Set password",
          page_manifest: "/agent-manifest.json",
          page_app_name: "KOMIUTA Agent",
          page_theme_color: "#ffffff",
          identifier: identifier,
          reference: reference
        )
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:agent_id)
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: "/agent/login")
  end

  defp load_agent(nil), do: :error

  defp load_agent(agent_id) do
    case Agents.get_application(agent_id) do
      %{} = application -> {:ok, application}
      _ -> :error
    end
  end

  defp first_name(nil), do: "Agent"
  defp first_name(name), do: name |> to_string() |> String.split() |> List.first()

  defp changeset_error(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.flat_map(fn {_field, messages} -> messages end)
    |> Enum.uniq()
    |> case do
      [] -> "Please check your password details and try again."
      messages -> Enum.join(messages, " ")
    end
  end
end
