defmodule XpressbusWeb.ChyllzLive do
  @moduledoc """
  Public Chyllz storefront.

  The five Chyllz routes share this LiveView:

    * `/tour-packages`              - overview of all four collections
    * `/tour-packages/hotels`       - hotel collection with search
    * `/our-packages/hidden-gems`   - hidden gem collection with search
    * `/tour-packages/car`          - car hire collection with search
    * `/tour-packages/events`       - upcoming events (falls back to recent events)

  Every card is rendered from the database through `Xpressbus.Chyllz`; the
  page only contains copy, layout and presentation. Clicking a card opens a
  detail dialog and the CTA links into the bus search prefilled with the
  destination, so no card is a dead end.
  """

  use XpressbusWeb, :live_view

  import XpressbusWeb.AssistantComponents
  import XpressbusWeb.BrandComponents

  import XpressbusWeb.Format,
    only: [day_of_month: 1, long_date: 1, money: 1, month_abbr: 1, rating: 1, short_date: 1]

  alias Xpressbus.{Accounts, Chyllz, HotelBookings, TravelAssistant}

  @listing_limit 60
  @room_images ["/images/room_1.webp", "/images/room_2.webp", "/images/room_3.webp"]
  @assistant_hourly_limit 40

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:step, :chyllz)
     |> assign(:footer_tab, "about")
     |> assign(:current_user, session["user_id"])
     |> assign(:search, "")
     |> assign(:selected, nil)
     |> assign(:stay_error, nil)
     |> assign(:stay_check_in, Date.to_iso8601(Date.add(Date.utc_today(), 1)))
     |> assign(:stay_check_out, Date.to_iso8601(Date.add(Date.utc_today(), 2)))
     |> assign(:stay_rooms, "1")
     |> assign(:stay_guests, "1")
     |> assign(:hotels, [])
     |> assign(:hidden_gems, [])
     |> assign(:car_hires, [])
     |> assign(:events, [])
     |> assign(:past_events, [])
     |> assign(:events_are_past, false)
     |> assign(:counts, %{hotels: 0, hidden_gems: 0, car_hires: 0, events: 0})
     |> assign(:assistant, initial_assistant_state())
     |> assign(:assistant_ai_enabled, TravelAssistant.provider_configured?())
     |> assign(:assistant_engine, TravelAssistant.engine_label())
     |> allow_upload(:assistant_photo,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 1,
       max_file_size: 8_000_000
     )
     |> assign(
       :page_description,
       "Discover handpicked hotels, hidden gems, car hire and events across East Africa with Chyllz by KOMIUTA. Book stays and experiences alongside your bus ticket."
     )
     |> assign(:page_canonical, XpressbusWeb.Endpoint.url() <> "/tour-packages")
     |> assign(:page_json_ld, chyllz_json_ld(:chyllz))
     |> assign(:page_title, "Chyllz · Hotels, Hidden Gems, Car Hire & Events")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    step = step_for(socket.assigns.live_action)
    search = normalize_search(Map.get(params, "q", ""))

    socket =
      socket
      |> assign(:step, step)
      |> assign(:search, search)
      |> assign(:selected, nil)
      |> assign(:page_title, page_title_for(step))
      |> assign(:page_canonical, canonical_for(step))
      |> assign(:page_json_ld, chyllz_json_ld(step))
      |> load_step(step, search)
      |> maybe_open_assistant(params)

    {:noreply, socket}
  end

  # The Chyllz account hero's "Build with AI" button deep-links here with
  # `?assistant=1`; open the travel assistant straight away.
  defp maybe_open_assistant(socket, params) do
    if Map.get(params, "assistant") in ["1", "open", "true"] do
      assign_assistant(socket, %{socket.assigns.assistant | open: true, error: nil})
    else
      socket
    end
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: search_path(socket.assigns.step, query))}
  end

  def handle_event("hub_search", %{"q" => query}, socket) do
    {:noreply, push_patch(socket, to: search_path(:hotels, query))}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, push_patch(socket, to: search_path(socket.assigns.step, ""))}
  end

  def handle_event("open_item", %{"kind" => kind, "id" => id}, socket) do
    case find_item(socket.assigns, kind, id) do
      nil ->
        {:noreply, socket}

      item ->
        socket =
          socket
          |> assign(:selected, %{kind: kind, item: item})
          |> assign(:stay_error, nil)

        socket =
          if kind == "hotel" do
            today = Date.utc_today()

            socket
            |> assign(:stay_check_in, Date.to_iso8601(Date.add(today, 1)))
            |> assign(:stay_check_out, Date.to_iso8601(Date.add(today, 2)))
            |> assign(:stay_rooms, "1")
            |> assign(:stay_guests, "1")
          else
            socket
          end

        {:noreply, socket}
    end
  end

  def handle_event("book_stay", params, socket) do
    user =
      case socket.assigns.current_user do
        nil -> nil
        identity -> Accounts.get_user(identity) || Accounts.get_user_by_phone(identity)
      end

    hotel =
      case socket.assigns.selected do
        %{kind: "hotel", item: hotel} -> hotel
        _ -> nil
      end

    cond do
      is_nil(user) ->
        {:noreply,
         socket
         |> put_flash(:error, "Sign in to reserve a stay.")
         |> push_navigate(to: ~p"/user/login")}

      is_nil(hotel) ->
        {:noreply, assign(socket, :stay_error, "Choose a hotel before reserving.")}

      true ->
        socket =
          socket
          |> assign(:stay_check_in, params["check_in"] || socket.assigns.stay_check_in)
          |> assign(:stay_check_out, params["check_out"] || socket.assigns.stay_check_out)
          |> assign(:stay_rooms, params["rooms"] || socket.assigns.stay_rooms)
          |> assign(:stay_guests, params["guests"] || socket.assigns.stay_guests)

        case HotelBookings.create_booking(user, hotel, params) do
          {:ok, booking} ->
            {:noreply,
             socket
             |> assign(:selected, nil)
             |> assign(:stay_error, nil)
             |> put_flash(
               :success,
               "Stay reserved. #{booking.hotel_name} · #{booking.reference}"
             )
             |> push_navigate(to: ~p"/dashboard?tab=chyllz")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :stay_error, stay_error_message(changeset))}

          {:error, :past_check_in} ->
            {:noreply, assign(socket, :stay_error, "Check-in date cannot be in the past.")}

          {:error, :invalid_dates} ->
            {:noreply, assign(socket, :stay_error, "Check-out must be after check-in.")}

          {:error, _reason} ->
            {:noreply, assign(socket, :stay_error, "Could not create the reservation.")}
        end
    end
  end

  def handle_event("close_item", _params, socket) do
    {:noreply, assign(socket, :selected, nil)}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  def handle_event("back_to_search", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  # --- Chyllz AI assistant ---------------------------------------------------

  @impl true
  def handle_event("assistant_open", _params, socket) do
    {:noreply, assign_assistant(socket, %{socket.assigns.assistant | open: true, error: nil})}
  end

  def handle_event("assistant_close", _params, socket) do
    {:noreply, assign_assistant(socket, %{socket.assigns.assistant | open: false})}
  end

  def handle_event("assistant_escape", _params, socket) do
    if socket.assigns.assistant.open do
      {:noreply, assign_assistant(socket, %{socket.assigns.assistant | open: false})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("assistant_tab", %{"tab" => tab}, socket)
      when tab in ~w(chat lens receipt food) do
    state = %{socket.assigns.assistant | tab: tab, error: nil, input: ""}
    {:noreply, assign_assistant(socket, state)}
  end

  def handle_event("assistant_tab", _params, socket), do: {:noreply, socket}

  def handle_event("assistant_input", %{"message" => message}, socket) do
    state = %{
      socket.assigns.assistant
      | input: message |> to_string() |> String.slice(0, 1_000)
    }

    {:noreply, assign_assistant(socket, state)}
  end

  def handle_event("assistant_caption", %{"caption" => caption}, socket) do
    state = %{socket.assigns.assistant | caption: caption |> to_string() |> String.slice(0, 300)}
    {:noreply, assign_assistant(socket, state)}
  end

  def handle_event("assistant_validate_upload", params, socket) do
    caption = Map.get(params, "caption", socket.assigns.assistant.caption)

    state = %{
      socket.assigns.assistant
      | caption: caption |> to_string() |> String.slice(0, 300),
        error: nil
    }

    {:noreply, assign_assistant(socket, state)}
  end

  def handle_event("assistant_send", %{"message" => message}, socket) do
    {:noreply, assistant_submit(socket, message)}
  end

  def handle_event("assistant_suggestion", %{"prompt" => prompt}, socket) do
    {:noreply, assistant_submit(socket, prompt)}
  end

  def handle_event("assistant_new_chat", _params, socket) do
    state = socket.assigns.assistant

    socket =
      if state.pending do
        cancel_async(socket, {:assistant_reply, state.pending_ref})
      else
        socket
      end

    socket =
      Enum.reduce(socket.assigns.uploads.assistant_photo.entries, socket, fn entry, acc ->
        cancel_upload(acc, :assistant_photo, entry.ref)
      end)

    state = %{
      state
      | threads: Map.put(state.threads, state.tab, []),
        input: "",
        caption: "",
        receipt_text: "",
        error: nil,
        pending: false,
        pending_ref: nil,
        pending_tab: nil,
        pending_prompt: nil,
        pending_history: nil
    }

    {:noreply, assign_assistant(socket, state)}
  end

  def handle_event("assistant_cancel_upload", %{"ref" => ref}, socket) do
    socket = cancel_upload(socket, :assistant_photo, ref)
    {:noreply, assign_assistant(socket, %{socket.assigns.assistant | error: nil})}
  end

  def handle_event("assistant_analyze", params, socket) do
    caption = Map.get(params, "caption", socket.assigns.assistant.caption)
    {:noreply, assistant_analyze_photo(socket, to_string(caption))}
  end

  def handle_event("assistant_receipt_text", %{"receipt_text" => text}, socket) do
    {:noreply, assistant_receipt_submit(socket, text)}
  end

  def handle_event("assistant_clear_expenses", _params, socket) do
    {:noreply, assign_assistant(socket, %{socket.assigns.assistant | expenses: []})}
  end

  @impl true
  def handle_async({:assistant_reply, ref}, {:ok, {tab, reply}}, socket) do
    if socket.assigns.assistant.pending_ref == ref do
      socket =
        socket
        |> clear_assistant_pending()
        |> append_assistant_reply(tab, reply)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:assistant_reply, ref}, {:exit, _reason}, socket) do
    state = socket.assigns.assistant

    if state.pending_ref == ref do
      tab = state.pending_tab || state.tab
      prompt = state.pending_prompt || ""
      context = TravelAssistant.context()

      fallback =
        TravelAssistant.respond(tab, prompt, state.pending_history || [], context, use_ai: false)

      reply = %{
        fallback
        | text:
            "I couldn't reach the AI service just now — here's the catalogue answer instead.\n\n" <>
              fallback.text
      }

      socket =
        socket
        |> clear_assistant_pending()
        |> append_assistant_reply(tab, reply)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_async(_name, _result, socket), do: {:noreply, socket}

  defp initial_assistant_state do
    %{
      open: false,
      tab: "chat",
      threads: %{"chat" => [], "lens" => [], "receipt" => [], "food" => []},
      pending: false,
      pending_ref: nil,
      pending_tab: nil,
      pending_prompt: nil,
      pending_history: nil,
      input: "",
      caption: "",
      receipt_text: "",
      expenses: [],
      error: nil,
      sequence: 0,
      requests: []
    }
  end

  defp assign_assistant(socket, state), do: assign(socket, :assistant, state)

  defp assistant_submit(socket, text) do
    text = text |> to_string() |> String.trim() |> String.slice(0, 1_000)
    state = socket.assigns.assistant
    rate = assistant_rate_status(state)

    cond do
      text == "" ->
        socket

      state.pending ->
        assign_assistant(socket, %{state | input: ""})

      rate.limited ->
        socket = append_chat_message(socket, state.tab, :user, text)

        socket =
          assign_assistant(socket, %{
            socket.assigns.assistant
            | input: "",
              requests: rate.requests
          })

        append_chat_message(
          socket,
          state.tab,
          :assistant,
          "You've reached this hour's assistant limit. Give it a few minutes, or browse the Chyllz catalogue in the meantime."
        )

      state.tab == "receipt" and receipt_like?(text) ->
        assistant_receipt_submit(socket, text)

      true ->
        assistant_respond(socket, text, rate.requests)
    end
  end

  defp assistant_respond(socket, text, requests) do
    state = socket.assigns.assistant
    tab = state.tab
    history = state.threads[tab] || []
    context = TravelAssistant.context()

    socket = append_chat_message(socket, tab, :user, text)
    state = socket.assigns.assistant

    socket =
      assign_assistant(socket, %{
        state
        | input: "",
          error: nil,
          requests: requests
      })

    if socket.assigns.assistant_ai_enabled and tab in ["chat", "food"] do
      ref = System.unique_integer([:positive])

      socket
      |> assign_assistant(%{
        socket.assigns.assistant
        | pending: true,
          pending_ref: ref,
          pending_tab: tab,
          pending_prompt: text,
          pending_history: history
      })
      |> start_async({:assistant_reply, ref}, fn ->
        {tab, TravelAssistant.respond(tab, text, history, context)}
      end)
    else
      reply = TravelAssistant.respond(tab, text, history, context, use_ai: false)
      append_assistant_reply(socket, tab, reply)
    end
  end

  defp assistant_receipt_submit(socket, text) do
    text = to_string(text)

    if String.trim(text) == "" do
      assign_assistant(socket, %{
        socket.assigns.assistant
        | error: "Paste the receipt lines first."
      })
    else
      result = TravelAssistant.parse_receipt_text(text)
      label = text |> String.trim() |> String.slice(0, 500)

      socket =
        socket
        |> append_chat_message("receipt", :user, label)
        |> append_assistant_reply("receipt", %{
          text: result.text,
          cards: [],
          action: nil,
          source: :local,
          receipt: result.receipt
        })

      state = socket.assigns.assistant
      assign_assistant(socket, %{state | receipt_text: "", input: "", error: nil})
    end
  end

  defp assistant_analyze_photo(socket, caption) do
    state = socket.assigns.assistant

    cond do
      state.pending ->
        socket

      socket.assigns.uploads.assistant_photo.entries == [] ->
        assign_assistant(socket, %{
          state
          | error: "Add a photo first — or paste the receipt lines below."
        })

      true ->
        [entry | _rest] = socket.assigns.uploads.assistant_photo.entries
        content_type = image_content_type(entry.client_type, entry.client_name)

        case consume_uploaded_entry(socket, entry, fn %{path: path} ->
               case File.read(path) do
                 {:ok, binary} when byte_size(binary) > 0 -> {:ok, binary}
                 {:ok, _empty} -> {:error, :empty}
                 {:error, reason} -> {:error, reason}
               end
             end) do
          binary when is_binary(binary) ->
            data_url = "data:" <> content_type <> ";base64," <> Base.encode64(binary)
            tab = state.tab
            history = state.threads[tab] || []
            user_text = if String.trim(caption) == "", do: "📷 Photo", else: "📷 " <> caption

            socket = append_chat_message(socket, tab, :user, user_text)
            state = socket.assigns.assistant

            socket =
              assign_assistant(socket, %{
                state
                | caption: "",
                  input: "",
                  error: nil
              })

            if socket.assigns.assistant_ai_enabled do
              ref = System.unique_integer([:positive])

              socket
              |> assign_assistant(%{
                socket.assigns.assistant
                | pending: true,
                  pending_ref: ref,
                  pending_tab: tab,
                  pending_prompt: caption,
                  pending_history: history
              })
              |> start_async({:assistant_reply, ref}, fn ->
                {tab, TravelAssistant.photo_reply(tab, data_url, caption)}
              end)
            else
              reply = TravelAssistant.photo_reply(tab, data_url, caption)
              append_assistant_reply(socket, tab, reply)
            end

          {:error, _reason} ->
            assign_assistant(socket, %{
              socket.assigns.assistant
              | error: "That photo could not be read. Please try another image."
            })
        end
    end
  end

  defp append_assistant_reply(socket, tab, reply) do
    socket =
      append_chat_message(socket, tab, :assistant, reply.text,
        cards: reply.cards || [],
        action: reply.action,
        source: reply.source
      )

    if Map.get(reply, :receipt) do
      add_assistant_expense(socket, reply.receipt)
    else
      socket
    end
  end

  defp append_chat_message(socket, tab, role, text, opts \\ []) do
    state = socket.assigns.assistant
    sequence = state.sequence + 1

    message = %{
      id: "assistant-message-#{sequence}",
      role: role,
      text: to_string(text),
      cards: Keyword.get(opts, :cards, []),
      action: Keyword.get(opts, :action),
      source: Keyword.get(opts, :source)
    }

    thread =
      ((state.threads[tab] || []) ++ [message])
      |> Enum.take(-60)

    state = %{state | sequence: sequence, threads: Map.put(state.threads, tab, thread)}
    assign_assistant(socket, state)
  end

  defp add_assistant_expense(socket, summary) do
    state = socket.assigns.assistant
    entry = TravelAssistant.expense_entry(summary)
    expenses = (state.expenses ++ [entry]) |> Enum.take(-20)
    assign_assistant(socket, %{state | expenses: expenses})
  end

  defp clear_assistant_pending(socket) do
    state = %{
      socket.assigns.assistant
      | pending: false,
        pending_ref: nil,
        pending_tab: nil,
        pending_prompt: nil,
        pending_history: nil
    }

    assign_assistant(socket, state)
  end

  defp assistant_rate_status(state) do
    now = System.monotonic_time(:millisecond)
    recent = Enum.filter(state.requests || [], &(now - &1 < 3_600_000))

    %{
      limited: length(recent) >= @assistant_hourly_limit,
      requests: [now | recent]
    }
  end

  defp receipt_like?(text) do
    String.contains?(text, "\n") and Regex.match?(~r/\d/, text)
  end

  defp image_content_type(client_type, filename) do
    cond do
      is_binary(client_type) and String.starts_with?(client_type, "image/") ->
        client_type

      is_binary(filename) and String.ends_with?(String.downcase(filename), ".png") ->
        "image/png"

      is_binary(filename) and String.ends_with?(String.downcase(filename), ".webp") ->
        "image/webp"

      true ->
        "image/jpeg"
    end
  end

  defp load_step(socket, :chyllz, _search) do
    events = upcoming_or_recent_events(2)

    socket
    |> assign(:hotels, Chyllz.hotels(limit: 3))
    |> assign(:hidden_gems, Chyllz.hidden_gems(limit: 3))
    |> assign(:car_hires, Chyllz.car_hires(limit: 4))
    |> assign(:events, events)
    |> assign(:events_are_past, past_events?(events))
    |> assign(:counts, Chyllz.counts())
  end

  defp load_step(socket, :hotels, search) do
    assign(socket, :hotels, Chyllz.hotels(search: search, limit: @listing_limit))
  end

  defp load_step(socket, :gems, search) do
    assign(socket, :hidden_gems, Chyllz.hidden_gems(search: search, limit: @listing_limit))
  end

  defp load_step(socket, :car, search) do
    assign(socket, :car_hires, Chyllz.car_hires(search: search, limit: @listing_limit))
  end

  defp load_step(socket, :events, search) do
    upcoming = Chyllz.upcoming_events(search: search, limit: @listing_limit)

    recent =
      if upcoming == [] and search == "" do
        Chyllz.past_events(limit: 6)
      else
        []
      end

    socket
    |> assign(:events, if(recent == [], do: upcoming, else: recent))
    |> assign(:past_events, recent)
    |> assign(:events_are_past, recent != [])
  end

  defp upcoming_or_recent_events(limit) do
    case Chyllz.upcoming_events(limit: limit) do
      [] -> Chyllz.past_events(limit: limit)
      events -> events
    end
  end

  defp past_events?(events) do
    events != [] and
      Enum.all?(events, &(not is_nil(&1.date) and Date.compare(&1.date, Date.utc_today()) == :lt))
  end

  defp find_item(assigns, "hotel", id), do: Enum.find(assigns.hotels, &(to_string(&1.id) == id))

  defp find_item(assigns, "hidden_gem", id),
    do: Enum.find(assigns.hidden_gems, &(to_string(&1.id) == id))

  defp find_item(assigns, "car_hire", id),
    do: Enum.find(assigns.car_hires, &(to_string(&1.id) == id))

  defp find_item(assigns, "event", id), do: Enum.find(assigns.events, &(to_string(&1.id) == id))
  defp find_item(_assigns, _kind, _id), do: nil

  defp step_for(:hotels), do: :hotels
  defp step_for(:gems), do: :gems
  defp step_for(:car), do: :car
  defp step_for(:events), do: :events
  defp step_for(_action), do: :chyllz

  defp page_title_for(:hotels), do: "Premium Hotels · Chyllz"
  defp page_title_for(:gems), do: "Hidden Gems · Chyllz"
  defp page_title_for(:car), do: "Premium Car Hire · Chyllz"
  defp page_title_for(:events), do: "Upcoming Events · Chyllz"
  defp page_title_for(_step), do: "Chyllz · Hotels, Hidden Gems, Car Hire & Events"

  defp canonical_for(:hotels), do: XpressbusWeb.Endpoint.url() <> "/tour-packages/hotels"
  defp canonical_for(:gems), do: XpressbusWeb.Endpoint.url() <> "/our-packages/hidden-gems"
  defp canonical_for(:car), do: XpressbusWeb.Endpoint.url() <> "/tour-packages/car"
  defp canonical_for(:events), do: XpressbusWeb.Endpoint.url() <> "/tour-packages/events"
  defp canonical_for(_step), do: XpressbusWeb.Endpoint.url() <> "/tour-packages"

  defp chyllz_json_ld(step) do
    [
      XpressbusWeb.SEO.organization(),
      XpressbusWeb.SEO.breadcrumb([
        {"Home", XpressbusWeb.SEO.base_url() <> "/"},
        {"Chyllz", XpressbusWeb.SEO.base_url() <> "/tour-packages"},
        {page_title_for(step), canonical_for(step)}
      ])
    ]
  end

  defp normalize_search(nil), do: ""

  defp normalize_search(term) do
    term
    |> to_string()
    |> String.trim()
    |> String.slice(0, 80)
  end

  defp count_label(1, singular, _plural), do: "1 " <> singular
  defp count_label(count, _singular, plural), do: "#{count} " <> plural

  defp search_path(step, query) do
    path = step_path(step)
    search = normalize_search(query)

    if search == "" do
      path
    else
      path <> "?" <> URI.encode_query(%{"q" => search})
    end
  end

  defp step_path(:hotels), do: ~p"/tour-packages/hotels"
  defp step_path(:gems), do: ~p"/our-packages/hidden-gems"
  defp step_path(:car), do: ~p"/tour-packages/car"
  defp step_path(:events), do: ~p"/tour-packages/events"
  defp step_path(_step), do: ~p"/tour-packages"

  defp hero_title(:chyllz), do: "Find Your Perfect Stay with Chyllz"
  defp hero_title(:hotels), do: "Premium Hotels"
  defp hero_title(:gems), do: "Hidden Gems"
  defp hero_title(:car), do: "Premium Car Hire"
  defp hero_title(:events), do: "Upcoming Events"

  defp hero_subtitle(:chyllz),
    do: "Premium rooms, apartments, and staycations curated for the modern traveler."

  defp hero_subtitle(:hotels),
    do: "Curated luxury stays and boutique hotels for every budget."

  defp hero_subtitle(:gems),
    do: "Discover East Africa's best-kept secrets and off-the-beaten-path adventures."

  defp hero_subtitle(:car), do: "Reliable vehicles for self-drive or chauffeured regional travel."

  defp hero_subtitle(:events),
    do: "The most anticipated festivals, concerts, and cultural experiences in the region."

  defp search_placeholder(:hotels), do: "Where are you going?"
  defp search_placeholder(:gems), do: "Search a destination or experience"
  defp search_placeholder(:car), do: "Search a vehicle, type or town"
  defp search_placeholder(_step), do: "Search an event or town"

  defp empty_message(:hotels, ""),
    do: "Our hotel collection is being refreshed. Please check back shortly."

  defp empty_message(:gems, ""),
    do: "Our hidden gems collection is being refreshed. Please check back shortly."

  defp empty_message(:car, ""),
    do: "No vehicles are listed right now. Please check back shortly."

  defp empty_message(:events, ""),
    do: "No events are scheduled right now. Please check back shortly."

  defp empty_message(_step, query), do: "Nothing matched “#{query}”. Try a different search."

  defp hotel_image(hotel) do
    case List.first(hotel.images || []) do
      nil -> fallback_room_image(hotel.id)
      image -> normalize_image_path(image)
    end
  end

  defp gem_image(gem) do
    case List.first(gem.images || []) do
      nil -> nil
      image -> normalize_image_path(image)
    end
  end

  defp fallback_room_image(id) when is_binary(id) do
    Enum.at(@room_images, :erlang.phash2(id, length(@room_images)))
  end

  defp fallback_room_image(_id), do: hd(@room_images)

  defp normalize_image_path(path) when is_binary(path) do
    cond do
      String.starts_with?(path, ["http://", "https://", "/"]) -> path
      true -> "/images/" <> path
    end
  end

  defp normalize_image_path(_path), do: hd(@room_images)

  defp amenities_text(amenities) do
    case Enum.reject(amenities || [], &is_nil/1) do
      [] -> nil
      list -> list |> Enum.take(4) |> Enum.join(" · ")
    end
  end

  defp item_name(%{kind: "hotel", item: item}), do: item.name
  defp item_name(%{kind: "hidden_gem", item: item}), do: item.title
  defp item_name(%{kind: "car_hire", item: item}), do: item.car_name
  defp item_name(%{kind: "event", item: item}), do: item.title
  defp item_name(_selected), do: "Details"

  defp item_kind_label("hotel"), do: "Hotel"
  defp item_kind_label("hidden_gem"), do: "Hidden gem"
  defp item_kind_label("car_hire"), do: "Car hire"
  defp item_kind_label("event"), do: "Event"
  defp item_kind_label(_kind), do: "Chyllz"

  defp item_icon("hotel"), do: "hotel"
  defp item_icon("hidden_gem"), do: "explore"
  defp item_icon("car_hire"), do: "directions_car"
  defp item_icon("event"), do: "local_activity"
  defp item_icon(_kind), do: "travel_explore"

  defp item_details(%{kind: "hotel", item: hotel}) do
    compact([
      {"Location", hotel.location},
      {"Rating", hotel.rating && rating(hotel.rating)},
      {"Price", hotel.price_per_night && "KES #{money(hotel.price_per_night)} / night"},
      {"Amenities", amenities_text(hotel.amenities)}
    ])
  end

  defp item_details(%{kind: "hidden_gem", item: gem}) do
    compact([{"Location", gem.location}])
  end

  defp item_details(%{kind: "car_hire", item: car}) do
    compact([
      {"Vehicle type", car.type},
      {"Location", car.location},
      {"Price", car.price_per_day && "KES #{money(car.price_per_day)} / day"}
    ])
  end

  defp item_details(%{kind: "event", item: event}) do
    compact([
      {"Date", event.date && long_date(event.date)},
      {"Location", event.location}
    ])
  end

  defp item_details(_selected), do: []

  defp item_description(%{kind: "hotel", item: hotel}), do: hotel.description

  defp item_description(%{kind: "hidden_gem", item: gem}), do: gem.description

  defp item_description(%{kind: "car_hire", item: car}),
    do: "Self-drive or chauffeured hire of a #{car.type} in #{car.location || "Kenya"}."

  defp item_description(%{kind: "event", item: event}), do: event.description
  defp item_description(_selected), do: nil

  defp item_location(%{item: %{location: location}}) when is_binary(location) and location != "",
    do: location

  defp item_location(_selected), do: nil

  defp compact(pairs) do
    Enum.reject(pairs, fn {_label, value} -> is_nil(value) or value == "" end)
  end

  defp stay_error_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.map(fn {field, messages} ->
      "#{Phoenix.Naming.humanize(field)} #{Enum.join(messages, ", ")}"
    end)
    |> Enum.join(". ")
    |> case do
      "" -> "Check the reservation details and try again."
      message -> message
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-white text-slate-900">
        <.main_header step={@step} current_user={@current_user} />
        <main class="pt-[72px] md:pt-[80px]">
          <%= if @step == :chyllz do %>
            <.hub_hero counts={@counts} current_user={@current_user} />
            <div class="max-w-[1350px] mx-auto px-6 space-y-20 py-[58px]">
              <section id="hotels">
                <.section_heading
                  icon="hotel"
                  title="Premium Hotels"
                  subtitle="Curated luxury stays and boutique hotels for every budget."
                  link={step_path(:hotels)}
                  link_label="View All Hotels"
                />
                <%= if @hotels == [] do %>
                  <.empty_state id="catalogue-empty-hotels" message={empty_message(:hotels, "")} />
                <% else %>
                  <.hotel_grid hotels={@hotels} />
                <% end %>
              </section>

              <section id="hidden-gems">
                <.section_heading
                  icon="explore"
                  title="Hidden Gems"
                  subtitle="Discover East Africa's best-kept secrets and off-the-beaten-path adventures."
                  link={step_path(:gems)}
                  link_label="Explore All Gems"
                />
                <%= if @hidden_gems == [] do %>
                  <.empty_state id="catalogue-empty-gems" message={empty_message(:gems, "")} />
                <% else %>
                  <.gem_grid gems={@hidden_gems} />
                <% end %>
              </section>

              <section id="car-hire">
                <.section_heading
                  icon="directions_car"
                  title="Premium Car Hire"
                  subtitle="Reliable vehicles for self-drive or chauffeured regional travel."
                  link={step_path(:car)}
                  link_label="Book a Vehicle"
                />
                <%= if @car_hires == [] do %>
                  <.empty_state id="catalogue-empty-cars" message={empty_message(:car, "")} />
                <% else %>
                  <.car_grid cars={@car_hires} />
                <% end %>
              </section>

              <.events_section
                events={@events}
                events_are_past={@events_are_past}
                link={step_path(:events)}
                link_label="See All Events"
              />
            </div>
          <% else %>
            <.listing_hero step={@step} search={@search} />
            <div class="max-w-[1350px] mx-auto px-6 py-[58px]">
              <%= case @step do %>
                <% :hotels -> %>
                  <%= if @hotels == [] do %>
                    <.empty_state
                      message={empty_message(:hotels, @search)}
                      search={@search}
                    />
                  <% else %>
                    <p id="catalogue-result-count" class="text-sm font-bold text-slate-400 mb-8">
                      Showing {length(@hotels)} {if length(@hotels) == 1,
                        do: "hotel",
                        else: "hotels"}
                      <%= if @search != "" do %>
                        for “{@search}”
                      <% end %>
                    </p>
                    <.hotel_grid hotels={@hotels} />
                  <% end %>
                <% :gems -> %>
                  <%= if @hidden_gems == [] do %>
                    <.empty_state message={empty_message(:gems, @search)} search={@search} />
                  <% else %>
                    <p id="catalogue-result-count" class="text-sm font-bold text-slate-400 mb-8">
                      Showing {length(@hidden_gems)} {if length(@hidden_gems) == 1,
                        do: "destination",
                        else: "destinations"}
                      <%= if @search != "" do %>
                        for “{@search}”
                      <% end %>
                    </p>
                    <.gem_grid gems={@hidden_gems} />
                  <% end %>
                <% :car -> %>
                  <%= if @car_hires == [] do %>
                    <.empty_state message={empty_message(:car, @search)} search={@search} />
                  <% else %>
                    <p id="catalogue-result-count" class="text-sm font-bold text-slate-400 mb-8">
                      Showing {length(@car_hires)} {if length(@car_hires) == 1,
                        do: "vehicle",
                        else: "vehicles"}
                      <%= if @search != "" do %>
                        for “{@search}”
                      <% end %>
                    </p>
                    <.car_grid cars={@car_hires} />
                  <% end %>
                <% :events -> %>
                  <.events_section
                    events={@events}
                    events_are_past={@events_are_past}
                    variant={:page}
                    search={@search}
                  />
              <% end %>
            </div>
          <% end %>
        </main>
        <.main_footer footer_tab={@footer_tab} />
        <%= if @selected do %>
          <.catalogue_modal
            selected={@selected}
            current_user={@current_user}
            stay_error={@stay_error}
            stay_check_in={@stay_check_in}
            stay_check_out={@stay_check_out}
            stay_rooms={@stay_rooms}
            stay_guests={@stay_guests}
          />
        <% end %>
      </div>

      <.assistant_launcher open={@assistant.open} />
      <.assistant_panel
        open={@assistant.open}
        tab={@assistant.tab}
        thread={@assistant.threads[@assistant.tab] || []}
        pending={@assistant.pending}
        pending_tab={@assistant.pending_tab}
        input={@assistant.input}
        upload={@uploads.assistant_photo}
        caption={@assistant.caption}
        receipt_text={@assistant.receipt_text}
        expenses={@assistant.expenses}
        expense_total={TravelAssistant.expense_total_label(@assistant.expenses)}
        greeting={TravelAssistant.greeting(@assistant.tab)}
        suggestions={TravelAssistant.suggestions(@assistant.tab)}
        engine={@assistant_engine}
        ai_enabled={@assistant_ai_enabled}
        error={@assistant.error}
      />
    </Layouts.app>
    """
  end

  attr :counts, :map, required: true
  attr :current_user, :string, default: nil

  defp hub_hero(assigns) do
    ~H"""
    <section class="relative pt-20 pb-[200px] px-6 rounded-b-[4rem] md:rounded-b-[8rem] overflow-hidden bg-slate-950 text-white">
      <video
        id="chyllz-hero-video"
        autoplay
        muted
        loop
        playsinline
        preload="none"
        poster="/images/hero_bg-1024.webp"
        class="absolute inset-0 w-full h-full object-cover opacity-95"
        aria-hidden="true"
      >
        <source src="/images/hero_video.mp4" type="video/mp4" />
      </video>
      <div class="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black/40">
      </div>

      <div class="max-w-[1350px] mx-auto flex flex-col items-center justify-center relative z-10 text-center">
        <h1 class="text-4xl md:text-7xl font-black tracking-tighter mb-8 leading-tight">
          {hero_title(:chyllz)}
        </h1>

        <p class="text-xl md:text-2xl font-medium opacity-90 mb-8 max-w-2xl">
          {hero_subtitle(:chyllz)}
        </p>

        <p
          id="chyllz-catalogue-counts"
          class="text-xs font-black uppercase tracking-[0.3em] text-white/60 mb-12"
        >
          {count_label(@counts.hotels, "stay", "stays")} · {count_label(
            @counts.hidden_gems,
            "hidden gem",
            "hidden gems"
          )} · {count_label(@counts.car_hires, "vehicle", "vehicles")} · {count_label(
            @counts.events,
            "event",
            "events"
          )}
        </p>
        <%!-- Hub search: sends travellers to the hotel collection with the term applied --%>
        <form
          id="chyllz-hub-search-form"
          phx-submit="hub_search"
          class="w-full max-w-4xl bg-white p-4 rounded-[2.5rem] shadow-2xl flex flex-col md:flex-row items-center gap-4 text-slate-900"
        >
          <div class="flex-1 flex items-center gap-3 px-6 w-full">
            <span class="material-symbols-outlined text-orange-500">location_on</span>
            <input
              id="chyllz-hub-search-input"
              type="search"
              name="q"
              placeholder="Where are you going?"
              aria-label="Search hotels by destination"
              class="w-full py-4 font-bold outline-none"
            />
          </div>

          <button
            type="submit"
            class="bg-[#FF4C00] text-white px-10 py-4 rounded-full font-black hover:bg-[#E64400] transition shadow-lg shadow-orange-200 shrink-0"
          >
            Search Stays
          </button>
        </form>

        <button
          type="button"
          id="chyllz-ai-hero-cta"
          phx-click="assistant_open"
          class="mt-7 inline-flex items-center gap-2 rounded-full border border-white/25 bg-white/10 px-6 py-3 text-[10px] font-black uppercase tracking-widest text-white backdrop-blur transition-all hover:-translate-y-0.5 hover:bg-white hover:text-[#FF4C00]"
        >
          <.sparkle_icon class="h-4 w-4" /> Ask Chyllz AI
        </button>

        <%= if @current_user do %>
          <a
            href="/dashboard?tab=chyllz"
            id="chyllz-hub-account-link"
            class="mt-7 inline-flex items-center gap-2 rounded-full border border-white/25 bg-white/10 px-6 py-3 text-[10px] font-black uppercase tracking-widest text-white backdrop-blur transition-all hover:-translate-y-0.5 hover:bg-white hover:text-[#FF4C00]"
          >
            <span class="material-symbols-outlined !text-base" aria-hidden="true">person</span>
            My Chyllz account
          </a>
        <% end %>
      </div>
    </section>
    """
  end

  attr :step, :atom, required: true
  attr :search, :string, required: true

  defp listing_hero(assigns) do
    ~H"""
    <section class="relative pt-16 pb-16 px-6 rounded-b-[4rem] md:rounded-b-[8rem] overflow-hidden bg-gradient-to-br from-slate-950 via-slate-900 to-[#431407] text-white">
      <span
        class="material-symbols-outlined absolute -right-10 -top-10 text-white/5 !text-[22rem] pointer-events-none select-none"
        aria-hidden="true"
      >
        {item_icon(step_kind(@step))}
      </span>

      <div class="max-w-[1350px] mx-auto relative z-10">
        <nav class="flex items-center gap-2 text-[10px] font-black uppercase tracking-[0.25em] text-white/50 mb-8 flex-wrap">
          <.link navigate={~p"/"} class="hover:text-white transition">Home</.link> <span>/</span>
          <.link navigate={~p"/tour-packages"} class="hover:text-white transition">Chyllz</.link>
          <span>/</span> <span class="text-[#FF4C00]">{hero_title(@step)}</span>
        </nav>

        <h1 class="text-4xl md:text-6xl font-black tracking-tighter mb-4 leading-tight">
          {hero_title(@step)}
        </h1>

        <p class="text-lg md:text-xl font-medium text-white/80 max-w-2xl mb-10">
          {hero_subtitle(@step)}
        </p>

        <form
          id="catalogue-search-form"
          phx-submit="search"
          class="w-full max-w-2xl bg-white p-3 rounded-[2rem] shadow-2xl flex flex-col sm:flex-row items-center gap-3 text-slate-900"
        >
          <div class="flex-1 flex items-center gap-3 px-4 w-full">
            <span class="material-symbols-outlined text-orange-500">search</span>
            <input
              id="catalogue-search-input"
              type="search"
              name="q"
              value={@search}
              placeholder={search_placeholder(@step)}
              aria-label={search_placeholder(@step)}
              class="w-full py-3 font-bold outline-none"
            />
          </div>

          <div class="flex items-center gap-2 shrink-0 w-full sm:w-auto">
            <%= if @search != "" do %>
              <button
                type="button"
                phx-click="clear_search"
                class="px-5 py-3 rounded-full font-black text-xs uppercase tracking-widest text-slate-500 hover:text-slate-900 hover:bg-slate-100 transition"
              >
                Clear
              </button>
            <% end %>

            <button
              type="submit"
              class="bg-[#FF4C00] text-white px-8 py-3 rounded-full font-black hover:bg-[#E64400] transition shadow-lg shadow-orange-200"
            >
              Search
            </button>
          </div>
        </form>
      </div>
    </section>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :link, :string, default: nil
  attr :link_label, :string, default: nil

  defp section_heading(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-end mb-8">
      <div>
        <div class="flex items-center gap-3 mb-2">
          <span class="material-symbols-outlined text-[#FF4C00] !text-3xl">{@icon}</span>
          <h2 class="text-3xl md:text-4xl font-black tracking-tight text-slate-900">{@title}</h2>
        </div>

        <p class="text-slate-400 font-bold">{@subtitle}</p>
      </div>

      <%= if @link do %>
        <.link
          navigate={@link}
          class="text-[#FF4C00] font-black uppercase text-xs tracking-widest flex items-center gap-2 hover:underline transition-all hover:gap-3"
        >
          {@link_label} <span class="material-symbols-outlined !text-sm">arrow_forward</span>
        </.link>
      <% end %>
    </div>
    """
  end

  attr :hotels, :list, required: true

  defp hotel_grid(assigns) do
    ~H"""
    <div id="hotel-grid" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
      <%= for hotel <- @hotels do %>
        <.hotel_card hotel={hotel} />
      <% end %>
    </div>
    """
  end

  attr :hotel, :any, required: true

  defp hotel_card(assigns) do
    ~H"""
    <div class="group">
      <button
        type="button"
        id={"hotel-card-#{@hotel.id}"}
        phx-click="open_item"
        phx-value-kind="hotel"
        phx-value-id={@hotel.id}
        class="w-full text-left cursor-pointer"
        aria-label={"View details for #{@hotel.name}"}
      >
        <div class="aspect-[4/3] rounded-[2.5rem] overflow-hidden mb-6 relative shadow-lg bg-slate-100">
          <img
            src={hotel_image(@hotel)}
            alt={@hotel.name}
            loading="lazy"
            class="absolute inset-0 w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
            onerror="this.style.opacity='0'"
          />
          <div class="absolute top-6 right-6 bg-white/95 backdrop-blur-md px-5 py-2 rounded-full font-black text-xs shadow-xl border border-slate-50">
            KES {money(@hotel.price_per_night)}/night
          </div>
        </div>

        <h3 class="text-xl font-black text-slate-900 group-hover:text-[#FF4C00] transition-colors">
          {@hotel.name}
        </h3>

        <p class="text-sm font-bold text-slate-400 mt-1 flex items-center gap-2 flex-wrap">
          <%= if @hotel.rating do %>
            <span class="material-symbols-outlined !text-sm text-yellow-500">star</span> {rating(
              @hotel.rating
            )} <span>•</span>
          <% end %>
          <span>{@hotel.location}</span>
        </p>

        <%= if @hotel.description do %>
          <p class="text-xs font-bold text-slate-400 mt-2 line-clamp-2">{@hotel.description}</p>
        <% end %>
      </button>
    </div>
    """
  end

  attr :gems, :list, required: true

  defp gem_grid(assigns) do
    ~H"""
    <div id="gem-grid" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
      <%= for gem <- @gems do %>
        <.gem_card gem={gem} />
      <% end %>
    </div>
    """
  end

  attr :gem, :any, required: true

  defp gem_card(assigns) do
    ~H"""
    <button
      type="button"
      id={"gem-card-#{@gem.id}"}
      phx-click="open_item"
      phx-value-kind="hidden_gem"
      phx-value-id={@gem.id}
      class="relative rounded-[3rem] overflow-hidden group cursor-pointer aspect-square shadow-2xl text-left w-full"
      aria-label={"View details for #{@gem.title}"}
    >
      <%= case gem_image(@gem) do %>
        <% nil -> %>
          <div class="absolute inset-0 bg-gradient-to-br from-[#FF4C00] via-orange-600 to-slate-950">
          </div>

          <span
            class="material-symbols-outlined absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-white/20 !text-[10rem]"
            aria-hidden="true"
          >
            explore
          </span>
        <% image -> %>
          <img
            src={image}
            alt={@gem.title}
            loading="lazy"
            class="absolute inset-0 w-full h-full object-cover transition-transform duration-1000 group-hover:scale-110"
            onerror="this.style.opacity='0'"
          />
      <% end %>

      <div class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent"></div>

      <div class="absolute bottom-10 left-10 right-10">
        <div class="text-[11px] font-black uppercase tracking-[0.3em] text-yellow-400 mb-2">
          {@gem.location}
        </div>

        <h3 class="text-2xl font-black text-white leading-tight">{@gem.title}</h3>

        <%= if @gem.description do %>
          <p class="mt-3 text-xs font-bold text-white/70 line-clamp-2">{@gem.description}</p>
        <% end %>

        <div class="mt-4 flex items-center gap-2 text-white/80 font-bold text-xs group-hover:gap-4 transition-all">
          Read Story <span class="material-symbols-outlined !text-base">arrow_right_alt</span>
        </div>
      </div>
    </button>
    """
  end

  attr :cars, :list, required: true

  defp car_grid(assigns) do
    ~H"""
    <div id="car-grid" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
      <%= for car <- @cars do %>
        <.car_card car={car} />
      <% end %>
    </div>
    """
  end

  attr :car, :any, required: true

  defp car_card(assigns) do
    ~H"""
    <button
      type="button"
      id={"car-card-#{@car.id}"}
      phx-click="open_item"
      phx-value-kind="car_hire"
      phx-value-id={@car.id}
      class="bg-slate-50 rounded-[2rem] p-8 border border-slate-100 hover:border-orange-200 transition-all group cursor-pointer text-left w-full"
      aria-label={"View details for #{@car.car_name}"}
    >
      <div class="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-4">
        {@car.type}
      </div>

      <h3 class="text-xl font-black text-slate-900 mb-6">{@car.car_name}</h3>

      <div class="flex justify-between items-end">
        <div>
          <div class="text-[10px] font-bold text-slate-400 uppercase">From</div>

          <div class="text-lg font-black text-slate-900">
            KES {money(@car.price_per_day)}<span class="text-xs font-bold text-slate-400">/day</span>
          </div>
        </div>

        <div class="w-10 h-10 rounded-full bg-white flex items-center justify-center text-[#FF4C00] shadow-md group-hover:bg-[#FF4C00] group-hover:text-white transition-all">
          <span class="material-symbols-outlined !text-xl">arrow_outward</span>
        </div>
      </div>

      <%= if @car.location do %>
        <div class="mt-4 text-xs font-bold text-slate-400 flex items-center gap-1">
          <span class="material-symbols-outlined !text-sm">location_on</span>{@car.location}
        </div>
      <% end %>
    </button>
    """
  end

  attr :events, :list, required: true
  attr :events_are_past, :boolean, default: false
  attr :link, :string, default: nil
  attr :link_label, :string, default: nil
  attr :variant, :atom, default: :section
  attr :search, :string, default: ""

  defp events_section(assigns) do
    ~H"""
    <section
      id="events"
      class="bg-slate-900 rounded-[4rem] p-8 md:p-14 text-white relative overflow-hidden"
    >
      <div class="absolute top-0 right-0 w-96 h-96 bg-[#FF4C00]/20 rounded-full blur-[120px]"></div>

      <div class="relative z-10">
        <div class="flex flex-col md:flex-row justify-between items-center md:items-end gap-8 mb-12">
          <div class="text-center md:text-left">
            <div class="flex items-center justify-center md:justify-start gap-3 mb-2">
              <span class="material-symbols-outlined text-[#FF4C00] !text-3xl">local_activity</span>
              <h2 class="text-3xl md:text-4xl font-black tracking-tight text-white">
                {if @events_are_past, do: "Recently Held Events", else: "Upcoming Events"}
              </h2>
            </div>

            <p class="text-slate-400 font-bold">
              {if @events_are_past,
                do: "The most recent cultural experiences in the region.",
                else:
                  "The most anticipated festivals, concerts, and cultural experiences in the region."}
            </p>
          </div>

          <%= if @link do %>
            <.link
              navigate={@link}
              class="bg-[#FF4C00] text-white px-8 py-4 rounded-full font-black uppercase text-xs tracking-widest hover:bg-[#E64400] transition-all shadow-xl shadow-orange-950/40"
            >
              {@link_label}
            </.link>
          <% end %>
        </div>

        <%= if @events == [] do %>
          <div id="catalogue-empty-events" class="text-center py-10">
            <span class="material-symbols-outlined text-white/20 !text-5xl mb-4">event_busy</span>
            <p class="text-slate-300 font-bold">{empty_message(:events, @search)}</p>

            <%= if @search != "" do %>
              <button
                type="button"
                phx-click="clear_search"
                class="mt-6 text-[#FF4C00] font-black uppercase text-xs tracking-widest hover:underline"
              >
                Clear search
              </button>
            <% end %>
          </div>
        <% else %>
          <div
            id="event-grid"
            class="grid grid-cols-1 md:grid-cols-2 gap-8"
          >
            <%= for event <- @events do %>
              <.event_card event={event} />
            <% end %>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  attr :event, :any, required: true

  defp event_card(assigns) do
    ~H"""
    <button
      type="button"
      id={"event-card-#{@event.id}"}
      phx-click="open_item"
      phx-value-kind="event"
      phx-value-id={@event.id}
      class="flex gap-8 items-center group cursor-pointer border-b border-white/10 pb-12 last:border-0 last:pb-0 text-left w-full"
      aria-label={"View details for #{@event.title}"}
    >
      <div class="flex flex-col items-center justify-center w-24 h-24 rounded-3xl bg-white/5 border border-white/10 shrink-0 text-center">
        <div class="text-2xl font-black text-[#FF4C00]">
          {day_of_month(@event.date)}
        </div>

        <div class="text-[10px] font-black uppercase tracking-widest opacity-60">
          {month_abbr(@event.date)}
        </div>
      </div>

      <div class="flex-1">
        <h3 class="text-2xl md:text-3xl font-black group-hover:text-[#FF4C00] transition-colors">
          {@event.title}
        </h3>

        <div class="flex items-center gap-4 mt-2 text-slate-400 font-bold text-sm flex-wrap">
          <span class="flex items-center gap-1">
            <span class="material-symbols-outlined !text-sm text-[#FF4C00]">location_on</span> {@event.location}
          </span>

          <span class="flex items-center gap-1">
            <span class="material-symbols-outlined !text-sm text-[#FF4C00]">calendar_month</span> {short_date(
              @event.date
            )}
          </span>
        </div>

        <%= if @event.description do %>
          <p class="text-slate-400 font-bold text-sm mt-2 line-clamp-1">{@event.description}</p>
        <% end %>
      </div>

      <div class="w-12 h-12 rounded-full border border-white/20 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all group-hover:translate-x-2">
        <span class="material-symbols-outlined">arrow_forward</span>
      </div>
    </button>
    """
  end

  attr :message, :string, required: true
  attr :search, :string, default: ""
  attr :id, :string, default: "catalogue-empty"

  defp empty_state(assigns) do
    ~H"""
    <div
      id={@id}
      class="bg-slate-50 border border-dashed border-slate-200 rounded-[2.5rem] py-16 px-8 text-center"
    >
      <span class="material-symbols-outlined text-slate-300 !text-5xl mb-4">travel_explore</span>
      <p class="text-slate-500 font-bold">{@message}</p>

      <%= if @search != "" do %>
        <button
          type="button"
          phx-click="clear_search"
          class="mt-6 text-[#FF4C00] font-black uppercase text-xs tracking-widest hover:underline"
        >
          Clear search
        </button>
      <% end %>
    </div>
    """
  end

  attr :selected, :map, required: true
  attr :current_user, :any, default: nil
  attr :stay_error, :string, default: nil
  attr :stay_check_in, :string, default: ""
  attr :stay_check_out, :string, default: ""
  attr :stay_rooms, :string, default: "1"
  attr :stay_guests, :string, default: "1"

  defp catalogue_modal(assigns) do
    assigns = assign(assigns, :details, item_details(assigns.selected))

    ~H"""
    <div
      id="catalogue-modal"
      class="fixed inset-0 z-[70] flex items-end sm:items-center justify-center p-0 sm:p-6"
      phx-window-keydown="close_item"
      phx-key="escape"
      role="dialog"
      aria-modal="true"
      aria-labelledby="catalogue-modal-title"
    >
      <div class="absolute inset-0 bg-slate-950/70 backdrop-blur-sm" phx-click="close_item"></div>

      <div class="relative w-full sm:max-w-2xl bg-white rounded-t-[2.5rem] sm:rounded-[2.5rem] shadow-2xl overflow-hidden max-h-[92vh] overflow-y-auto">
        <div class="relative bg-gradient-to-br from-slate-950 via-slate-900 to-[#431407] px-8 py-10 text-white">
          <button
            type="button"
            id="catalogue-modal-close"
            phx-click="close_item"
            class="absolute top-6 right-6 w-10 h-10 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition"
            aria-label="Close details"
          >
            <span class="material-symbols-outlined">close</span>
          </button>

          <div class="flex items-center gap-3 text-[10px] font-black uppercase tracking-[0.3em] text-[#FF4C00] mb-4">
            <span class="material-symbols-outlined !text-base">{item_icon(@selected.kind)}</span> {item_kind_label(
              @selected.kind
            )}
          </div>

          <h2 id="catalogue-modal-title" class="text-3xl font-black tracking-tight pr-12">
            {item_name(@selected)}
          </h2>
        </div>

        <div class="p-8 space-y-6">
          <%= if @details != [] do %>
            <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <%= for {label, value} <- @details do %>
                <div class="bg-slate-50 rounded-2xl px-5 py-4">
                  <dt class="text-[10px] font-black uppercase tracking-widest text-slate-400">
                    {label}
                  </dt>

                  <dd class="text-sm font-black text-slate-900 mt-1">{value}</dd>
                </div>
              <% end %>
            </dl>
          <% end %>

          <%= if item_description(@selected) do %>
            <p class="text-slate-500 font-bold leading-relaxed">{item_description(@selected)}</p>
          <% end %>

          <%= if @selected.kind == "hotel" do %>
            <div
              id="stay-booking"
              class="rounded-[1.75rem] border border-orange-100 bg-orange-50/50 p-5"
            >
              <div class="flex items-center gap-2">
                <span class="material-symbols-outlined text-[#FF4C00]">event_available</span>
                <h3 class="text-sm font-black uppercase tracking-widest text-slate-900">
                  Reserve this stay
                </h3>
              </div>

              <p class="mt-1 text-xs font-bold leading-relaxed text-slate-500">
                Send a reservation request to {item_name(@selected)}. No payment is taken here.
              </p>

              <%= if @stay_error do %>
                <p
                  id="stay-booking-error"
                  class="mt-3 rounded-xl bg-red-50 px-3 py-2 text-xs font-bold text-red-600"
                >
                  {@stay_error}
                </p>
              <% end %>

              <%= if @current_user do %>
                <form id="stay-booking-form" phx-submit="book_stay" class="mt-4 space-y-3">
                  <div class="grid gap-3 sm:grid-cols-2">
                    <label class="block text-left">
                      <span class="mb-1 block text-[10px] font-black uppercase tracking-widest text-slate-500">
                        Check-in
                      </span>
                      <input
                        id="stay-check-in"
                        type="date"
                        name="check_in"
                        value={@stay_check_in}
                        min={Date.to_iso8601(Date.utc_today())}
                        required
                        class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm font-bold text-slate-700 outline-none focus:border-[#FF4C00]"
                      />
                    </label>

                    <label class="block text-left">
                      <span class="mb-1 block text-[10px] font-black uppercase tracking-widest text-slate-500">
                        Check-out
                      </span>
                      <input
                        id="stay-check-out"
                        type="date"
                        name="check_out"
                        value={@stay_check_out}
                        min={@stay_check_in}
                        required
                        class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm font-bold text-slate-700 outline-none focus:border-[#FF4C00]"
                      />
                    </label>
                  </div>

                  <div class="grid gap-3 sm:grid-cols-2">
                    <label class="block text-left">
                      <span class="mb-1 block text-[10px] font-black uppercase tracking-widest text-slate-500">
                        Rooms
                      </span>
                      <input
                        id="stay-rooms"
                        type="number"
                        name="rooms"
                        min="1"
                        max="10"
                        value={@stay_rooms}
                        required
                        class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm font-bold text-slate-700 outline-none focus:border-[#FF4C00]"
                      />
                    </label>

                    <label class="block text-left">
                      <span class="mb-1 block text-[10px] font-black uppercase tracking-widest text-slate-500">
                        Guests
                      </span>
                      <input
                        id="stay-guests"
                        type="number"
                        name="guests"
                        min="1"
                        max="20"
                        value={@stay_guests}
                        required
                        class="w-full rounded-xl border border-slate-200 bg-white px-3 py-2.5 text-sm font-bold text-slate-700 outline-none focus:border-[#FF4C00]"
                      />
                    </label>
                  </div>

                  <button
                    id="stay-booking-submit"
                    type="submit"
                    class="w-full rounded-full bg-[#FF4C00] px-6 py-3.5 text-[10px] font-black uppercase tracking-widest text-white shadow-lg shadow-orange-200 transition hover:bg-[#E64400]"
                  >
                    Request reservation
                  </button>
                </form>
              <% else %>
                <.link
                  id="stay-booking-login"
                  navigate={~p"/user/login"}
                  class="mt-4 flex items-center justify-center rounded-full bg-[#FF4C00] px-6 py-3.5 text-[10px] font-black uppercase tracking-widest text-white shadow-lg shadow-orange-200 transition hover:bg-[#E64400]"
                >
                  Sign in to reserve
                </.link>
              <% end %>
            </div>
          <% end %>

          <div class="flex flex-col sm:flex-row gap-3 pt-2">
            <%= if location = item_location(@selected) do %>
              <.link
                id="catalogue-modal-cta"
                navigate={book_path(location)}
                class="flex-1 text-center bg-[#FF4C00] text-white px-8 py-4 rounded-full font-black uppercase text-xs tracking-widest hover:bg-[#E64400] transition shadow-lg shadow-orange-200"
              >
                Find buses to {location}
              </.link>
            <% else %>
              <.link
                id="catalogue-modal-cta"
                navigate={~p"/"}
                class="flex-1 text-center bg-[#FF4C00] text-white px-8 py-4 rounded-full font-black uppercase text-xs tracking-widest hover:bg-[#E64400] transition shadow-lg shadow-orange-200"
              >
                Book a Bus Trip
              </.link>
            <% end %>

            <button
              type="button"
              phx-click="close_item"
              class="px-8 py-4 rounded-full font-black uppercase text-xs tracking-widest text-slate-500 hover:bg-slate-100 transition"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp book_path(location) when is_binary(location) and location != "" do
    ~p"/?#{[to: location]}"
  end

  defp book_path(_location), do: ~p"/"

  # Maps the page step to the catalogue kind used by the shared icon helpers.
  defp step_kind(:hotels), do: "hotel"
  defp step_kind(:gems), do: "hidden_gem"
  defp step_kind(:car), do: "car_hire"
  defp step_kind(:events), do: "event"
  defp step_kind(_step), do: "hotel"
end
