defmodule XpressbusWeb.RawBodyReader do
  @moduledoc """
  A `Plug.Parsers` body reader that caches the raw request body in
  `conn.assigns[:raw_body]`.

  Payment providers (Paystack, Flutterwave) sign the exact bytes of the
  webhook request, so signature verification has to happen against the raw
  body, not against a re-encoded JSON map. This reader follows the pattern
  documented by `Plug.Parsers` and accumulates chunks in reverse order; use
  `XpressbusWeb.RawBodyReader.raw_body/1` to get the joined body.
  """

  @doc """
  `Plug.Parsers` `:body_reader` callback.
  """
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
    {:ok, body, conn}
  end

  @doc """
  Returns the raw request body assembled from the chunks captured while parsing.
  """
  def raw_body(%Plug.Conn{assigns: %{raw_body: chunks}}) when is_list(chunks) do
    chunks |> Enum.reverse() |> IO.iodata_to_binary()
  end

  def raw_body(%Plug.Conn{assigns: %{raw_body: body}}) when is_binary(body), do: body
  def raw_body(_conn), do: ""
end
