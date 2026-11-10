defmodule XpressbusWeb.AiTripBuilderLive do
  @moduledoc """
  The Chyllz AI trip builder: a five-step wizard (destination, dates, companions,
  budget and preferences) that turns a short brief into an itinerary the Chyllz AI
  assistant can expand.

  The first step is the destination picker: travellers can search any city,
  country or landmark or tap one of the trending destinations. The remaining
  steps collect the trip brief, and the final screen summarises it with links to
  the Chyllz assistant and catalogue.
  """

  use XpressbusWeb, :live_view

  import XpressbusWeb.ChyllzAccountArt

  @steps [
    %{key: 1, title: "Destination", icon: :pin},
    %{key: 2, title: "Dates", icon: :calendar},
    %{key: 3, title: "Companions", icon: :users},
    %{key: 4, title: "Budget", icon: :wallet},
    %{key: 5, title: "Preferences", icon: :sliders}
  ]

  @destinations [
    %{name: "Cox's Bazar", country: "Bangladesh", art: :coast, tag: "cox"},
    %{name: "Saint Martins", country: "Bangladesh", art: :coast, tag: "saint-martins"},
    %{name: "Rome", country: "Italy", art: :mountains, tag: "rome"},
    %{name: "Bangkok", country: "Thailand", art: :mountains, tag: "bangkok"},
    %{name: "New York", country: "United States", art: :savanna, tag: "new-york"},
    %{name: "Las Vegas", country: "United States", art: :savanna, tag: "las-vegas"},
    %{name: "Istanbul", country: "Turkey", art: :coast, tag: "istanbul"}
  ]

  @preferences ~w(Beach Food Culture Adventure Nature Nightlife Shopping Relaxation)

  @budgets [
    "Under KES 50,000",
    "KES 50,000 – 100,000",
    "KES 100,000 – 200,000",
    "KES 200,000+"
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Chyllz AI Trip Builder")
     |> assign(:page_description, "Build your dream trip with Chyllz AI.")
     |> assign(:page_robots, "noindex,follow")
     |> assign(:steps, @steps)
     |> assign(:destinations, @destinations)
     |> assign(:preferences, @preferences)
     |> assign(:budgets, @budgets)
     |> assign(:step, 1)
     |> assign(:query, "")
     |> assign(:error, nil)
     |> assign(:today, Date.utc_today())
     |> assign(:calendar_month, Date.beginning_of_month(Date.utc_today()))
     |> reset_trip()}
  end

  @impl true
  def handle_event("search_destination", %{"query" => query}, socket) do
    query = query |> to_string() |> String.trim() |> String.slice(0, 80)

    if query == "" do
      {:noreply, assign(socket, :error, "Type a city, country or landmark to continue.")}
    else
      {:noreply,
       socket
       |> assign(:error, nil)
       |> assign(:query, query)
       |> choose_destination(%{destination: query, country: ""})}
    end
  end

  def handle_event(
        "choose_destination",
        %{"destination" => destination, "country" => country},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:error, nil)
     |> choose_destination(%{destination: destination, country: country})}
  end

  def handle_event("pick_date", %{"date" => value}, socket) do
    case Date.from_iso8601(to_string(value)) do
      {:ok, date} ->
        {:noreply,
         socket
         |> assign(:error, nil)
         |> assign(:trip, select_date(socket.assigns.trip, date))}

      _other ->
        {:noreply, socket}
    end
  end

  def handle_event("calendar_shift", %{"shift" => shift}, socket) do
    shift = to_int(shift, 0)
    {:noreply, assign(socket, :calendar_month, shift_month(socket.assigns.calendar_month, shift))}
  end

  def handle_event("change_destination", _params, socket) do
    {:noreply, assign(socket, :step, 1)}
  end

  def handle_event("dates_next", _params, socket) do
    trip = socket.assigns.trip

    if trip.start_date && trip.end_date do
      {:noreply, socket |> assign(:error, nil) |> assign(:step, 3)}
    else
      {:noreply, assign(socket, :error, "Pick a start and end date to continue.")}
    end
  end

  def handle_event("companions", %{"adults" => adults, "children" => children}, socket) do
    adults = adults |> to_string() |> to_int(2) |> clamp(1, 20)
    children = children |> to_string() |> to_int(0) |> clamp(0, 20)

    {:noreply,
     socket
     |> assign(:error, nil)
     |> assign(:trip, %{socket.assigns.trip | adults: adults, children: children})
     |> assign(:step, 4)}
  end

  def handle_event("budget", %{"budget" => budget}, socket) do
    if budget in @budgets do
      {:noreply,
       socket
       |> assign(:error, nil)
       |> assign(:trip, %{socket.assigns.trip | budget: budget})
       |> assign(:step, 5)}
    else
      {:noreply, assign(socket, :error, "Choose a budget range to continue.")}
    end
  end

  def handle_event("toggle_preference", %{"preference" => preference}, socket) do
    if preference in @preferences do
      preferences =
        socket.assigns.trip.preferences
        |> toggle_value(preference)

      {:noreply, assign(socket, :trip, %{socket.assigns.trip | preferences: preferences})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("finish", _params, socket) do
    if socket.assigns.trip.preferences == [] do
      {:noreply,
       assign(socket, :error, "Pick at least one preference so the AI can shape your trip.")}
    else
      {:noreply, socket |> assign(:error, nil) |> assign(:step, 6)}
    end
  end

  def handle_event("back", _params, socket) do
    {:noreply, socket |> assign(:error, nil) |> assign(:step, max(socket.assigns.step - 1, 1))}
  end

  def handle_event("restart", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, 1)
     |> assign(:query, "")
     |> assign(:error, nil)
     |> assign(:today, Date.utc_today())
     |> assign(:calendar_month, Date.beginning_of_month(Date.utc_today()))
     |> reset_trip()}
  end

  defp reset_trip(socket) do
    assign(socket, :trip, %{
      destination: nil,
      country: nil,
      start_date: nil,
      end_date: nil,
      adults: 2,
      children: 0,
      budget: hd(@budgets),
      preferences: []
    })
  end

  defp choose_destination(socket, %{destination: destination, country: country}) do
    trip = %{
      socket.assigns.trip
      | destination: destination |> to_string() |> String.trim() |> String.slice(0, 80),
        country: to_string(country)
    }

    socket
    |> assign(:trip, trip)
    |> assign(:step, 2)
  end

  defp select_date(trip, date) do
    cond do
      is_nil(trip.start_date) ->
        %{trip | start_date: date, end_date: nil}

      is_nil(trip.end_date) and Date.compare(date, trip.start_date) == :lt ->
        %{trip | start_date: date, end_date: trip.start_date}

      is_nil(trip.end_date) ->
        %{trip | end_date: date}

      true ->
        %{trip | start_date: date, end_date: nil}
    end
  end

  defp shift_month(%Date{} = date, months) do
    total = date.year * 12 + date.month - 1 + months
    year = div(total, 12)
    month = rem(rem(total, 12) + 12, 12) + 1
    Date.new!(year, month, 1)
  end

  defp calendar_months(cursor) do
    first = Date.beginning_of_month(cursor)
    [first, shift_month(first, 1)] |> Enum.map(&calendar_month/1)
  end

  defp calendar_month(first) do
    offset = Date.day_of_week(first, :sunday) - 1
    dates = for day <- 1..Date.days_in_month(first), do: Date.add(first, day - 1)
    cells = List.duplicate(nil, offset) ++ dates
    padding = rem(7 - rem(length(cells), 7), 7)

    %{
      first: first,
      label: Calendar.strftime(first, "%B %Y"),
      weeks: (cells ++ List.duplicate(nil, padding)) |> Enum.chunk_every(7)
    }
  end

  defp calendar_day_class(date, trip, today) do
    selected = date == trip.start_date or date == trip.end_date

    cond do
      selected ->
        "rounded-full bg-[#FF4C00] font-black text-white shadow-lg shadow-orange-500/25"

      in_range?(date, trip.start_date, trip.end_date) ->
        "rounded-full bg-orange-50 font-black text-[#FF4C00]"

      date == today ->
        "rounded-full bg-amber-100 font-black text-amber-900 ring-1 ring-amber-200"

      true ->
        "rounded-full text-slate-700 hover:bg-slate-100"
    end
  end

  defp in_range?(_date, nil, _end_date), do: false
  defp in_range?(_date, _start_date, nil), do: false

  defp in_range?(date, start_date, end_date) do
    Date.compare(date, start_date) == :gt and Date.compare(date, end_date) == :lt
  end

  defp range_label(%{start_date: nil}), do: "Please select a date range"

  defp range_label(%{start_date: start_date, end_date: nil}),
    do: "#{format_date(start_date)} — now pick your return date"

  defp range_label(%{start_date: start_date, end_date: end_date}),
    do: "#{format_date(start_date)} → #{format_date(end_date)}"

  defp toggle_value(list, value) do
    if value in list, do: List.delete(list, value), else: list ++ [value]
  end

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)

  defp to_int(value, default) do
    case Integer.parse(to_string(value)) do
      {number, _rest} -> number
      :error -> default
    end
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b %Y")

  defp travel_label(%{start_date: nil}), do: "Dates to be confirmed"

  defp travel_label(%{start_date: start_date, end_date: nil}),
    do: format_date(start_date)

  defp travel_label(%{start_date: start_date, end_date: end_date}) do
    "#{format_date(start_date)} → #{format_date(end_date)}"
  end

  defp companion_label(%{adults: adults, children: children}) do
    parts = ["#{adults} #{if adults == 1, do: "adult", else: "adults"}"]

    parts =
      if children > 0 do
        parts ++ ["#{children} #{if children == 1, do: "child", else: "children"}"]
      else
        parts
      end

    Enum.join(parts, " · ")
  end

  defp budget_label(%{budget: budget}), do: budget

  defp preference_label([]), do: "No preferences selected"
  defp preference_label(preferences), do: Enum.join(preferences, " · ")
end
