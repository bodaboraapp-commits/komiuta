defmodule XpressbusWeb.FirebasePhoneAuth do
  @moduledoc """
  Shared HTTP response handling for Firebase phone sign-in.

  Both the traveller and agent sign-in endpoints verify the same Firebase token
  through `Xpressbus.Firebase.verify_phone_token/1` and return the same errors,
  so a phone number behaves identically on either surface.
  """

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn, only: [put_status: 2]

  alias Xpressbus.Firebase

  def verify_token(token), do: Firebase.verify_phone_token(token)

  def error(conn, reason) do
    {status, message} = error_details(reason)
    conn |> put_status(status) |> json(%{error: message})
  end

  defp error_details(:not_configured) do
    {503, "SMS sign-in is not configured yet. Please use email or Gmail."}
  end

  defp error_details(:missing_token) do
    {400, "Missing SMS verification token."}
  end

  defp error_details(:invalid_token) do
    {401, "That SMS code could not be verified. Please try again."}
  end

  defp error_details(:no_phone) do
    {422, "No phone number was found on that Firebase session."}
  end

  defp error_details(_reason) do
    {502, "SMS verification is temporarily unavailable. Please use email or Gmail."}
  end
end
