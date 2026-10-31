defmodule Xpressbus.TicketAccess do
  @moduledoc """
  Signed, phone-bound access tokens for public ticket links.

  Manual ticket lookup requires the passenger's full phone number. Links we
  generate ourselves (post-payment redirect, boarding QR, Share Ticket) carry a
  short HMAC token instead of the phone number, so the URL never leaks PII while
  still opening the ticket in one tap.
  """

  alias Xpressbus.Tickets.Ticket

  @spec token(Ticket.t()) :: String.t()
  def token(%Ticket{} = ticket), do: token(ticket.ticket_id, ticket.passenger_phone)

  @spec token(String.t(), String.t() | nil) :: String.t()
  def token(ticket_id, phone) when is_binary(ticket_id) do
    payload = "ticket-access:#{ticket_id}:#{normalize(phone)}"

    :crypto.mac(:hmac, :sha256, secret(), payload)
    |> Base.url_encode64(padding: false)
  end

  @spec valid?(Ticket.t() | nil, String.t() | nil) :: boolean()
  def valid?(%Ticket{} = ticket, token) when is_binary(token) and token != "" do
    Plug.Crypto.secure_compare(token(ticket), token)
  end

  def valid?(_ticket, _token), do: false

  @spec path(Ticket.t()) :: String.t()
  def path(%Ticket{} = ticket) do
    "/tickets?ticket_id=#{URI.encode_www_form(ticket.ticket_id)}&token=#{token(ticket)}"
  end

  @doc """
  Signed download URL for the printable PDF boarding pass.

  Carries the same HMAC token as the ticket link, so a passenger who is not
  signed in (e.g. a guest booking opened from the post-payment redirect) can
  still download their own PDF without the download endpoint leaking tickets.
  """
  @spec download_path(Ticket.t()) :: String.t()
  def download_path(%Ticket{} = ticket) do
    "/tickets/#{URI.encode_www_form(ticket.ticket_id)}/download?token=#{token(ticket)}"
  end

  @spec url(Ticket.t()) :: String.t()
  def url(%Ticket{} = ticket), do: XpressbusWeb.Endpoint.url() <> path(ticket)

  @doc """
  Normalises a phone number for comparison: digits only, keeping the last 9
  digits so `0712345678`, `+254712345678` and `712345678` all match.
  """
  @spec normalize(String.t() | nil) :: String.t()
  def normalize(nil), do: ""

  def normalize(phone) do
    digits = phone |> to_string() |> String.replace(~r/[^0-9]/, "")

    if String.length(digits) > 9 do
      String.slice(digits, -9, 9)
    else
      digits
    end
  end

  defp secret do
    endpoint_config = Application.get_env(:xpressbus, XpressbusWeb.Endpoint, [])

    Keyword.get(endpoint_config, :secret_key_base) ||
      Application.get_env(:xpressbus, :login_code_secret) ||
      "komiuta-ticket-access-dev-secret"
  end
end
