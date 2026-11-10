defmodule Xpressbus.AgentNotifications do
  @moduledoc """
  Agent lifecycle notifications: registration, pending, approved and rejected.

  Every event sends an email to the applicant and an SMS to the phone number on
  the application. SMS uses `Xpressbus.SMS` (Africa's Talking); when SMS is not
  configured the email still goes out and the error is reported to the admin.
  """

  require Logger

  alias Xpressbus.{AgentApplicationEmail, SMS}

  @events [:registered, :pending, :approved, :rejected]

  def events, do: @events

  @doc """
  Sends the email and SMS for an agent event.

  Returns `%{email: result, sms: result}`. Registration also sends the admin
  notification email and returns it as `:admin_email`.
  """
  def notify(application, event, reason \\ nil)

  def notify(application, event, reason) when event in @events do
    if event == :registered do
      %{
        email: safe(fn -> AgentApplicationEmail.deliver_applicant(application) end),
        admin_email: safe(fn -> AgentApplicationEmail.deliver_admin(application) end),
        sms: send_sms(application, event, reason)
      }
    else
      %{
        email: safe(fn -> AgentApplicationEmail.deliver_status(application, event, reason) end),
        sms: send_sms(application, event, reason)
      }
    end
  end

  def notify(_application, _event, _reason),
    do: %{email: {:error, :unknown_event}, sms: {:error, :unknown_event}}

  @doc "Human-readable delivery label used in admin flashes."
  def label({:ok, _}), do: "sent"
  def label({:error, :not_configured}), do: "not configured"
  def label({:error, :invalid_phone}), do: "invalid phone"
  def label({:error, _}), do: "failed"

  @doc "SMS body for an agent lifecycle event."
  def sms_body(application, event, reason \\ nil) do
    name = first_name(application.full_name)
    ref = application.reference

    case event do
      :registered ->
        "Hi #{name}, your KOMIUTA Agent application #{ref} has been received. We'll review it and update you. Log in at agent.komiuta.com/agent/login"

      :pending ->
        "Hi #{name}, your KOMIUTA Agent application #{ref} is still pending review. We'll update you soon. agent.komiuta.com/agent/login"

      :approved ->
        "Hi #{name}, your KOMIUTA Agent application #{ref} has been approved! Our team will contact you about activation. KOMIUTA Agent"

      :rejected ->
        reason = reason && String.trim(to_string(reason))

        "Hi #{name}, your KOMIUTA Agent application #{ref} was not approved.#{if reason && reason != "", do: " Reason: #{reason}", else: ""} Contact 0800 211 211."

      _ ->
        "Hi #{name}, your KOMIUTA Agent application #{ref} has been updated. agent.komiuta.com/agent/login"
    end
  end

  defp send_sms(application, event, reason) do
    SMS.send(application.phone, sms_body(application, event, reason))
  end

  defp safe(fun) do
    fun.()
  rescue
    error ->
      Logger.warning("Agent notification failed", error: Exception.message(error))
      {:error, :delivery_failed}
  end

  defp first_name(nil), do: "Agent"
  defp first_name(name), do: name |> to_string() |> String.split() |> List.first()
end
