defmodule XpressbusWeb.QRCode do
  @moduledoc """
  Small helper for rendering locally generated QR codes as safe inline SVG.

  Used by the ticket boarding pass (ticket URL) and the app-download section
  (PWA URL), so no third-party QR image service is involved.
  """

  @doc """
  Builds a QR code for `payload` and returns `{:safe, svg}` for direct HEEx
  interpolation, or `nil` when the payload is too long for the encoder.

  Accepts the same options as `Xpressbus.QR.svg/2` (`:aria_label`, `:size`).
  """
  @spec svg(binary(), keyword()) :: {:safe, binary()} | nil
  def svg(payload, opts \\ []) when is_binary(payload) do
    case Xpressbus.QR.svg(payload, opts) do
      {:ok, svg} -> Phoenix.HTML.raw(svg)
      {:error, _reason} -> nil
    end
  end
end
