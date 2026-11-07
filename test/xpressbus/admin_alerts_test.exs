defmodule Xpressbus.AdminAlertsTest do
  use ExUnit.Case, async: false

  import Swoosh.TestAssertions

  alias Xpressbus.AdminAlertEmail
  alias Xpressbus.AdminAlerts
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Tickets.Ticket

  setup do
    Application.put_env(:xpressbus, :admin_alert_emails, ["komondiedward@gmail.com"])

    on_exit(fn ->
      Application.put_env(:xpressbus, :admin_alert_emails, [])
    end)
  end

  defp ticket do
    %Ticket{
      ticket_id: "TKT-ALERT-1",
      from: "Nairobi",
      to: "Mombasa",
      travel_date: ~D[2026-11-08],
      departure: "08:00 AM",
      seats: "4,5",
      passenger_name: "Test Passenger",
      passenger_phone: "0712345678",
      company: "Test Coach",
      price: "KSH 1,800",
      status: "confirmed",
      inserted_at: ~U[2026-11-06 09:30:00Z]
    }
  end

  defp payment do
    %Payment{
      provider: "mpesa",
      amount: 1800,
      currency: "KES",
      status: "success",
      reference: "PAY-ALERT-1"
    }
  end

  test "the nominated comms address is the default alert recipient" do
    assert AdminAlerts.recipients() == ["komondiedward@gmail.com"]
  end

  test "sends one booking and payment alert email with full details" do
    assert :ok = AdminAlertEmail.deliver(ticket(), payment())

    assert_email_sent(fn email ->
      assert email.subject == "New booking & payment received — TKT-ALERT-1"
      assert Enum.any?(email.to, fn {_name, address} -> address == "komondiedward@gmail.com" end)
      assert email.text_body =~ "Nairobi -> Mombasa"
      assert email.text_body =~ "Test Passenger"
      assert email.text_body =~ "KES 1,800"
      assert email.text_body =~ "mpesa"
      assert email.html_body =~ "New booking & payment received"
      assert email.html_body =~ "/images/logo_email.png"
      assert email.html_body =~ ~s(alt="Komiuta")
      assert email.html_body =~ "PAY-ALERT-1"
    end)
  end

  test "sends a payment alert when a ticket was already created" do
    assert :ok = AdminAlertEmail.deliver_payment(ticket(), payment())

    assert_email_sent(fn email ->
      assert email.subject == "Payment received — TKT-ALERT-1"
      assert email.text_body =~ "Payment received"
      assert email.text_body =~ "PAY-ALERT-1"
    end)
  end

  test "ignores malformed recipient addresses" do
    Application.put_env(:xpressbus, :admin_alert_emails, [
      "komondiedward@gmail.com",
      "not-an-email",
      "ops@example.com"
    ])

    assert AdminAlerts.recipients() == ["komondiedward@gmail.com", "ops@example.com"]
  end
end
