defmodule Xpressbus.TicketPDF do
  @moduledoc """
  Dependency-free single-page PDF boarding pass.

  The PDF is a real printable boarding pass: a branded header, the journey and
  trip details, and the same two machine-readable codes as the on-screen
  boarding pass:

    * a QR code encoding the signed ticket URL (opens the live ticket when
      scanned), and
    * an ISO/IEC 15417 Code 128B barcode of the ticket number for gate
      scanners.

  Both are drawn as vector rectangles in the PDF content stream (no images, no
  rasterisation), so they stay crisp at any print resolution and the PDF has no
  third-party or binary dependencies. The encoders are the same ones used by
  the ticket page and the dashboard modal (`Xpressbus.QR` / `Xpressbus.Barcode`).
  """

  alias Xpressbus.{Barcode, QR, TicketAccess}
  alias Xpressbus.Tickets.Ticket

  @page_width 595
  @page_height 842

  # Brand palette (RGB 0..1) matching the on-screen boarding pass.
  @orange {1.0, 0.298, 0.0}
  @ink {0.06, 0.09, 0.16}
  @muted {0.45, 0.51, 0.59}
  @hairline {0.89, 0.91, 0.94}
  @white {1.0, 1.0, 1.0}

  @qr_module_size 4
  @qr_quiet_modules 4
  @barcode_module_width 2
  @barcode_height 64

  @spec render(Ticket.t()) :: binary()
  def render(%Ticket{} = ticket) do
    content = content_stream(ticket)
    build_pdf(content)
  end

  # --- Page layout -----------------------------------------------------------

  defp content_stream(ticket) do
    ticket_id = ticket.ticket_id || "-"

    [
      # Header band
      rect(0, 742, @page_width, 100, @orange),
      text(40, 806, "KOMIUTA", font: :bold, size: 24, color: @white),
      text(40, 788, "BUS E-TICKET  /  BOARDING PASS", font: :bold, size: 8, color: @white),
      text(400, 812, "TICKET NUMBER", font: :bold, size: 7, color: @white),
      text(400, 794, ticket_id, font: :bold, size: 14, color: @white),
      # Journey
      text(40, 700, "FROM", font: :bold, size: 7, color: @muted),
      text(40, 672, upper(ticket.from), font: :bold, size: 24, color: @ink),
      text(268, 676, ">", font: :bold, size: 20, color: @muted),
      text(320, 700, "TO", font: :bold, size: 7, color: @muted),
      text(320, 672, upper(ticket.to), font: :bold, size: 24, color: @ink),
      # Trip details
      text(40, 630, "TRAVEL DATE", font: :bold, size: 7, color: @muted),
      text(40, 614, format_date(ticket.travel_date), font: :regular, size: 12, color: @ink),
      text(185, 630, "DEPARTURE", font: :bold, size: 7, color: @muted),
      text(185, 614, ticket.departure || "-", font: :regular, size: 12, color: @ink),
      text(310, 630, "ARRIVAL", font: :bold, size: 7, color: @muted),
      text(310, 614, ticket.arrival || "-", font: :regular, size: 12, color: @ink),
      text(425, 630, "OPERATOR", font: :bold, size: 7, color: @muted),
      text(425, 614, truncate(ticket.company || "-", 22), font: :regular, size: 12, color: @ink),
      # Passenger block
      line(40, 590, 555, 590, @hairline, 1, true),
      text(40, 566, "PASSENGER DETAILS", font: :bold, size: 9, color: @ink),
      text(40, 540, "PASSENGER", font: :bold, size: 7, color: @muted),
      text(40, 524, truncate(ticket.passenger_name || "-", 38),
        font: :bold,
        size: 12,
        color: @ink
      ),
      text(330, 540, "PHONE", font: :bold, size: 7, color: @muted),
      text(330, 524, ticket.passenger_phone || "-", font: :regular, size: 12, color: @ink),
      text(40, 498, "SEATS", font: :bold, size: 7, color: @muted),
      text(40, 482, format_seats(ticket.seats), font: :bold, size: 12, color: @ink),
      text(150, 498, "FARE", font: :bold, size: 7, color: @muted),
      text(150, 482, ticket.price || "-", font: :bold, size: 12, color: @ink),
      text(280, 498, "STATUS", font: :bold, size: 7, color: @muted),
      text(280, 482, String.upcase(ticket.status || "pending"),
        font: :bold,
        size: 12,
        color: @ink
      ),
      text(400, 498, "TICKET TYPE", font: :bold, size: 7, color: @muted),
      text(400, 482, ticket.type || "One Way", font: :regular, size: 12, color: @ink),
      # Boarding codes
      line(40, 456, 555, 456, @hairline, 1, true),
      text(40, 440, "BOARDING CODES", font: :bold, size: 9, color: @ink),
      barcode_graphics(ticket, 40, 112),
      text(40, 96, ticket_id, font: :regular, size: 10, color: @ink),
      text(40, 82, "CODE 128  -  TICKET NUMBER", font: :bold, size: 7, color: @muted),
      qr_graphics(ticket),
      qr_caption(ticket),
      # Instructions and footer
      text(40, 62, "Scan the QR code or let the gate scanner read the barcode when boarding.",
        font: :regular,
        size: 9,
        color: @ink
      ),
      line(40, 50, 555, 50, @hairline, 1, false),
      text(40, 34, "komiuta.com/tickets   -   hello@komiuta.com   -   0800 211 211",
        font: :bold,
        size: 8,
        color: @muted
      )
    ]
    |> IO.iodata_to_binary()
  end

  # --- Boarding codes --------------------------------------------------------

  defp barcode_graphics(ticket, x, y) do
    case Barcode.encode(ticket.ticket_id || "") do
      {:ok, bits} ->
        quiet = 10

        rects =
          bits
          |> String.graphemes()
          |> Enum.with_index(quiet)
          |> Enum.flat_map(fn
            {"1", index} ->
              [
                [
                  num(x + index * @barcode_module_width),
                  " ",
                  num(y),
                  " ",
                  num(@barcode_module_width),
                  " ",
                  num(@barcode_height),
                  " re\n"
                ]
              ]

            {"0", _index} ->
              []
          end)

        [rgb(@ink), rects, "f\n"]

      _error ->
        # Unsupported ticket number: skip the barcode rather than drawing garbage.
        text(x, y + 24, "Barcode unavailable - present the ticket number",
          font: :regular,
          size: 9,
          color: @muted
        )
    end
  end

  defp qr_graphics(ticket) do
    case qr_matrix(ticket) do
      {:ok, %{modules: modules}} ->
        size = length(modules)
        total = size + @qr_quiet_modules * 2
        width = total * @qr_module_size
        x0 = 555 - width
        y0 = 220

        rects =
          modules
          |> Enum.with_index()
          |> Enum.flat_map(fn {row, row_index} ->
            row
            |> Enum.with_index()
            |> Enum.flat_map(fn
              {true, column} ->
                x = x0 + (column + @qr_quiet_modules) * @qr_module_size
                y = y0 + (size - 1 - row_index + @qr_quiet_modules) * @qr_module_size

                [
                  [
                    num(x),
                    " ",
                    num(y),
                    " ",
                    num(@qr_module_size),
                    " ",
                    num(@qr_module_size),
                    " re\n"
                  ]
                ]

              {false, _column} ->
                []
            end)
          end)

        [rgb(@ink), rects, "f\n"]

      :error ->
        text(400, 330, "QR unavailable", font: :regular, size: 9, color: @muted)
    end
  end

  defp qr_caption(ticket) do
    case qr_matrix(ticket) do
      {:ok, %{modules: modules}} ->
        width = (length(modules) + @qr_quiet_modules * 2) * @qr_module_size
        x0 = 555 - width
        # Roughly centre an 8 pt, 13-character caption under the code.
        text(x0 + max(div(width, 2) - 27, 0), 202, "SCAN TO BOARD",
          font: :bold,
          size: 7,
          color: @muted
        )

      :error ->
        []
    end
  end

  defp qr_matrix(ticket) do
    payloads = [ticket_url(ticket), TicketAccess.path(ticket)]

    Enum.find_value(payloads, :error, fn payload ->
      case QR.encode(payload) do
        {:ok, qr} -> {:ok, qr}
        {:error, _reason} -> nil
      end
    end)
  end

  defp ticket_url(ticket) do
    TicketAccess.url(ticket)
  rescue
    # The endpoint is not running (e.g. a mix task): fall back to the public
    # host so the printed QR still resolves to a usable ticket link.
    _error -> "https://www.komiuta.com" <> TicketAccess.path(ticket)
  end

  # --- PDF primitives --------------------------------------------------------

  defp rect(x, y, width, height, color) do
    [rgb(color), num(x), " ", num(y), " ", num(width), " ", num(height), " re f\n"]
  end

  defp line(x1, y1, x2, y2, color, width, dashed?) do
    dash = if dashed?, do: "[3 3] 0 d\n", else: "[] 0 d\n"

    [
      rgb(color),
      num(width),
      " w\n",
      dash,
      num(x1),
      " ",
      num(y1),
      " m ",
      num(x2),
      " ",
      num(y2),
      " l S\n"
    ]
  end

  defp text(x, y, string, opts) do
    font = if Keyword.get(opts, :font, :regular) == :bold, do: "/F2", else: "/F1"
    color = Keyword.get(opts, :color, @ink)
    size = Keyword.get(opts, :size, 10)

    [
      rgb(color),
      "BT\n",
      font,
      " ",
      num(size),
      " Tf\n1 0 0 1 ",
      num(x),
      " ",
      num(y),
      " Tm\n(",
      escape(string),
      ") Tj\nET\n"
    ]
  end

  defp rgb({red, green, blue}) do
    [num(red), " ", num(green), " ", num(blue), " rg\n"]
  end

  defp num(value) when is_integer(value), do: Integer.to_string(value)

  defp num(value) when is_float(value) do
    value
    |> :erlang.float_to_binary(decimals: 3)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  # --- Value formatting ------------------------------------------------------

  defp upper(nil), do: "-"
  defp upper(value), do: value |> to_string() |> String.upcase()

  defp truncate(value, max_length) do
    value = to_string(value)

    if String.length(value) > max_length do
      String.slice(value, 0, max_length - 3) <> "..."
    else
      value
    end
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")
  defp format_date(nil), do: "-"
  defp format_date(other), do: to_string(other)

  defp format_seats(nil), do: "-"
  defp format_seats(seats) when is_list(seats), do: Enum.join(seats, ", ")

  defp format_seats(seats) when is_binary(seats) do
    case Jason.decode(seats) do
      {:ok, list} when is_list(list) -> Enum.join(list, ", ")
      _ -> seats
    end
  end

  defp format_seats(other), do: to_string(other)

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> String.replace(~r/[^\x20-\x7E]/, " ")
  end

  # --- PDF document ----------------------------------------------------------

  defp build_pdf(content) do
    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{@page_width} #{@page_height}] " <>
        "/Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >>",
      "<< /Length #{byte_size(content)} >>\nstream\n#{content}endstream",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>"
    ]

    header = "%PDF-1.4\n"

    {body, offsets} =
      objects
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {object, number}, {chunks, offsets} ->
        offset = IO.iodata_length([header | chunks])
        chunk = "#{number} 0 obj\n#{object}\nendobj\n"
        {chunks ++ [chunk], offsets ++ [offset]}
      end)

    xref_offset = IO.iodata_length([header | body])

    xref =
      ["xref\n0 #{length(objects) + 1}\n", "0000000000 65535 f \n"] ++
        Enum.map(offsets, fn offset ->
          offset |> Integer.to_string() |> String.pad_leading(10, "0") |> Kernel.<>(" 00000 n \n")
        end)

    trailer = [
      "trailer\n<< /Size #{length(objects) + 1} /Root 1 0 R >>\n",
      "startxref\n",
      Integer.to_string(xref_offset),
      "\n%%EOF\n"
    ]

    IO.iodata_to_binary([header | body] ++ xref ++ trailer)
  end
end
