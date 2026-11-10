defmodule XpressbusWeb.AdminTicketsLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Xpressbus.{Accounts, Repo, Tickets}
  alias Xpressbus.Payments.Payment

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  defp fixture do
    unique = System.unique_integer([:positive])
    phone = "07" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0"))

    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Admin Refund Tester",
        "phone" => phone,
        "email" => "adminrefund#{unique}@example.com"
      })

    {:ok, ticket} =
      Tickets.create_ticket(%{
        "ticket_id" => "TKT-ADMIN-#{unique}",
        "from" => "Nairobi",
        "to" => "Kisumu",
        "travel_date" => Date.utc_today(),
        "departure" => "09:00",
        "arrival" => "15:00",
        "company" => "Admin Coaches",
        "price" => "KES 1,800",
        "seats" => ["2B"],
        "passenger_name" => user.name,
        "passenger_phone" => user.phone,
        "payment_method" => "mpesa",
        "status" => "confirmed"
      })

    Repo.insert!(%Payment{
      provider: "mpesa",
      amount: 1800,
      status: "success",
      reference: "ADMIN-PAY-#{unique}",
      ticket_id: ticket.ticket_id,
      phone_number: user.phone,
      raw_response: %{}
    })

    %{user: user, ticket: ticket}
  end

  test "non-admin users are sent to the admin login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, ~p"/admin/tickets")
  end

  test "lists tickets and opens the refund dialog", %{conn: conn} do
    %{ticket: ticket} = fixture()

    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/tickets")

    assert html =~ ticket.ticket_id
    assert html =~ "Refund a ticket"

    view
    |> element("button[phx-value-ticket_id='#{ticket.ticket_id}']")
    |> render_click()

    assert has_element?(view, "#cancel-ticket-form")
    assert render(view) =~ "Cancel &amp; refund"
  end

  test "cancels and refunds a ticket with email and SMS notifications", %{conn: conn} do
    %{user: user, ticket: ticket} = fixture()
    test_pid = self()

    Application.put_env(:xpressbus, :sms_send_fun, fn to, message ->
      send(test_pid, {:sms_sent, to, message})
      {:ok, %{provider: :test}}
    end)

    on_exit(fn -> Application.delete_env(:xpressbus, :sms_send_fun) end)

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/tickets")

    view
    |> element("button[phx-value-ticket_id='#{ticket.ticket_id}']")
    |> render_click()

    view
    |> element("#cancel-ticket-form")
    |> render_submit(%{
      "ticket_id" => ticket.ticket_id,
      "refund" => %{
        "amount" => "1800",
        "reason" => "Operator cancelled the trip",
        "reference" => "REV-ADMIN-1"
      }
    })

    updated = Tickets.get_ticket(ticket.ticket_id)
    assert updated.status == "cancelled"
    assert updated.refund_amount == 1800
    assert Repo.get_by!(Payment, ticket_id: ticket.ticket_id).status == "cancelled"

    assert_email_sent(fn email ->
      assert email.to == [{user.name, user.email}]
      assert email.text_body =~ "sincerely apologise"
      assert email.text_body =~ ticket.ticket_id
    end)

    assert_receive {:sms_sent, "+254" <> _digits, message}
    assert message =~ ticket.ticket_id
  end
end
