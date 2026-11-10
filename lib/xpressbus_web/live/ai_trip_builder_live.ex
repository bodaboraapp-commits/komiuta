defmodule XpressbusWeb.AiTripBuilderLive do
  @moduledoc """
  The Chyllz AI trip builder: a five-step wizard (destination, dates, companions,
  budget and preferences) that turns a short brief into an itinerary the Chyllz AI
  assistant can expand.

  The first step is the destination picker: every search is resolved against the
  real geocoding API (Open-Meteo) and, for landmarks or natural-language
  requests, interpreted by the Chyllz AI model before it is accepted. Travellers
  can also start from a trending destination. The remaining steps collect the
  trip brief, and the final screen summarises it with links to the Chyllz
  assistant and catalogue.
  """

  use XpressbusWeb, :live_view

  alias Xpressbus.{Accounts, Itineraries, TripItinerary}

  import XpressbusWeb.ChyllzAccountArt

  alias Xpressbus.Places

  @generation_deadline_ms 10_000

  @generation_steps [
    %{key: :brief, label: "Getting to know you"},
    %{key: :stays, label: "Your stay"},
    %{key: :table, label: "Your table"},
    %{key: :days, label: "Your days"},
    %{key: :care, label: "Your peace of mind"},
    %{key: :final, label: "Final caring check"}
  ]

  @generation_default %{
    message: "Getting to know your trip...",
    detail: "I'm reading your brief and gathering the details that make this trip yours."
  }

  @steps [
    %{key: 1, title: "Destination", icon: :pin},
    %{key: 2, title: "Dates", icon: :calendar},
    %{key: 3, title: "Companions", icon: :users},
    %{key: 4, title: "Budget", icon: :wallet},
    %{key: 5, title: "Preferences", icon: :sliders}
  ]

  @destinations [
    %{
      name: "Cox's Bazar",
      country: "Bangladesh",
      art: :coast,
      tag: "cox",
      latitude: 21.4272,
      longitude: 92.0058
    },
    %{
      name: "Saint Martins",
      country: "Bangladesh",
      art: :coast,
      tag: "saint-martins",
      latitude: 20.6000,
      longitude: 92.3200
    },
    %{
      name: "Rome",
      country: "Italy",
      art: :mountains,
      tag: "rome",
      latitude: 41.9028,
      longitude: 12.4964
    },
    %{
      name: "Bangkok",
      country: "Thailand",
      art: :mountains,
      tag: "bangkok",
      latitude: 13.7563,
      longitude: 100.5018
    },
    %{
      name: "New York",
      country: "United States",
      art: :savanna,
      tag: "new-york",
      latitude: 40.7128,
      longitude: -74.0060
    },
    %{
      name: "Las Vegas",
      country: "United States",
      art: :savanna,
      tag: "las-vegas",
      latitude: 36.1699,
      longitude: -115.1398
    },
    %{
      name: "Istanbul",
      country: "Turkey",
      art: :coast,
      tag: "istanbul",
      latitude: 41.0082,
      longitude: 28.9784
    }
  ]

  @preferences [
    %{key: "adventure-travel", label: "Adventure Travel", emoji: "🏔️"},
    %{key: "city-breaks", label: "City Breaks", emoji: "🏙️"},
    %{key: "glamping", label: "Glamping", emoji: "🏕️"},
    %{key: "beach-vacations", label: "Beach Vacations", emoji: "🏖️"},
    %{key: "relaxing-getaways", label: "Relaxing Getaways", emoji: "🧘"},
    %{key: "nature-escapes", label: "Nature Escapes", emoji: "🌿"},
    %{key: "road-trips", label: "Road Trips", emoji: "🚗"},
    %{key: "food-tourism", label: "Food Tourism", emoji: "🍱"},
    %{key: "cruise-vacations", label: "Cruise Vacations", emoji: "🛳️"},
    %{key: "wildlife-safaris", label: "Wildlife Safaris", emoji: "🦁"},
    %{key: "art-galleries", label: "Art Galleries", emoji: "🎨"},
    %{key: "horse-riding", label: "Horse Riding", emoji: "🐎"},
    %{key: "cultural-exploration", label: "Cultural Exploration", emoji: "🏛️"}
  ]

  @preference_labels Enum.map(@preferences, & &1.label)

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
    %{
      key: "cheap",
      title: "Cheap",
      description: "Budget-friendly economical travel",
      icon: :money
    },
    %{
      key: "balanced",
      title: "Balanced",
      description: "Moderate spending for a balanced trip",
      icon: :wallet
    },
    %{
      key: "luxury",
      title: "Luxury",
      description: "High-end, indulgent experiences",
      icon: :gem
    },
    %{
      key: "flexible",
      title: "Flexible",
      description: "No budget restrictions",
      icon: :sparkles
    },
    %{
      key: "custom",
      title: "Custom Budget",
      description: "Darjeeling 3 days tour",
      icon: :map
    },
    %{
      key: "mars",
      title: "Mars Tour",
      description: "Mars Tour with Elon Musk",
      icon: :rocket
    }
  ]

  @budget_keys Enum.map(@budgets, & &1.key)

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:current_user, current_user_from_session(session))
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
     |> assign(:suggestions, [])
     |> assign(:searching, false)
     |> assign(:search_empty, false)
     |> assign(:error, nil)
     |> assign(:saved_itinerary, nil)
     |> assign(:itinerary, nil)
     |> assign(:generating, false)
     |> assign(:generation_stage, 0)
     |> assign(:generation_total, length(@generation_steps))
     |> assign(:generation_message, @generation_default.message)
     |> assign(:generation_detail, @generation_default.detail)
     |> assign(:generation_task_label, generation_step(0).label)
     |> assign(:generation_ref, nil)
     |> assign(:generation_pid, nil)
     |> assign(:generation_started_at, nil)
     |> assign(:today, Date.utc_today())
     |> assign(:calendar_month, Date.beginning_of_month(Date.utc_today()))
     |> reset_trip()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, maybe_load_saved_itinerary(socket, params)}
  end

  @impl true
  def handle_event("destination_query", %{"query" => query}, socket) do
    query = sanitize_query(query)

    if String.length(query) < 2 do
      {:noreply,
       socket
       |> assign(:query, query)
       |> assign(:suggestions, [])
       |> assign(:searching, false)
       |> assign(:search_empty, false)}
    else
      {:noreply,
       socket
       |> assign(:query, query)
       |> assign(:error, nil)
       |> assign(:suggestions, [])
       |> assign(:searching, true)
       |> assign(:search_empty, false)
       |> start_async(:destination_search, fn -> Places.search(query) end)}
    end
  end

  def handle_event("search_destination", %{"query" => query}, socket) do
    query = sanitize_query(query)

    cond do
      query == "" ->
        {:noreply, assign(socket, :error, "Type a city, country or landmark to continue.")}

      socket.assigns.searching ->
        {:noreply, socket}

      place = List.first(socket.assigns.suggestions) ->
        {:noreply, choose_place(socket, place)}

      true ->
        {:noreply,
         socket
         |> assign(:query, query)
         |> assign(:error, nil)
         |> assign(:searching, true)
         |> assign(:search_empty, false)
         |> start_async(:destination_resolve, fn -> Places.resolve(query) end)}
    end
  end

  def handle_event("choose_suggestion", params, socket) do
    place = %{
      name: to_string(params["name"] || ""),
      country: to_string(params["country"] || ""),
      region: params["region"],
      latitude: parse_number(params["latitude"]),
      longitude: parse_number(params["longitude"]),
      source: :geocoding
    }

    if place.name == "" do
      {:noreply, socket}
    else
      {:noreply, choose_place(socket, place)}
    end
  end

  def handle_event(
        "choose_destination",
        %{"destination" => destination, "country" => country} = params,
        socket
      ) do
    place = %{
      name: to_string(destination),
      country: to_string(country || ""),
      region: nil,
      latitude: parse_number(params["latitude"]),
      longitude: parse_number(params["longitude"]),
      source: :curated
    }

    {:noreply, socket |> assign(:error, nil) |> choose_place(place)}
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
    {:noreply,
     socket
     |> assign(:step, 1)
     |> assign(:query, socket.assigns.trip.destination || "")
     |> assign(:suggestions, [])
     |> assign(:searching, false)
     |> assign(:search_empty, false)}
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

  def handle_event("select_budget", %{"budget" => budget}, socket) do
    if budget in @budget_keys do
      {:noreply,
       socket
       |> assign(:error, nil)
       |> assign(:trip, %{socket.assigns.trip | budget: budget})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("budget_next", _params, socket) do
    if socket.assigns.trip.budget do
      {:noreply, socket |> assign(:error, nil) |> assign(:step, 5)}
    else
      {:noreply, assign(socket, :error, "Choose a spending style to continue.")}
    end
  end

  def handle_event("toggle_preference", %{"preference" => preference}, socket) do
    if preference in @preference_labels do
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
      parent = self()
      trip = socket.assigns.trip

      {pid, ref} =
        spawn_monitor(fn -> send(parent, {:generation_done, TripItinerary.generate(trip)}) end)

      Process.send_after(self(), :generation_tick, 1_200)
      Process.send_after(self(), :generation_timeout, @generation_deadline_ms)

      copy = generation_copy(:brief, trip)

      {:noreply,
       socket
       |> assign(:error, nil)
       |> assign(:generating, true)
       |> assign(:generation_stage, 0)
       |> assign(:generation_total, length(@generation_steps))
       |> assign(:generation_message, copy.message)
       |> assign(:generation_detail, copy.detail)
       |> assign(:generation_task_label, generation_step(0).label)
       |> assign(:generation_ref, ref)
       |> assign(:generation_pid, pid)
       |> assign(:generation_started_at, System.monotonic_time(:millisecond))}
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
     |> assign(:generating, false)
     |> assign(:generation_stage, 0)
     |> assign(:generation_total, length(@generation_steps))
     |> assign(:generation_message, @generation_default.message)
     |> assign(:generation_detail, @generation_default.detail)
     |> assign(:generation_task_label, generation_step(0).label)
     |> assign(:generation_ref, nil)
     |> assign(:generation_pid, nil)
     |> assign(:generation_started_at, nil)
     |> assign(:today, Date.utc_today())
     |> assign(:itinerary, nil)
     |> assign(:saved_itinerary, nil)
     |> assign(:calendar_month, Date.beginning_of_month(Date.utc_today()))
     |> reset_trip()}
  end

  def handle_event("save_itinerary", _params, socket) do
    case socket.assigns[:current_user] do
      nil ->
        {:noreply, put_flash(socket, :error, "Sign in to save this itinerary to My Chyllz.")}

      user ->
        case persist_itinerary(user, socket) do
          {:ok, saved} ->
            {:noreply,
             socket
             |> assign(:saved_itinerary, saved)
             |> put_flash(:info, "Itinerary saved to My Chyllz.")
             |> push_navigate(to: "/dashboard?tab=chyllz")}

          {:error, _reason} ->
            {:noreply,
             put_flash(socket, :error, "Could not save this itinerary. Please try again.")}
        end
    end
  end

  defp persist_itinerary(user, socket) do
    case socket.assigns[:saved_itinerary] do
      nil -> Itineraries.save(user, socket.assigns.trip, socket.assigns.itinerary)
      saved -> Itineraries.update(saved, socket.assigns.trip, socket.assigns.itinerary)
    end
  end

  defp current_user_from_session(session) do
    with user_id when is_binary(user_id) <- session["user_id"],
         %{} = user <- Accounts.get_user(user_id) do
      user
    else
      _other -> nil
    end
  end

  defp maybe_load_saved_itinerary(socket, %{"saved" => saved_id}) when is_binary(saved_id) do
    with %{} = user <- socket.assigns[:current_user],
         %{} = saved <- Itineraries.get_for_user(user, saved_id) do
      socket
      |> assign(:saved_itinerary, saved)
      |> assign(:trip, Itineraries.to_trip(saved))
      |> assign(:itinerary, Itineraries.itinerary(saved))
      |> assign(:query, saved.destination)
      |> assign(:error, nil)
      |> assign(:generating, false)
      |> assign(:step, 6)
    else
      _other -> socket
    end
  end

  defp maybe_load_saved_itinerary(socket, _params), do: socket
  @impl true
  def handle_async(:destination_search, {:ok, {:ok, results}}, socket) do
    {:noreply,
     socket
     |> assign(:suggestions, results)
     |> assign(:searching, false)
     |> assign(:search_empty, results == [])}
  end

  def handle_async(:destination_search, {:ok, {:error, _reason}}, socket) do
    {:noreply,
     socket
     |> assign(:suggestions, [])
     |> assign(:searching, false)
     |> assign(:search_empty, true)}
  end

  def handle_async(:destination_search, {:exit, _reason}, socket) do
    {:noreply,
     socket
     |> assign(:suggestions, [])
     |> assign(:searching, false)
     |> assign(:search_empty, true)}
  end

  def handle_async(:destination_resolve, {:ok, {:ok, place, _results}}, socket) do
    {:noreply, choose_place(socket, place)}
  end

  def handle_async(:destination_resolve, {:ok, {:error, _reason}}, socket) do
    {:noreply, destination_not_found(socket)}
  end

  def handle_async(:destination_resolve, {:exit, _reason}, socket) do
    {:noreply, destination_not_found(socket)}
  end

  @impl true
  def handle_info(:trip_generated, socket) do
    itinerary = TripItinerary.generate(socket.assigns.trip)

    {:noreply,
     socket
     |> assign(:generating, false)
     |> assign(:generation_ref, nil)
     |> assign(:itinerary, itinerary)
     |> assign(:step, 6)}
  end

  def handle_info(:generation_tick, socket) do
    if socket.assigns.generating do
      next_stage = min(socket.assigns.generation_stage + 1, length(@generation_steps) - 1)
      step = generation_step(next_stage)
      copy = generation_copy(step.key, socket.assigns.trip)

      if next_stage < length(@generation_steps) - 1 do
        Process.send_after(self(), :generation_tick, 1_600)
      end

      {:noreply,
       socket
       |> assign(:generation_stage, next_stage)
       |> assign(:generation_message, copy.message)
       |> assign(:generation_detail, copy.detail)
       |> assign(:generation_task_label, step.label)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:generation_done, itinerary}, socket) do
    if socket.assigns.generating do
      if socket.assigns.generation_ref do
        Process.demonitor(socket.assigns.generation_ref, [:flush])
      end

      started_at = socket.assigns.generation_started_at || System.monotonic_time(:millisecond)

      remaining =
        max(@generation_deadline_ms - (System.monotonic_time(:millisecond) - started_at), 0)

      if remaining > 0 do
        Process.send_after(self(), {:generation_complete, itinerary}, remaining)
        {:noreply, socket |> assign(:generation_ref, nil) |> assign(:generation_pid, nil)}
      else
        complete_generation(socket, itinerary)
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:generation_complete, itinerary}, socket) do
    if socket.assigns.generating do
      complete_generation(socket, itinerary)
    else
      {:noreply, socket}
    end
  end

  def handle_info(:generation_timeout, socket) do
    if socket.assigns.generating do
      if is_pid(socket.assigns.generation_pid) do
        Process.exit(socket.assigns.generation_pid, :kill)
      end

      itinerary = TripItinerary.generate(socket.assigns.trip, live_places: false)
      complete_generation(socket, itinerary)
    else
      {:noreply, socket}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
    if socket.assigns.generation_ref == ref and socket.assigns.generating do
      require Logger
      Logger.error("Trip generation failed: #{inspect(reason)}")

      {:noreply,
       socket
       |> assign(:generating, false)
       |> assign(:generation_ref, nil)
       |> assign(:generation_message, hd(@generation_steps))
       |> assign(:error, "We couldn't finish your itinerary. Please try again.")}
    else
      {:noreply, socket}
    end
  end

  defp generation_copy(:brief, trip) do
    destination = generation_destination(trip)
    party = generation_party(trip)
    preferences = generation_preferences(trip)

    %{
      message: "Getting to know your #{party} trip to #{destination}...",
      detail:
        "I'm reading your dates, budget, love of #{preferences} and the little details that make this trip yours."
    }
  end

  defp generation_copy(:stays, trip) do
    destination = generation_destination(trip)
    party = generation_party(trip)

    %{
      message: "Hand-picking stays in #{destination} for you...",
      detail:
        "I'm comparing Google ratings and recent guest reviews so every Hotels & Stays pick feels right for your #{party} trip."
    }
  end

  defp generation_copy(:table, trip) do
    destination = generation_destination(trip)
    preferences = generation_preferences(trip)

    %{
      message: "Finding tables worth travelling for in #{destination}...",
      detail:
        "I'm checking Recommended Restaurants against Google ratings and review volume, with your love of #{preferences} in mind."
    }
  end

  defp generation_copy(:days, trip) do
    destination = generation_destination(trip)
    duration = generation_duration(trip)
    date_range = generation_date_range(trip)

    %{
      message: "Shaping your #{duration} days in #{destination}...",
      detail:
        "I'm balancing morning, lunch, afternoon, evening and dinner around #{date_range}, so the days flow without feeling rushed."
    }
  end

  defp generation_copy(:care, trip) do
    destination = generation_destination(trip)

    %{
      message: "Sweating the small stuff so you don't have to...",
      detail:
        "I'm adding Important Notes on visas, currency, language, transport and safety for #{destination}."
    }
  end

  defp generation_copy(:final, trip) do
    destination = generation_destination(trip)

    %{
      message: "Giving your #{destination} itinerary one last caring look...",
      detail:
        "Rechecking every stay, table, map stop and note — then it's all yours to enjoy. You've got a trip to look forward to."
    }
  end

  defp generation_destination(trip) do
    value = to_string(trip.destination || "")

    if value == "", do: "your destination", else: value
  end

  defp generation_party(trip) do
    case trip.travel_party do
      "solo" -> "solo"
      "couple" -> "couple's"
      "family" -> "family"
      "friends" -> "friends'"
      _other -> "personal"
    end
  end

  defp generation_preferences(trip) do
    case trip.preferences do
      [] ->
        "the experiences you enjoy"

      preferences ->
        case preferences do
          [only] -> only
          values -> Enum.join(Enum.drop(values, -1), ", ") <> " and " <> List.last(values)
        end
    end
  end

  defp generation_duration(trip) do
    case {trip.start_date, trip.end_date} do
      {%Date{} = start_date, %Date{} = end_date} ->
        days = max(Date.diff(end_date, start_date) + 1, 1)
        "#{days}-day"

      _other ->
        "multi-day"
    end
  end

  defp generation_date_range(trip) do
    case {trip.start_date, trip.end_date} do
      {%Date{} = start_date, %Date{} = end_date} ->
        "#{Calendar.strftime(start_date, "%d %b")} to #{Calendar.strftime(end_date, "%d %b")}"

      _other ->
        "your travel dates"
    end
  end

  defp generation_step(index) do
    Enum.at(@generation_steps, min(index, length(@generation_steps) - 1))
  end

  defp complete_generation(socket, itinerary) do
    {:noreply,
     socket
     |> assign(:generating, false)
     |> assign(:generation_ref, nil)
     |> assign(:generation_pid, nil)
     |> assign(:itinerary, itinerary)
     |> assign(:step, 6)}
  end

  defp reset_trip(socket) do
    assign(socket, :trip, %{
      destination: nil,
      country: nil,
      region: nil,
      latitude: nil,
      longitude: nil,
      place_source: nil,
      start_date: nil,
      end_date: nil,
      travel_party: nil,
      pets: false,
      budget: nil,
      preferences: []
    })
  end

  defp choose_place(socket, place) do
    trip = %{
      socket.assigns.trip
      | destination: place.name |> to_string() |> String.trim() |> String.slice(0, 80),
        country: to_string(Map.get(place, :country) || ""),
        region: Map.get(place, :region),
        latitude: Map.get(place, :latitude),
        longitude: Map.get(place, :longitude),
        place_source: Map.get(place, :source)
    }

    socket
    |> assign(:trip, trip)
    |> assign(:step, 2)
    |> assign(:query, trip.destination)
    |> assign(:suggestions, [])
    |> assign(:searching, false)
    |> assign(:search_empty, false)
    |> assign(:error, nil)
  end

  defp destination_not_found(socket) do
    socket
    |> assign(:searching, false)
    |> assign(:suggestions, [])
    |> assign(
      :error,
      "We couldn't find that place. Search for a real city or country - e.g. Nairobi, Paris or " <>
        "Bali - or describe the vibe and let Chyllz AI pinpoint the nearest real place."
    )
  end

  defp sanitize_query(query) do
    query
    |> to_string()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, 80)
  end

  defp parse_number(value) when is_number(value), do: value

  defp parse_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp parse_number(_value), do: nil

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
end
