defmodule XpressbusWeb.FirebasePhoneAuthParityTest do
  use XpressbusWeb.ConnCase, async: false

  import Ecto.Query

  alias Xpressbus.Accounts
  alias Xpressbus.Agents

  defp unique, do: System.unique_integer([:positive])

  defp phone(prefix) do
    prefix <> (unique() |> rem(1_000_000) |> Integer.to_string() |> String.pad_leading(6, "0"))
  end

  defp email(prefix), do: "#{prefix}#{unique()}@example.com"

  defp with_lookup(fun) do
    Application.put_env(:xpressbus, :firebase_lookup_fun, fun)
    on_exit(fn -> Application.delete_env(:xpressbus, :firebase_lookup_fun) end)
  end

  defp both_endpoints(token) do
    user_conn = post(build_conn(), "/user/firebase/verify", %{"id_token" => token})
    agent_conn = post(build_conn(), "/agent/firebase/verify", %{"id_token" => token})
    {user_conn, agent_conn}
  end

  test "traveller and agent sign-in return the same missing-token error", %{conn: conn} do
    user_conn = post(conn, "/user/firebase/verify", %{"id_token" => ""})
    agent_conn = post(recycle(conn), "/agent/firebase/verify", %{"id_token" => ""})

    assert user_conn.status == agent_conn.status
    assert json_response(user_conn, 400) == json_response(agent_conn, 400)
  end

  test "traveller and agent sign-in return the same invalid-token error" do
    with_lookup(fn _token -> {:error, :invalid_token} end)

    {user_conn, agent_conn} = both_endpoints("invalid-firebase-token")

    assert user_conn.status == agent_conn.status
    assert user_conn.status == 401
    assert json_response(user_conn, 401) == json_response(agent_conn, 401)
  end

  test "a verified number that works for a traveller also signs the agent in" do
    traveller_email = email("shared.agent")
    traveller_phone = phone("0711")

    {:ok, user} =
      Accounts.create_user(%{
        name: "Shared Agent",
        phone: traveller_phone,
        email: traveller_email
      })

    # The agent application uses the same verified email but a different phone
    # representation. The shared traveller identity must still resolve it.
    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Shared Agent",
        "business_name" => "Shared Travel",
        "email" => traveller_email,
        "phone" => phone("0722"),
        "city" => "Nairobi",
        "payout_method" => "mpesa"
      })

    with_lookup(fn token ->
      assert token == "shared-firebase-token"
      {:ok, "+254" <> String.trim_leading(user.phone, "0")}
    end)

    agent_conn =
      post(build_conn(), "/agent/firebase/verify", %{"id_token" => "shared-firebase-token"})

    assert json_response(agent_conn, 200)["ok"]
    assert get_session(agent_conn, :agent_id) == application.id
  end

  test "a verified phone resolves a legacy formatted agent application phone", %{conn: conn} do
    application_phone = phone("0744")

    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Legacy Agent",
        "business_name" => "Legacy Travel",
        "email" => email("legacy.agent"),
        "phone" => application_phone,
        "city" => "Nairobi",
        "payout_method" => "mpesa"
      })

    formatted =
      String.slice(application_phone, 0, 4) <>
        " " <>
        String.slice(application_phone, 4, 3) <>
        " " <>
        String.slice(application_phone, 7, 3)

    Xpressbus.Repo.update_all(
      from(a in Xpressbus.Agents.AgentApplication, where: a.id == ^application.id),
      set: [phone: formatted]
    )

    with_lookup(fn _token -> {:ok, "+254" <> String.trim_leading(application_phone, "0")} end)

    agent_conn =
      post(conn, "/agent/firebase/verify", %{"id_token" => "legacy-firebase-token"})

    assert json_response(agent_conn, 200)["ok"]
    assert get_session(agent_conn, :agent_id) == application.id
  end

  test "a verified phone resolves the agent application directly", %{conn: conn} do
    application_phone = phone("0733")

    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Direct Agent",
        "business_name" => "Direct Travel",
        "email" => email("direct.agent"),
        "phone" => application_phone,
        "city" => "Nairobi",
        "payout_method" => "mpesa"
      })

    with_lookup(fn _token -> {:ok, "+254" <> String.trim_leading(application_phone, "0")} end)

    agent_conn =
      post(conn, "/agent/firebase/verify", %{"id_token" => "direct-firebase-token"})

    assert json_response(agent_conn, 200)["ok"]
    assert get_session(agent_conn, :agent_id) == application.id
  end
end
