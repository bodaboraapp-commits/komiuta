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

  @parties [
    %{
      key: "solo",
      title: "Only Me",
      description: "Traveling solo, just you",
      icon: :user
    },
    %{
      key: "couple",
      title: "A Couple",
      description: "A romantic getaway for two",
      icon: :heart
    },
    %{
      key: "family",
      title: "Family",
      description: "Quality time with your loved ones",
      icon: :users
    },
    %{
      key: "friends",
      title: "Friends",
      description: "Adventure with your closest pals",
      icon: :sparkles
    }
  ]

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
     |> assign(:parties, @parties)
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

  def handle_event("select_companions", %{"party" => party}, socket) do
    if Enum.any?(@parties, &(&1.key == party)) do
      {:noreply,
       socket
       |> assign(:error, nil)
       |> assign(:trip, %{socket.assigns.trip | travel_party: party})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_pets", %{"value" => value}, socket) do
    {:noreply, assign(socket, :trip, %{socket.assigns.trip | pets: value == "yes"})}
  end

  def handle_event("companions_next", _params, socket) do
    if socket.assigns.trip.travel_party do
      {:noreply, socket |> assign(:error, nil) |> assign(:step, 4)}
    else
      {:noreply, assign(socket, :error, "Select who you're travelling with to continue.")}
    end
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
      travel_party: nil,
      pets: false,
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
    do: "Selected: #{Date.to_iso8601(start_date)} — now pick your return date"

  defp range_label(%{start_date: start_date, end_date: end_date}) do
    "Selected: #{Date.to_iso8601(start_date)} to #{Date.to_iso8601(end_date)} (#{duration_days(start_date, end_date)} Days)"
  end

  defp duration_days(%Date{} = start_date, %Date{} = end_date) do
    Date.diff(end_date, start_date) + 1
  end

  defp estimated_credits(%Date{} = start_date, %Date{} = end_date) do
    duration_days(start_date, end_date) * credits_per_day()
  end

  defp credits_per_day do
    :xpressbus
    |> Application.get_env(:ai_trip_builder, [])
    |> Keyword.get(:credits_per_day, 20)
  end

  defp credit_balance do
    :xpressbus
    |> Application.get_env(:ai_trip_builder, [])
    |> Keyword.get(:credit_balance, "2.00")
  end

  defp toggle_value(list, value) do
    if value in list, do: List.delete(list, value), else: list ++ [value]
  end

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

  defp companion_label(%{travel_party: nil}), do: "Who's coming"
  defp companion_label(%{travel_party: "solo"}), do: "Only me"
  defp companion_label(%{travel_party: "couple"}), do: "A couple"
  defp companion_label(%{travel_party: "family"}), do: "Family"
  defp companion_label(%{travel_party: "friends"}), do: "Friends"

  defp pets_label(%{pets: true}), do: " · with pets"
  defp pets_label(_trip), do: ""

  defp budget_label(%{budget: budget}), do: budget

  defp preference_label([]), do: "No preferences selected"
  defp preference_label(preferences), do: Enum.join(preferences, " · ")
end
