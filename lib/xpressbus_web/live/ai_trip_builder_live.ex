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

  def handle_event("dates", %{"start_date" => start_date, "end_date" => end_date}, socket) do
    with {:ok, start} <- parse_date(start_date),
         {:ok, finish} <- parse_date(end_date),
         :ok <- validate_dates(start, finish) do
      {:noreply,
       socket
       |> assign(:error, nil)
       |> assign(:trip, %{socket.assigns.trip | start_date: start, end_date: finish})
       |> assign(:step, 3)}
    else
      {:error, message} -> {:noreply, assign(socket, :error, message)}
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

  defp parse_date(value) do
    case Date.from_iso8601(to_string(value)) do
      {:ok, date} -> {:ok, date}
      _other -> {:error, "Choose both travel dates to continue."}
    end
  end

  defp validate_dates(%Date{} = start_date, %Date{} = end_date) do
    if Date.compare(end_date, start_date) == :lt do
      {:error, "The return date can't be before the departure date."}
    else
      :ok
    end
  end

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

  defp date_input(nil), do: ""

  defp date_input(%Date{} = date), do: Date.to_iso8601(date)

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
