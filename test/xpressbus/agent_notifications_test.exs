defmodule Xpressbus.AgentNotificationsTest do
  use Xpressbus.DataCase, async: false

  import Swoosh.TestAssertions

  alias Xpressbus.AgentNotifications
  alias Xpressbus.Agents

  setup do
    previous = Application.get_env(:xpressbus, :sms_send_fun)

    Application.put_env(:xpressbus, :sms_send_fun, fn to, message ->
      send(self(), {:agent_sms, to, message})
      {:ok, %{provider: :test}}
    end)

    on_exit(fn ->
      if is_nil(previous) do
        Application.delete_env(:xpressbus, :sms_send_fun)
      else
        Application.put_env(:xpressbus, :sms_send_fun, previous)
      end
    end)

    :ok
  end

  defp application do
    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Notify Agent",
        "business_name" => "Notify Travel",
        "email" => "notify.agent@example.com",
        "phone" => "0712345678",
        "city" => "Nairobi",
        "payout_method" => "mpesa",
        "password" => "agentpass123",
        "password_confirmation" => "agentpass123"
      })

    application
  end

  test "registration sends applicant email, admin email and SMS" do
    application = application()

    result = AgentNotifications.notify(application, :registered)

    assert {:ok, _} = result.email
    assert {:ok, _} = result.admin_email
    assert {:ok, _} = result.sms

    assert_email_sent(fn email ->
      assert email.subject =~ "received your Komiuta Agent application"
      assert email.to == [{"Notify Agent", "notify.agent@example.com"}]
    end)

    assert_email_sent(fn email ->
      assert email.subject =~ "New Komiuta Agent application"
    end)

    assert_receive {:agent_sms, "+254712345678", message}
    assert message =~ application.reference
    assert message =~ "agent.komiuta.com/agent/login"
  end

  test "pending sends a pending email and SMS" do
    application = application()
    result = AgentNotifications.notify(application, :pending)

    assert {:ok, _} = result.email
    assert {:ok, _} = result.sms

    assert_email_sent(fn email ->
      assert email.subject =~ "still pending"
    end)

    assert_receive {:agent_sms, "+254712345678", message}
    assert message =~ "pending"
  end

  test "approval sends an approved email and SMS" do
    application = application()
    result = AgentNotifications.notify(application, :approved)

    assert {:ok, _} = result.email
    assert {:ok, _} = result.sms

    assert_email_sent(fn email ->
      assert email.subject =~ "approved"
    end)

    assert_receive {:agent_sms, "+254712345678", message}
    assert message =~ "approved"
  end

  test "rejection email and SMS include the reason" do
    application = application()
    result = AgentNotifications.notify(application, :rejected, "Missing business registration")

    assert {:ok, _} = result.email
    assert {:ok, _} = result.sms

    assert_email_sent(fn email ->
      assert email.subject =~ "Update on your Komiuta Agent application"
      assert email.text_body =~ "Missing business registration"
    end)

    assert_receive {:agent_sms, "+254712345678", message}
    assert message =~ "Missing business registration"
  end
end
