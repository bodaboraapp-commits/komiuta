defmodule Xpressbus.SMS do
  @moduledoc """
  Transactional SMS delivery.

  Uses Africa's Talking for Kenyan numbers. Configure it with:

      AFRICASTALKING_USERNAME
      AFRICASTALKING_API_KEY
      AFRICASTALKING_SENDER_ID (optional)

  When it is not configured, callers receive `{:error, :not_configured}` and can
  still fall back to email. Tests can inject a sender with the
  `:sms_send_fun` application env.
  """

  require Logger

  @africastalking_url "https://api.africastalking.com/version1/messaging"

  def configured? do
    config = config()

    is_binary(config[:api_key]) and String.trim(config[:api_key]) != "" and
      is_binary(config[:username]) and String.trim(config[:username]) != ""
  end

  @doc "Sends an SMS and returns `{:ok, details}` or `{:error, reason}`."
  def send(phone, message) when is_binary(message) do
    to = to_e164(phone)
    config = config()
    override = Application.get_env(:xpressbus, :sms_send_fun)

    cond do
      is_nil(to) ->
        {:error, :invalid_phone}

      is_function(override, 2) ->
        normalize_result(override.(to, message))

      not configured?() ->
        {:error, :not_configured}

      true ->
        deliver_africastalking(to, message, config)
    end
  end

  def send(_phone, _message), do: {:error, :invalid_phone}

  @doc "Normalises a Kenyan phone number to E.164 form."
  def to_e164(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    cond do
      String.starts_with?(digits, "254") and byte_size(digits) == 12 ->
        "+" <> digits

      String.starts_with?(digits, "0") and byte_size(digits) == 10 ->
        "+254" <> binary_part(digits, 1, 9)

      byte_size(digits) == 9 ->
        "+254" <> digits

      byte_size(digits) >= 10 ->
        "+" <> digits

      true ->
        nil
    end
  end

  def to_e164(_phone), do: nil

  def body_for_cancellation(ticket, refund) do
    route = "#{ticket.from} to #{ticket.to}"
    date = Calendar.strftime(ticket.travel_date, "%d %b %Y")
    reference = refund.reference || "processing"

    "Hi #{first_name(ticket.passenger_name)}, we're sorry that ticket #{ticket.ticket_id} (#{route}, #{date}) has been cancelled. Your refund of KES #{refund.amount} is being processed (ref #{reference}). We apologise for the inconvenience. KOMIUTA 0800 211 211"
  end

  defp deliver_africastalking(to, message, config) do
    headers = [
      {"apiKey", config[:api_key]},
      {"Accept", "application/json"}
    ]

    form =
      [
        username: config[:username],
        to: to,
        message: message,
        from: config[:sender_id]
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) or to_string(v) == "" end)

    case Req.post(@africastalking_url,
           form: form,
           headers: headers,
           receive_timeout: 15_000
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        recipients = get_in(body, ["SMSMessageData", "Recipients"]) || []
        first = List.first(recipients) || %{}

        if to_string(first["status"] || "") in ["Success", "success"] do
          {:ok,
           %{provider: :africastalking, message: get_in(body, ["SMSMessageData", "Message"])}}
        else
          Logger.warning("Africa's Talking SMS rejected", body: inspect(body))
          {:error, :provider_rejected}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Africa's Talking SMS failed", status: status, body: inspect(body))
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.warning("Africa's Talking SMS unavailable", reason: inspect(reason))
        {:error, :unavailable}
    end
  end

  defp normalize_result({:ok, details}), do: {:ok, details}
  defp normalize_result({:error, reason}), do: {:error, reason}
  defp normalize_result(_), do: {:error, :unexpected_result}

  defp config do
    Application.get_env(:xpressbus, :sms, %{})
  end

  defp first_name(nil), do: "traveller"

  defp first_name(name) do
    name
    |> to_string()
    |> String.split()
    |> List.first()
    |> case do
      nil -> "traveller"
      value -> value
    end
  end
end
