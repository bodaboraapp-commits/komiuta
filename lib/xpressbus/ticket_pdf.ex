defmodule Xpressbus.TicketPDF do
  @moduledoc """
  Dependency-free single-page PDF renderer for a bus ticket.

  The PDF is deliberately minimal (Helvetica text on A4) so the app can offer a
  working "Download PDF" without pulling in a PDF dependency.
  """

  alias Xpressbus.Tickets.Ticket

  @page_width 595
  @page_height 842

  @spec render(Ticket.t()) :: binary()
  def render(%Ticket{} = ticket) do
    lines = ticket_lines(ticket)
    content = content_stream(lines)
    build_pdf(content)
  end

  defp ticket_lines(ticket) do
    [
      {:title, "KOMIUTA"},
      {:subtitle, "BUS E-TICKET / BOARDING PASS"},
      {:spacer, ""},
      {:label, "TICKET ID"},
      {:value, ticket.ticket_id || "-"},
      {:label, "PASSENGER"},
      {:value, ticket.passenger_name || "-"},
      {:label, "PHONE"},
      {:value, ticket.passenger_phone || "-"},
      {:label, "ROUTE"},
      {:value, "#{ticket.from}  ->  #{ticket.to}"},
      {:label, "TRAVEL DATE"},
      {:value, format_date(ticket.travel_date)},
      {:label, "DEPARTURE / ARRIVAL"},
      {:value, "#{ticket.departure || "-"} / #{ticket.arrival || "-"}"},
      {:label, "OPERATOR"},
      {:value, ticket.company || "-"},
      {:label, "SEATS"},
      {:value, format_seats(ticket.seats)},
      {:label, "FARE"},
      {:value, ticket.price || "-"},
      {:label, "STATUS"},
      {:value, String.upcase(ticket.status || "pending")},
      {:spacer, ""},
      {:footer, "Present this ticket (or the QR code in your dashboard) when boarding."},
      {:footer, "Thank you for travelling with Komiuta."}
    ]
  end

  defp content_stream(lines) do
    {ops, _y} =
      Enum.reduce(lines, {[], 0}, fn {kind, text}, {ops, _y} ->
        step =
          case kind do
            :title -> 34
            :subtitle -> 24
            :label -> 30
            :value -> 22
            :spacer -> 18
            :footer -> 22
          end

        font =
          case kind do
            k when k in [:title, :subtitle, :label] -> "/F2"
            _ -> "/F1"
          end

        size =
          case kind do
            :title -> 24
            :subtitle -> 10
            :label -> 9
            :footer -> 9
            _ -> 13
          end

        op = ["/", String.trim_leading(font, "/"), " ", to_string(size), " Tf\n"]
        op = op ++ ["0 -", to_string(step), " Td\n(", escape(text), ") Tj\n"]
        {ops ++ op, step}
      end)

    [
      "BT\n",
      "/F1 12 Tf\n",
      "50 780 Td\n",
      ops,
      "ET\n"
    ]
    |> IO.iodata_to_binary()
  end

  defp build_pdf(content) do
    objects = [
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{@page_width} #{@page_height}] " <>
        "/Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >>",
      "<< /Length #{byte_size(content)} >>\nstream\n#{content}endstream",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>"
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

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> String.replace(~r/[^\x20-\x7E]/, " ")
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
end
