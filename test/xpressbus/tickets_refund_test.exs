defmodule Xpressbus.TicketsRefundTest do
  use Xpressbus.DataCase

  import Swoosh.TestAssertions

  alias Xpressbus.{Accounts, Repo, Tickets}
  alias Xpressbus.Payments.Payment

  defp ticket_fixture do
    unique = System.unique_integer([:positive])
    phone = "07" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0"))

    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Refund Tester",
        "phone" => phone,
        "email" => "refund#{unique}@example.com"
      })

    {:ok, ticket} =
      Tickets.create_ticket(%{
        "ticket_id" => "TKT-REF-#{unique}",
        "from" => "Nairobi",
        "to" => "Mombasa",
        "travel_date" => Date.utc_today(),
        "departure" => "08:00",
        "arrival" => "14:00",
        "company" => "Refund Coaches",
        "price" => "KSH 1,500",
        "seats" => ["1A"],
        "passenger_name" => user.name,
        "passenger_phone" => user.phone,
        "payment_method" => "mpesa",
        "status" => "confirmed"
      })

    {:ok, payment} =
      Repo.insert(%Payment{
        provider: "mpesa",
        amount: 1500,
        status: "success",
        reference: "MPESA-#{unique}",
        ticket_id: ticket.ticket_id,
        phone_number: user.phone,
        raw_response: %{}
      })

    %{user: user, ticket: ticket, payment: payment}
  end

  test "cancels the ticket, records the refund and notifies the traveller" do
    %{user: user, ticket: ticket, payment: payment} = ticket_fixture()

    Application.put_env(:xpressbus, :sms_send_fun, fn to, message ->
      send(self(), {:sms_sent, to, message})
      {:ok, %{provider: :test}}
    end)

    on_exit(fn -> Application.delete_env(:xpressbus, :sms_send_fun) end)

    assert {:ok, result} =
             Tickets.cancel_and_refund(
               ticket,
               %{
                 "refund_amount" => "1500",
                 "reason" => "Customer request",
                 "reference" => "REV-123"
               },
               7
             )

    assert result.ticket.status == "cancelled"
    assert result.ticket.refund_amount == 1500
    assert result.ticket.refund_reference == "REV-123"
    assert result.refund.amount == 1500
    assert result.refund.email_sent
    assert result.refund.sms_sent

    assert Repo.get!(Payment, payment.id).status == "cancelled"

    assert_receive {:sms_sent, to, message}
    assert to == "+254" <> String.trim_leading(user.phone, "0")
    assert message =~ "we're sorry"
    assert message =~ ticket.ticket_id
    assert message =~ "KES 1500"

    assert_email_sent(fn email ->
      assert email.to == [{user.name, user.email}]
      assert email.subject =~ "apologies"
      assert email.subject =~ ticket.ticket_id
      assert email.text_body =~ "sincerely apologise"
      assert email.text_body =~ "KES 1500"
      assert email.text_body =~ "REV-123"
    end)

    assert [refund] = Tickets.refunds_for_ticket(ticket.ticket_id)
    assert refund.reference == "REV-123"
  end

  test "refuses to cancel an already cancelled ticket" do
    %{ticket: ticket} = ticket_fixture()
    Application.put_env(:xpressbus, :sms_send_fun, fn _, _ -> {:ok, %{}} end)
    on_exit(fn -> Application.delete_env(:xpressbus, :sms_send_fun) end)

    assert {:ok, _} = Tickets.cancel_and_refund(ticket, %{"refund_amount" => 1500}, 1)

    assert {:error, :already_cancelled} =
             Tickets.cancel_and_refund(ticket, %{refund_amount: 1500}, 1)
  end

  test "still records the refund when SMS is not configured" do
    %{ticket: ticket} = ticket_fixture()

    assert {:ok, result} =
             Tickets.cancel_and_refund(
               ticket,
               %{"refund_amount" => "1200", "reason" => "Goodwill"},
               1
             )

    assert match?({:ok, _}, result.email)
    assert result.sms == {:error, :not_configured}
    refute result.refund.sms_sent
    assert result.refund.notification_details["sms"] == "not_configured"
  end

  test "parses prices such as KSH 1,500" do
    assert Tickets.parse_amount("KSH 1,500") == 1500
    assert Tickets.parse_amount(2400) == 2400
    assert Tickets.parse_amount("free") == nil
  end
end
