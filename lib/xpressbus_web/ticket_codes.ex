defmodule XpressbusWeb.TicketCodes do
  @moduledoc """
  Single source of truth for the machine-readable codes on a boarding pass.

  The QR code encodes the signed ticket URL (see `Xpressbus.TicketAccess`) and
  the barcode encodes the human-readable ticket number as ISO/IEC 15417
  Code 128B. Both are generated locally as inline SVG — no third-party image
  service — so the public ticket page, the dashboard ticket modal and any
  future PDF render identical, scannable codes.

  Callers receive `{:safe, svg}` tuples ready for direct HEEx interpolation, or
  `nil` when the ticket is missing or the payload cannot be encoded, so a
  template can always fall back to showing the ticket number as text.
  """

  alias Xpressbus.{Barcode, TicketAccess}
  alias Xpressbus.Tickets.Ticket

  @default_barcode_opts [module_width: 2, height: 64]

  @doc """
  Renders the boarding QR code for `ticket`.

  The payload is the signed `/tickets?ticket_id=...&token=...` URL (no phone
  number), matching the link the passenger would open by hand.
  """
  @spec qr(Ticket.t() | nil) :: {:safe, String.t()} | nil
  def qr(nil), do: nil

  def qr(%Ticket{} = ticket) do
    XpressbusWeb.QRCode.svg(TicketAccess.url(ticket), aria_label: "Boarding QR code")
  end

  def qr(_ticket), do: nil

  @doc """
  Renders the ISO/IEC 15417 Code 128B barcode for the ticket number.

  Options are forwarded to `Xpressbus.Barcode.svg/2`; the defaults match the
  public ticket page (2 px modules, 64 px tall). Pass `responsive: true` for
  containers whose width is fluid (e.g. the dashboard modal).
  """
  @spec barcode(Ticket.t() | nil, keyword()) :: {:safe, String.t()} | nil
  def barcode(ticket, opts \\ [])

  def barcode(nil, _opts), do: nil

  def barcode(%Ticket{ticket_id: ticket_id}, opts) when is_binary(ticket_id) do
    opts =
      @default_barcode_opts
      |> Keyword.merge(aria_label: "Ticket barcode #{ticket_id}")
      |> Keyword.merge(opts)

    case Barcode.svg(ticket_id, opts) do
      {:ok, svg} -> Phoenix.HTML.raw(svg)
      _error -> nil
    end
  end

  def barcode(_ticket, _opts), do: nil

  @doc """
  Signed URL of the printable PDF boarding pass for `ticket`.

  Used by the "Download PDF" buttons so the download works for guest bookings
  (post-payment) as well as signed-in passengers. Returns `nil` without a
  ticket.
  """
  @spec download_url(Ticket.t() | nil) :: String.t() | nil
  def download_url(nil), do: nil
  def download_url(%Ticket{} = ticket), do: TicketAccess.download_path(ticket)
  def download_url(_ticket), do: nil
end
