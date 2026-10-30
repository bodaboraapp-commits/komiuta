defmodule XpressbusWeb.BookingLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents
  alias Xpressbus.Bookings.{Bus, Scraper}
  alias Xpressbus.Tickets
  alias Xpressbus.Repo
  alias Xpressbus.Cities
  alias Xpressbus.Routes
  alias Xpressbus.DropPickPoints
  alias Xpressbus.Accounts
  alias Xpressbus.Integrations
  alias Xpressbus.Payments
  import Ecto.Query
  require Logger

  # --- Lifecycle & Initialization ---

  @impl true
  def mount(_params, session, socket) do
    Logger.info("Mounting BookingLive. Action: #{socket.assigns.live_action}")
    departure_date = Date.utc_today()
    departure_date_str = Date.to_string(departure_date)
    return_date = Date.add(departure_date, 28)
    return_date_str = Date.to_string(return_date)
    current_user = session["user_id"]

    # Parallelize initial data fetching for better load performance
    tasks = [
      Task.async(fn ->
        Cities.list_cities() |> Enum.filter(& &1.active) |> Enum.sort_by(& &1.name)
      end),
      Task.async(fn -> Routes.list_active_route_locations() end),
      Task.async(fn -> Xpressbus.BusOperators.list_active_bus_operators() end),
      Task.async(fn ->
        Integrations.list_integrations()
        |> Enum.filter(& &1.active)
        |> Enum.map(& &1.provider)
        |> Enum.filter(fn provider -> provider in ["mpesa", "flutterwave", "paystack"] end)
      end)
    ]

    [cities, city_names, partners, active_integrations] = Task.await_many(tasks)

    # Pre-index city names for faster lookup
    city_names_indexed = Enum.map(city_names, &String.downcase/1)
    cities_map = Enum.zip(city_names_indexed, city_names) |> Enum.into(%{})

    default_payment_method =
      if active_integrations != [], do: List.first(active_integrations), else: "mpesa"

    {:ok,
     socket
     |> assign(:page_title, "Komiuta Bus Booking")
     |> assign(:step, :search)
     |> assign(:current_user, current_user)
     |> assign(:ticket_last4, nil)
     |> assign(:cities, cities)
     |> assign(:city_names, city_names)
     |> assign(:cities_map, cities_map)
     |> assign(:partners, partners)
     |> assign(:active_integrations, active_integrations)
     |> assign(:from, "")
     |> assign(:to, "")
     |> assign(:from_suggestions, [])
     |> assign(:to_suggestions, [])
     |> assign(:date, departure_date_str)
     |> assign(:return_date, return_date_str)
     |> assign(:date_parts, parse_date_parts(departure_date_str))
     |> assign(
       :search_form,
       to_form(%{
         "from" => "",
         "to" => "",
         "date" => departure_date_str,
         "return_date" => return_date_str
       })
     )
     |> assign(:buses, [])
     |> assign(:selected_bus, nil)
     |> assign(:seat_drawer_open, false)
     |> assign(:stops_drawer_open, false)
     |> assign(:selected_seats, [])
     |> assign(:selected_operators, [])
     |> assign(:selected_departures, [])
     |> assign(:selected_seat_types, [])
     |> assign(:selected_amenities, [])
     |> assign(:loading, false)
     |> assign(:pickup_stop, "Main Terminal")
     |> assign(:dropoff_stop, "Main Terminal")
     |> assign(:pickup_points, [])
     |> assign(:dropoff_points, [])
     |> assign(:payment_method, default_payment_method)
     |> assign(:footer_tab, "about")
     |> assign(
       :passenger_form,
       to_form(
         %{
           "passengers" => %{},
           "payment_email" => "",
           "payment_name" => "",
           "payment_phone" => "",
           "payer_is_passenger" => true,
           "agreed" => false
         },
         as: :passenger
       )
     )
     |> assign(:date_range, [])
     |> assign(:seat_layout, generate_seat_layout([]))
     |> assign(:live_stats, %{
       customers: 630_000,
       buses: 310,
       routes: 200,
       tickets: 2_250_000
     })
     |> assign(:coupon_code, "")
     |> assign(:subscribe_form, to_form(%{"email" => ""}))
     |> assign(:applied_coupon, nil)
     |> assign(:discount_amount, 0)
     |> assign(:total_price, 0)
     |> assign(:final_price, 0)
     |> assign(:available_operators, [])
     |> assign(:available_seat_types, [])
     |> assign(:buses_map, %{})
     |> assign(:pwa_qr, pwa_qr())
     |> stream(:buses, [])}
  end

  # The app-download section shows a locally generated QR pointing at the
  # installable web app (PWA). Scanning opens Komiuta in the phone browser,
  # where the user can install it / add it to the home screen.
  defp pwa_qr do
    XpressbusWeb.QRCode.svg(XpressbusWeb.Endpoint.url() <> "/?source=qr_app_section",
      aria_label: "Scan to open the Komiuta app"
    )
  end

  @impl true
  def handle_params(params, _uri, socket) do
    Logger.info("handle_params: action=#{socket.assigns.live_action}, params=#{inspect(params)}")

    socket =
      socket
      |> maybe_start_stats_timer()
      |> assign(:seat_drawer_open, false)
      |> assign(:stops_drawer_open, false)
      # Ensure from/to are preserved or set from params
      |> assign(:from, Map.get(params, "from", socket.assigns.from || ""))
      |> assign(:to, Map.get(params, "to", socket.assigns.to || ""))

    case socket.assigns.live_action do
      :index ->
        {:noreply, assign(socket, :step, :search)}

      :results ->
        handle_results_params(params, socket)

      :passenger_details ->
        bus_id = params["bus_id"]
        seats_str = params["seats"] || ""
        selected_seats = String.split(seats_str, ",", trim: true)

        if bus_id do
          # Industrial Restoration: Ensure bus data and tiered seat layout are synced
          bus = restore_bus(socket, bus_id)

          # Only initialize form if it's a fresh visit or the bus changed
          is_new_bus =
            is_nil(socket.assigns.selected_bus) ||
              to_string(socket.assigns.selected_bus.id) != to_string(bus_id)

          socket =
            if is_new_bus or
                 Enum.empty?(socket.assigns.passenger_form.params["passengers"] || %{}) do
              # Pull from DB if user is logged in
              db_user =
                if socket.assigns.current_user, do: Accounts.get_user(socket.assigns.current_user)

              # Split names for first passenger
              [first, last] =
                case db_user do
                  %{name: name} when is_binary(name) and name != "" ->
                    case String.split(name, " ", parts: 2) do
                      [f, l] -> [f, l]
                      [f] -> [f, ""]
                      _ -> ["", ""]
                    end

                  _ ->
                    ["", ""]
                end

              passengers =
                selected_seats
                |> Enum.with_index()
                |> Enum.into(%{}, fn {seat, idx} ->
                  # Pre-fill first passenger with DB user details
                  if idx == 0 and db_user do
                    {seat,
                     %{
                       "firstname" => first,
                       "lastname" => last,
                       "phone" => db_user.phone || "",
                       "id_number" => "",
                       "nationality" => "Kenyan"
                     }}
                  else
                    {seat,
                     %{
                       "firstname" => "",
                       "lastname" => "",
                       "phone" => "",
                       "id_number" => "",
                       "nationality" => "Kenyan"
                     }}
                  end
                end)

              form_data = %{
                "passengers" => passengers,
                "payment_email" => if(db_user, do: db_user.email, else: ""),
                "payment_name" => if(db_user, do: db_user.name, else: ""),
                "payment_phone" => if(db_user, do: db_user.phone, else: ""),
                "payer_is_passenger" => "true",
                "agreed" => "false"
              }

              assign(socket, :passenger_form, to_form(form_data, as: :passenger))
            else
              socket
            end

          {:noreply,
           socket
           |> assign(:selected_bus, bus)
           |> assign(:seat_layout, generate_seat_layout(Map.get(bus, :occupied_seats, [])))
           |> assign(:selected_seats, selected_seats)
           |> assign(:step, :passenger_info)
           |> assign(:from, Map.get(params, "from", socket.assigns.from))
           |> assign(:to, Map.get(params, "to", socket.assigns.to))
           |> update_pricing()}
        else
          if socket.assigns[:selected_bus] do
            {:noreply, assign(socket, :step, :passenger_info)}
          else
            Logger.warning("Passenger details reached without selected_bus, redirecting home.")
            {:noreply, push_navigate(socket, to: ~p"/")}
          end
        end

      :review_and_pay ->
        bus_id = params["bus_id"]
        seats_str = params["seats"] || ""
        selected_seats = String.split(seats_str, ",", trim: true)

        if bus_id do
          # Industrial Restoration: Ensure bus data and tiered seat layout are synced
          bus = restore_bus(socket, bus_id)

          # SAFETY CHECK: If passenger details are missing (e.g. refresh), redirect back
          current_form_params = socket.assigns.passenger_form.params || %{}

          # Strictly check for a non-empty phone number and presence of passengers
          phone =
            Map.get(current_form_params, "payment_phone") ||
              Map.get(current_form_params, :payment_phone) || ""

          passengers =
            Map.get(current_form_params, "passengers") ||
              Map.get(current_form_params, :passengers) || %{}

          has_details =
            (is_binary(phone) and String.trim(phone) != "") or
              not Enum.empty?(passengers)

          if not has_details do
            Logger.warning(
              "Review page reached without details, redirecting back to passenger info"
            )

            dynamic_id =
              params["id"] || Base.encode64(:crypto.strong_rand_bytes(18), padding: false)

            from = Map.get(params, "from", socket.assigns.from)
            to = Map.get(params, "to", socket.assigns.to)

            {:noreply,
             socket
             |> put_flash(:info, "Please confirm your details before paying.")
             |> push_patch(
               to:
                 ~p"/passenger-details/#{dynamic_id}?bus_id=#{bus_id}&seats=#{seats_str}&from=#{from}&to=#{to}"
             )}
          else
            {:noreply,
             socket
             |> assign(:selected_bus, bus)
             |> assign(:seat_layout, generate_seat_layout(Map.get(bus, :occupied_seats, [])))
             |> assign(:selected_seats, selected_seats)
             |> assign(:step, :review_and_pay)
             |> assign(:from, Map.get(params, "from", socket.assigns.from))
             |> assign(:to, Map.get(params, "to", socket.assigns.to))
             |> update_pricing()}
          end
        else
          if socket.assigns[:selected_bus] do
            {:noreply, assign(socket, :step, :review_and_pay)}
          else
            Logger.warning("Review and pay reached without selected_bus, redirecting home.")
            {:noreply, push_navigate(socket, to: ~p"/")}
          end
        end

      _ ->
        {:noreply, socket}
    end
  end

  # --- Info Handlers ---

  @impl true
  def handle_info(:tick_stats, socket) do
    # Slow down stats updates to reduce unneeded re-renders
    stats = socket.assigns.live_stats

    new_stats = %{
      stats
      | tickets: stats.tickets + Enum.random(1..2),
        customers: stats.customers + if(Enum.random(1..15) > 13, do: 1, else: 0)
    }

    Process.send_after(self(), :tick_stats, Enum.random(15000..30000))
    {:noreply, assign(socket, :live_stats, new_stats)}
  end

  @impl true
  def handle_info({:select_bus, bus_id}, socket) do
    select_bus(bus_id, socket)
  end

  # --- Event Handlers: Search & Location ---

  @impl true
  def handle_event("search", params, socket) do
    from = Map.get(params, "from", "")
    to = Map.get(params, "to", "")
    date = Map.get(params, "date", socket.assigns.date)
    return_date = Map.get(params, "return_date", socket.assigns.return_date)

    if from != "" and to != "" do
      {:noreply, push_search_url(socket, from, to, date, return_date)}
    else
      {:noreply, put_flash(socket, :error, "Please select both from and to cities.")}
    end
  end

  def handle_event("search_input", params, socket) do
    new_from = Map.get(params, "from", socket.assigns.from)
    new_to = Map.get(params, "to", socket.assigns.to)
    from_changed? = new_from != socket.assigns.from
    to_changed? = new_to != socket.assigns.to

    # Only compute if significantly changed and not just whitespace
    from_suggestions =
      if from_changed? and String.trim(new_from) != "" do
        compute_suggestions(new_from, socket.assigns.city_names)
      else
        if String.trim(new_from) == "", do: [], else: socket.assigns.from_suggestions
      end

    to_suggestions =
      if to_changed? and String.trim(new_to) != "" do
        compute_suggestions(new_to, socket.assigns.city_names)
      else
        if String.trim(new_to) == "", do: [], else: socket.assigns.to_suggestions
      end

    # Fast return if only date changed and not cities
    search_form =
      to_form(%{
        "from" => new_from,
        "to" => new_to,
        "date" => Map.get(params, "date", socket.assigns.date),
        "return_date" => Map.get(params, "return_date", socket.assigns.return_date)
      })

    {:noreply,
     socket
     |> assign(:from_suggestions, from_suggestions)
     |> assign(:to_suggestions, to_suggestions)
     |> assign(:from, new_from)
     |> assign(:to, new_to)
     |> assign(:date, Map.get(params, "date", socket.assigns.date))
     |> assign(:date_parts, parse_date_parts(Map.get(params, "date", socket.assigns.date)))
     |> assign(:return_date, Map.get(params, "return_date", socket.assigns.return_date))
     |> assign(:search_form, search_form)}
  end

  def handle_event("select_city", %{"field" => field, "city" => city}, socket) do
    current_from = if field == "from", do: city, else: socket.assigns.from
    current_to = if field == "to", do: city, else: socket.assigns.to

    search_form =
      to_form(%{
        "from" => current_from,
        "to" => current_to,
        "date" => socket.assigns.date,
        "return_date" => socket.assigns.return_date
      })

    {:noreply,
     socket
     |> assign(:from, current_from)
     |> assign(:to, current_to)
     |> assign(:from_suggestions, [])
     |> assign(:to_suggestions, [])
     |> assign(:search_form, search_form)}
  end

  def handle_event("clear_input", %{"field" => field}, socket) do
    current_from = if field == "from", do: "", else: socket.assigns.from
    current_to = if field == "to", do: "", else: socket.assigns.to

    search_form =
      to_form(%{
        "from" => current_from,
        "to" => current_to,
        "date" => socket.assigns.date,
        "return_date" => socket.assigns.return_date
      })

    {:noreply,
     socket
     |> assign(:from, current_from)
     |> assign(:to, current_to)
     |> assign(:from_suggestions, [])
     |> assign(:to_suggestions, [])
     |> assign(:search_form, search_form)}
  end

  def handle_event("clear_suggestions", _, socket) do
    {:noreply,
     socket
     |> assign(:from_suggestions, [])
     |> assign(:to_suggestions, [])}
  end

  def handle_event("swap_cities", _params, socket) do
    new_from = socket.assigns.to
    new_to = socket.assigns.from
    date = socket.assigns.date
    return_date = socket.assigns.return_date

    if socket.assigns.step == :results do
      # Re-run the search with swapped origin/destination so the bus list refreshes.
      handle_search_params(socket, new_from, new_to, date, return_date)
    else
      search_form =
        to_form(%{
          "from" => new_from,
          "to" => new_to,
          "date" => date,
          "return_date" => return_date
        })

      {:noreply,
       socket
       |> assign(:from, new_from)
       |> assign(:to, new_to)
       |> assign(:from_suggestions, [])
       |> assign(:to_suggestions, [])
       |> assign(:search_form, search_form)}
    end
  end

  # Aliases for different swap UI triggers
  def handle_event("swap_locations", params, socket),
    do: handle_event("swap_cities", params, socket)

  def handle_event("swap_route", _params, socket) do
    {:noreply,
     push_search_url(
       socket,
       socket.assigns.to,
       socket.assigns.from,
       socket.assigns.date,
       socket.assigns.return_date
     )}
  end

  def handle_event("change_date", %{"date" => date}, socket) do
    {:noreply,
     push_search_url(
       socket,
       socket.assigns.from,
       socket.assigns.to,
       date,
       socket.assigns.return_date
     )}
  end

  def handle_event("change_date_part", %{"part" => part, "value" => value}, socket)
      when part in ["day", "month", "year"] do
    with {int_value, ""} <- Integer.parse(to_string(value)) do
      new_parts = Map.put(socket.assigns.date_parts, String.to_existing_atom(part), int_value)

      case Date.from_iso8601(date_parts_to_string(new_parts)) do
        {:ok, valid_date} ->
          if Date.compare(valid_date, Date.utc_today()) != :lt do
            search_form =
              to_form(%{
                "from" => socket.assigns.from,
                "to" => socket.assigns.to,
                "date" => date_parts_to_string(new_parts),
                "return_date" => socket.assigns.return_date
              })

            {:noreply,
             socket
             |> assign(:date_parts, new_parts)
             |> assign(:date, date_parts_to_string(new_parts))
             |> assign(:search_form, search_form)}
          else
            {:noreply, socket}
          end

        _ ->
          {:noreply, socket}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("change_date_part", _params, socket), do: {:noreply, socket}

  # --- Event Handlers: Filtering ---

  def handle_event("toggle_operator", %{"operator" => operator}, socket) do
    operator = String.downcase(operator)

    selected_operators =
      if operator in socket.assigns.selected_operators do
        List.delete(socket.assigns.selected_operators, operator)
      else
        [operator | socket.assigns.selected_operators]
      end

    buses =
      filter_buses(
        socket.assigns.buses,
        selected_operators,
        socket.assigns.selected_departures,
        socket.assigns.selected_seat_types,
        socket.assigns.selected_amenities
      )

    {:noreply,
     socket
     |> assign(:selected_operators, selected_operators)
     |> stream(:buses, buses, reset: true)}
  end

  def handle_event("toggle_departure", %{"period" => period}, socket) do
    selected_departures = toggle_filter(socket.assigns.selected_departures, period)

    buses =
      filter_buses(
        socket.assigns.buses,
        socket.assigns.selected_operators,
        selected_departures,
        socket.assigns.selected_seat_types,
        socket.assigns.selected_amenities
      )

    {:noreply,
     socket
     |> assign(:selected_departures, selected_departures)
     |> stream(:buses, buses, reset: true)}
  end

  def handle_event("toggle_seat_type", %{"seat_type" => seat_type}, socket) do
    selected_seat_types = toggle_filter(socket.assigns.selected_seat_types, seat_type)

    buses =
      filter_buses(
        socket.assigns.buses,
        socket.assigns.selected_operators,
        socket.assigns.selected_departures,
        selected_seat_types,
        socket.assigns.selected_amenities
      )

    {:noreply,
     socket
     |> assign(:selected_seat_types, selected_seat_types)
     |> stream(:buses, buses, reset: true)}
  end

  def handle_event("toggle_amenity", %{"amenity" => amenity}, socket) do
    selected_amenities = toggle_filter(socket.assigns.selected_amenities, amenity)

    buses =
      filter_buses(
        socket.assigns.buses,
        socket.assigns.selected_operators,
        socket.assigns.selected_departures,
        socket.assigns.selected_seat_types,
        selected_amenities
      )

    {:noreply,
     socket
     |> assign(:selected_amenities, selected_amenities)
     |> stream(:buses, buses, reset: true)}
  end

  def handle_event("reset_filters", _params, socket) do
    buses = filter_buses(socket.assigns.buses, [], [], [], [])

    {:noreply,
     socket
     |> assign(:selected_operators, [])
     |> assign(:selected_departures, [])
     |> assign(:selected_seat_types, [])
     |> assign(:selected_amenities, [])
     |> stream(:buses, buses, reset: true)}
  end

  # --- Event Handlers: Selection ---

  def handle_event("select_bus", %{"id" => bus_id}, socket) do
    Logger.info("SELECT BUS EVENT. ID: #{bus_id}")
    select_bus(bus_id, socket)
  end

  def handle_event("close_seat_picker", _params, socket) do
    {:noreply, assign(socket, :seat_drawer_open, false)}
  end

  def handle_event("toggle_seat", %{"seat" => seat}, socket) do
    Logger.info("Toggling seat: #{seat}")
    selected = socket.assigns.selected_seats

    new_selected =
      cond do
        seat in socket.assigns.selected_bus.occupied_seats -> selected
        seat_number(seat) > socket.assigns.selected_bus.total_seats -> selected
        seat in selected -> List.delete(selected, seat)
        true -> [seat | selected]
      end

    Logger.info("New selected seats: #{inspect(new_selected)}")

    {:noreply,
     socket
     |> assign(:selected_seats, new_selected)
     |> update_pricing()}
  end

  def handle_event("confirm_seats", _params, socket) do
    Logger.info(
      "CONFIRM SEATS triggered. Selected seats: #{inspect(socket.assigns.selected_seats)}"
    )

    bus_id = socket.assigns.selected_bus.id
    seats = Enum.join(socket.assigns.selected_seats, ",")
    from = socket.assigns.from
    to = socket.assigns.to

    # Generate a simple unique ID for testing
    dynamic_id = "TRANS-#{:os.system_time(:millisecond)}"

    {:noreply,
     socket
     |> push_navigate(
       to:
         ~p"/passenger-details/#{dynamic_id}?bus_id=#{bus_id}&seats=#{seats}&from=#{from}&to=#{to}"
     )}
  end

  def handle_event("select_stop", %{"type" => "pickup", "name" => name}, socket) do
    {:noreply, assign(socket, :pickup_stop, name)}
  end

  # --- Event Handlers: Checkout & Payment ---

  def handle_event("validate_passengers", params, socket) do
    # Extract params under "passenger" key if present, otherwise use raw params
    passenger_params = Map.get(params, "passenger", params)

    # Ensure checkbox values are handled correctly
    passenger_params =
      passenger_params
      |> Map.put_new("agreed", "false")
      |> Map.put_new("payer_is_passenger", "false")

    {:noreply, assign(socket, passenger_form: to_form(passenger_params, as: :passenger))}
  end

  def handle_event("save_passenger", params, socket) do
    # Extract params under "passenger" key if present, otherwise use raw params
    passenger_params = Map.get(params, "passenger", params)

    # Ensure checkbox values are handled correctly
    passenger_params =
      passenger_params
      |> Map.put_new("agreed", "false")
      |> Map.put_new("payer_is_passenger", "false")

    if passenger_params["agreed"] == "true" do
      do_save_passenger(passenger_params, socket)
    else
      {:noreply,
       socket
       |> assign(:passenger_form, to_form(passenger_params, as: :passenger))
       |> put_flash(:error, "You must agree to the Terms and Conditions before proceeding.")}
    end
  end

  def handle_event("select_payment_method", %{"method" => method}, socket) do
    {:noreply, assign(socket, :payment_method, method)}
  end

  def handle_event("apply_coupon", %{"code" => code}, socket) do
    code = String.trim(code) |> String.upcase()

    cond do
      code == "" ->
        {:noreply,
         socket
         |> assign(:applied_coupon, nil)
         |> assign(:discount_amount, 0)
         |> update_pricing()
         |> put_flash(:error, "Please enter a coupon code.")}

      socket.assigns.selected_bus == nil or socket.assigns.selected_seats == [] ->
        {:noreply,
         socket
         |> assign(:applied_coupon, nil)
         |> assign(:discount_amount, 0)
         |> update_pricing()
         |> put_flash(:error, "Please select a bus and seats before applying a coupon.")}

      true ->
        apply_coupon_to_total(socket, code)
    end
  end

  def handle_event("pay", _params, socket) do
    # Industrial Debug: Trace the form state
    form = socket.assigns.passenger_form
    passenger_form_params = form.params || %{}

    # ELITE DEFENSIVE EXTRACTION
    # If params is empty, we might be looking at a form that hasn't been "changed" yet
    # but has data in its source. Or the data is in the socket's internal state.
    passenger_phone =
      Map.get(passenger_form_params, "payment_phone") ||
        Map.get(passenger_form_params, :payment_phone) ||
        if(is_map(form.data),
          do: Map.get(form.data, "payment_phone") || Map.get(form.data, :payment_phone)
        ) ||
        ""

    passenger_name =
      Map.get(passenger_form_params, "payment_name") ||
        Map.get(passenger_form_params, :payment_name) ||
        if(is_map(form.data),
          do: Map.get(form.data, "payment_name") || Map.get(form.data, :payment_name)
        ) ||
        "Traveler"

    payment_email =
      Map.get(passenger_form_params, "payment_email") ||
        Map.get(passenger_form_params, :payment_email) ||
        if(is_map(form.data),
          do: Map.get(form.data, "payment_email") || Map.get(form.data, :payment_email)
        ) ||
        ""

    Logger.info("PAYMENT_JOURNEY_START: User initiated checkout", %{
      method: socket.assigns.payment_method,
      amount: socket.assigns.final_price,
      extracted_phone: passenger_phone,
      extracted_name: passenger_name
    })

    bus = socket.assigns.selected_bus
    amount = socket.assigns.final_price
    payment_method = socket.assigns.payment_method || "mpesa"

    cond do
      is_nil(bus) or length(socket.assigns.selected_seats) == 0 ->
        Logger.warning("Checkout blocked: No bus or seats selected")

        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Please select a bus and seat(s) before paying.")}

      payment_method == "mpesa" and String.trim(to_string(passenger_phone)) == "" ->
        Logger.warning(
          "Checkout blocked: M-Pesa requires a phone number. Full Form Params: #{inspect(passenger_form_params)}"
        )

        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "A valid phone number is required for M-Pesa payment.")}

      socket.assigns.from == "" or socket.assigns.to == "" ->
        Logger.warning("Checkout blocked: Route missing", %{
          from: socket.assigns.from,
          to: socket.assigns.to
        })

        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Please complete your route search (from/to) before paying.")}

      true ->
        ticket_id =
          "TKT-" <>
            (:crypto.strong_rand_bytes(4)
             |> Base.url_encode64(padding: false)
             |> String.replace("_", "-"))

        bus_id =
          if is_struct(bus, Xpressbus.Bookings.Bus) and is_integer(bus.id), do: bus.id, else: nil

        user_id = current_user_id(socket.assigns.current_user)

        trip_type =
          if socket.assigns.return_date && !String.match?(socket.assigns.return_date, ~r/^null$/) do
            "Round Trip"
          else
            "One Way"
          end

        booking_context = %{
          ticket_id: ticket_id,
          from: socket.assigns.from,
          to: socket.assigns.to,
          travel_date: socket.assigns.date,
          departure: Map.get(bus, :departure),
          arrival: Map.get(bus, :arrival),
          company: Map.get(bus, :company, "Komiuta Bus"),
          price: "KSH #{amount}",
          seats: socket.assigns.selected_seats,
          passenger_name: passenger_name,
          passenger_phone: passenger_phone,
          payment_email: payment_email,
          payment_method: payment_method,
          bus_id: bus_id,
          amount: amount,
          user_id: user_id,
          type: trip_type,
          # INDUSTRIAL INITIAL STATE
          status: "pending"
        }

        Logger.info("Initiating async payment task", %{
          method: payment_method,
          ticket_id: ticket_id,
          email: payment_email
        })

        {:noreply,
         socket
         |> assign(:loading, true)
         |> assign(:ticket_id, ticket_id)
         |> assign(:ticket_last4, phone_last4(booking_context.passenger_phone))
         |> assign(:payment_method, payment_method)
         |> start_async(:payment, fn ->
           Logger.info("Async task started for :payment")
           process_payment(payment_method, booking_context)
         end)}
    end
  end

  # --- Event Handlers: Miscellaneous ---

  def handle_event("subscribe", %{"email" => email}, socket) do
    case Accounts.create_subscriber(%{email: email, source: "Homepage"}) do
      {:ok, _subscriber} ->
        {:noreply, put_flash(socket, :info, "Thank you for subscribing! Check your inbox soon.")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Unable to subscribe. You might already be on our list.")}
    end
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  def handle_event("back_to_search", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("app_coming_soon", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :info,
       "The Komiuta app is coming soon. Book here on the web in the meantime."
     )}
  end

  # --- Async Handlers ---

  @impl true
  def handle_async(:bus_search, result, socket) do
    case result do
      {:ok, buses} ->
        # Pre-calculate expensive values once
        buses =
          Enum.map(buses, fn bus ->
            Map.merge(bus, %{
              period: departure_period(bus.departure),
              numeric_price: parse_unit_price(bus)
            })
          end)

        operators = unique_operators(buses)
        seat_types = unique_seat_types(buses)
        buses_map = Enum.into(buses, %{}, fn b -> {to_string(b.id), b} end)

        {:noreply,
         socket
         |> assign(:buses, buses)
         |> assign(:buses_map, buses_map)
         |> assign(:available_operators, operators)
         |> assign(:available_seat_types, seat_types)
         |> assign(:loading, false)
         |> stream(:buses, buses, reset: true)}

      {:exit, _reason} ->
        {:noreply, assign(socket, :loading, false)}
    end
  end

  @impl true
  def handle_async(:payment, result, socket) do
    Logger.info("PAYMENT_JOURNEY_ASYNC_RETURN: Result received", %{
      ticket_id: socket.assigns[:ticket_id],
      status: elem(result, 0)
    })

    case result do
      {:ok, {:ok, provider_response, ticket}} ->
        # Robustly handle authorization URL from provider response
        auth_url =
          case provider_response do
            %{authorization_url: url} -> url
            %{"authorization_url" => url} -> url
            _ -> nil
          end

        Logger.info("Payment processing result details", %{
          provider: socket.assigns.payment_method,
          ticket_id: ticket.ticket_id,
          has_auth_url: not is_nil(auth_url)
        })

        if auth_url do
          Logger.info("REDIRECTING TO EXTERNAL PAYMENT PAGE", %{url: auth_url})

          {:noreply,
           socket
           |> assign(:loading, false)
           |> assign(:ticket_id, ticket.ticket_id)
           |> assign(:ticket_last4, phone_last4(ticket.passenger_phone))
           |> redirect(external: auth_url)}
        else
          Logger.info("Push payment/direct processing required - Navigating to processing page")

          {:noreply,
           socket
           |> assign(:loading, false)
           |> assign(:ticket_id, ticket.ticket_id)
           |> assign(:ticket_last4, phone_last4(ticket.passenger_phone))
           |> push_navigate(
             to:
               ~p"/payment-processing/#{ticket.ticket_id}?method=#{socket.assigns.payment_method}"
           )}
        end

      {:ok, {:error, reason}} ->
        Logger.error("Payment initiation error", %{error: reason})

        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Payment failed: #{reason}")
         |> assign(step: :review_and_pay)}

      {:exit, reason} ->
        Logger.error("Payment process crashed", %{reason: inspect(reason)})

        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Payment process encountered a critical error.")
         |> assign(step: :review_and_pay)}
    end
  end

  # --- Private Functions ---

  # Helper logic for search/results
  defp begin_search(socket, from, to, date, return_date) do
    search_form =
      to_form(%{"from" => from, "to" => to, "date" => date, "return_date" => return_date})

    # Parallelize data fetching for better responsiveness
    tasks = [
      Task.async(fn -> list_buses(from, to, date) end),
      Task.async(fn -> DropPickPoints.list_by_city(from) end),
      Task.async(fn -> DropPickPoints.list_by_city(to) end)
    ]

    [buses_from_db, pickup_points, dropoff_points] = Task.await_many(tasks)

    # Pre-calculate for speed
    buses_from_db =
      Enum.map(buses_from_db, fn bus ->
        Map.merge(bus, %{
          period: departure_period(bus.departure),
          numeric_price: parse_unit_price(bus)
        })
      end)

    # Pre-index for search efficiency
    buses_map = Enum.into(buses_from_db, %{}, fn b -> {to_string(b.id), b} end)
    operators = unique_operators(buses_from_db)
    seat_types = unique_seat_types(buses_from_db)

    pickup_default =
      case List.first(pickup_points) do
        %Xpressbus.DropPickPoints.DropPickPoint{name: name} -> name
        %{name: name} -> name
        _ -> "#{from} Main Terminal"
      end

    dropoff_default =
      case List.first(dropoff_points) do
        %Xpressbus.DropPickPoints.DropPickPoint{name: name} -> name
        %{name: name} -> name
        _ -> "#{to} Main Terminal"
      end

    socket =
      socket
      |> assign(:step, :results)
      |> assign(:from, from)
      |> assign(:to, to)
      |> assign(:date, date)
      |> assign(:date_parts, parse_date_parts(date))
      |> assign(:return_date, return_date)
      |> assign(:search_form, search_form)
      |> assign(:buses, buses_from_db)
      |> assign(:buses_map, buses_map)
      |> assign(:available_operators, operators)
      |> assign(:available_seat_types, seat_types)
      |> assign(:pickup_points, pickup_points)
      |> assign(:dropoff_points, dropoff_points)
      |> assign(:pickup_stop, pickup_default)
      |> assign(:dropoff_stop, dropoff_default)
      |> assign(:selected_operators, [])
      |> assign(:selected_departures, [])
      |> assign(:selected_seat_types, [])
      |> assign(:seat_drawer_open, false)
      |> assign(:loading, true)
      |> assign(:date_range, generate_date_range(date))
      |> stream(:buses, buses_from_db, reset: true)

    start_async(socket, :bus_search, fn -> Scraper.search(from, to, date) end)
  end

  defp list_buses(from, to, date) do
    case Date.from_iso8601(to_string(date)) do
      {:ok, date_obj} ->
        Repo.all(
          from(b in Bus,
            left_join: operator in assoc(b, :bus_operator),
            where: b.from == ^from and b.to == ^to and b.travel_date == ^date_obj,
            # Buses submitted by partners stay hidden until the operator has
            # been approved (operator.active == true).
            where: is_nil(operator.id) or operator.active == true,
            order_by: [asc: b.departure],
            preload: [:bus_operator]
          )
        )

      _ ->
        []
    end
  end

  defp handle_search_params(socket, from, to, date, return_date) do
    same_search? =
      socket.assigns[:step] == :results and
        socket.assigns[:from] == from and
        socket.assigns[:to] == to and
        socket.assigns[:date] == date and
        socket.assigns[:return_date] == return_date

    if same_search? do
      {:noreply, socket}
    else
      {:noreply, begin_search(socket, from, to, date, return_date)}
    end
  end

  defp handle_results_params(
         %{"fromCityName" => from, "toCityName" => to, "onward" => date} = params,
         socket
       ) do
    return_date = Map.get(params, "return", "")

    date =
      case Date.from_iso8601(date) do
        {:ok, _} -> date
        _ -> Date.to_string(Date.utc_today())
      end

    return_date =
      if return_date == "" do
        Date.to_string(Date.add(Date.from_iso8601!(date), 28))
      else
        return_date
      end

    handle_search_params(socket, from, to, date, return_date)
  end

  defp handle_results_params(%{"from" => from, "to" => to, "date" => date}, socket) do
    case Date.from_iso8601(to_string(date)) do
      {:ok, valid_date} ->
        handle_search_params(
          socket,
          from,
          to,
          Date.to_string(valid_date),
          Date.to_string(Date.add(valid_date, 28))
        )

      _ ->
        {:noreply, assign(socket, :step, :search)}
    end
  end

  defp handle_results_params(%{"route" => [route]}, socket) do
    case String.split(route, "-to-", parts: 2) do
      [from, to] ->
        handle_search_params(
          socket,
          URI.decode(from),
          URI.decode(to),
          Date.to_string(Date.utc_today()),
          Date.to_string(Date.add(Date.utc_today(), 28))
        )

      _ ->
        {:noreply, assign(socket, :step, :search)}
    end
  end

  defp handle_results_params(%{"route" => route}, socket) when is_binary(route) do
    handle_results_params(%{"route" => [route]}, socket)
  end

  defp handle_results_params(_params, socket) do
    {:noreply, assign(socket, :step, :search)}
  end

  defp select_bus(bus_id, socket) do
    bus = restore_bus(socket, bus_id)

    {:noreply,
     socket
     |> assign(:selected_bus, bus)
     |> assign(:seat_drawer_open, true)
     |> assign(:seat_layout, generate_seat_layout(Map.get(bus, :occupied_seats, [])))
     |> assign(:selected_seats, [])
     |> update_pricing()}
  end

  defp restore_bus(socket, bus_id) do
    # Industrial Restoration: Priority lookup to ensure pricing consistency
    # Try DB fetch to ensure we have the high-fidelity record including tiered pricing
    Map.get(socket.assigns.buses_map || %{}, to_string(bus_id)) ||
      Enum.find(socket.assigns.buses, fn b -> to_string(b.id) == bus_id end) ||
      fetch_bus_from_db(bus_id) ||
      %{
        id: bus_id,
        company: "Komiuta Bus",
        price: 1500,
        vip_price: "2300",
        business_price: "2000",
        first_class_price: "1800",
        occupied_seats: [],
        departure: "08:00 AM",
        arrival: "04:00 PM",
        duration: "8h",
        seats: 40
      }
  end

  defp fetch_bus_from_db(bus_id) do
    case Integer.parse(to_string(bus_id)) do
      {id, _} -> Repo.get(Bus, id) |> Repo.preload([:bus_operator])
      _ -> nil
    end
  end

  defp maybe_start_stats_timer(socket) do
    if connected?(socket) and not Map.get(socket.assigns, :stats_timer_started, false) do
      Process.send_after(self(), :tick_stats, 1000)
      assign(socket, :stats_timer_started, true)
    else
      socket
    end
  end

  # Helper logic for pricing/coupons
  defp update_pricing(socket) do
    bus = socket.assigns.selected_bus
    seats = socket.assigns.selected_seats
    coupon = socket.assigns.applied_coupon

    if bus do
      # Calculate total based on individual seat types
      total_price =
        seats
        |> Enum.map(fn seat_id ->
          # Find seat type in layout
          type = find_seat_type(socket.assigns.seat_layout, seat_id)
          get_price_for_type(bus, type)
        end)
        |> Enum.sum()

      discount_amount = if coupon, do: calculate_discount(coupon, total_price), else: 0
      final_price = max(0, total_price - discount_amount)

      socket
      |> assign(:total_price, total_price)
      |> assign(:discount_amount, discount_amount)
      |> assign(:final_price, final_price)
    else
      socket
      |> assign(:total_price, 0)
      |> assign(:discount_amount, 0)
      |> assign(:final_price, 0)
    end
  end

  defp find_seat_type(layout, seat_id) do
    layout
    |> List.flatten()
    |> Enum.find(fn
      %{id: ^seat_id} -> true
      _ -> false
    end)
    |> case do
      %{type: type} -> type
      _ -> :normal
    end
  end

  defp get_price_for_type(bus, type) do
    case type do
      :first_class -> parse_price_value(Map.get(bus, :first_class_price), 1800)
      :vip -> parse_price_value(Map.get(bus, :vip_price), 2300)
      :business -> parse_price_value(Map.get(bus, :business_price), 2000)
      _ -> parse_price_value(Map.get(bus, :price), 1500)
    end
  end

  defp parse_price_value(value, default) do
    case value do
      nil ->
        default

      v when is_integer(v) ->
        v

      v when is_binary(v) ->
        numeric_str = String.replace(v, ~r/[^0-9.]/, "")

        case Float.parse(numeric_str) do
          {val, _} -> round(val)
          :error -> default
        end

      _ ->
        default
    end
  end

  defp calculate_discount(coupon, total) do
    case coupon.type do
      "fixed" ->
        Decimal.round(coupon.value, 0) |> Decimal.to_integer()

      "percentage" ->
        val = total * (Decimal.to_float(coupon.value) / 100.0)
        max_discount = Decimal.to_float(coupon.max_discount)

        if max_discount > 0 && val > max_discount do
          coupon.max_discount |> Decimal.round(0) |> Decimal.to_integer()
        else
          round(val)
        end

      _ ->
        0
    end
  end

  defp parse_unit_price(bus) do
    case Map.get(bus, :price, "1500") do
      price when is_binary(price) ->
        numeric_str = String.replace(price, ~r/[^0-9.]/, "")

        case Float.parse(numeric_str) do
          {val, _} -> round(val)
          :error -> 1500
        end

      price when is_integer(price) ->
        price

      _ ->
        1500
    end
  end

  defp apply_coupon_to_total(socket, code) do
    bus = socket.assigns.selected_bus

    # Correct calculation using tiered pricing
    total_base =
      socket.assigns.selected_seats
      |> Enum.map(fn seat_id ->
        type = find_seat_type(socket.assigns.seat_layout, seat_id)
        get_price_for_type(bus, type)
      end)
      |> Enum.sum()

    case Xpressbus.Coupons.get_coupon_by_code(code) do
      nil ->
        reset_coupon(socket, "Invalid or expired coupon code.")

      coupon ->
        cond do
          not coupon.active ->
            reset_coupon(socket, "This coupon is currently inactive.")

          expired?(coupon) ->
            reset_coupon(socket, "This coupon has expired.")

          usage_limit_reached?(coupon) ->
            reset_coupon(socket, "Coupon usage limit reached.")

          total_base < Decimal.to_float(coupon.min_amount || 0) ->
            reset_coupon(
              socket,
              "Minimum amount for this coupon is Ksh #{coupon.min_amount}"
            )

          true ->
            discount = calculate_discount(coupon, total_base)

            {:noreply,
             socket
             |> assign(:applied_coupon, coupon)
             |> assign(:discount_amount, discount)
             |> assign(:coupon_code, code)
             |> update_pricing()
             |> put_flash(:info, "Coupon applied! You saved Ksh #{discount}")}
        end
    end
  end

  defp reset_coupon(socket, message) do
    {:noreply,
     socket
     |> assign(:applied_coupon, nil)
     |> assign(:discount_amount, 0)
     |> update_pricing()
     |> put_flash(:error, message)}
  end

  defp expired?(coupon) do
    case coupon.expiry_date do
      %Date{} = date -> Date.compare(date, Date.utc_today()) == :lt
      nil -> false
    end
  end

  defp usage_limit_reached?(coupon) do
    case coupon.usage_limit do
      nil -> false
      limit -> (coupon.usage_count || 0) >= limit
    end
  end

  # Helper logic for payments
  defp do_save_passenger(passenger_params, socket) do
    Logger.info("Entering do_save_passenger", %{params: inspect(passenger_params)})
    bus = socket.assigns.selected_bus

    if is_nil(bus) or length(socket.assigns.selected_seats) == 0 do
      Logger.warning("do_save_passenger aborted: bus or seats missing")

      {:noreply,
       socket
       |> assign(:loading, false)
       |> put_flash(:error, "Please select a bus and seat(s) before paying.")}
    else
      # Generate dynamic ID (Base64) - longer
      dynamic_id = Base.encode64(:crypto.strong_rand_bytes(18), padding: false)
      bus_id = bus.id
      seats = Enum.join(socket.assigns.selected_seats, ",")
      from = socket.assigns.from
      to = socket.assigns.to

      {:noreply,
       socket
       |> assign(:passenger_form, to_form(passenger_params, as: :passenger))
       |> push_patch(
         to:
           ~p"/review-and-pay/#{dynamic_id}?bus_id=#{bus_id}&seats=#{seats}&from=#{from}&to=#{to}"
       )}
    end
  end

  defp process_payment(payment_method, booking_context) do
    Logger.info("PAYMENT_JOURNEY_STEP: Starting process_payment", %{
      method: payment_method,
      ticket_id: booking_context.ticket_id
    })

    payment_attrs = %{
      amount: booking_context.amount,
      currency: "KES",
      # REQUIRED for Paystack/Flutterwave
      email: booking_context.payment_email,
      reference: booking_context.ticket_id,
      phone_number: booking_context.passenger_phone,
      ticket_id: booking_context.ticket_id,
      passenger_name: booking_context.passenger_name,
      booking_context: booking_context
    }

    result =
      case Payments.initiate_payment(payment_method, payment_attrs) do
        {:ok, provider_response} ->
          Logger.info("Payment initiated successfully", %{
            provider: payment_method,
            ticket_id: booking_context.ticket_id
          })

          # Robustly handle authorization URL from provider response
          auth_url = Map.get(provider_response, :authorization_url)

          if is_binary(auth_url) and auth_url != "" do
            Logger.info("Payment checkout URL prepared - returning success with URL")
            fake_ticket = %Tickets.Ticket{ticket_id: booking_context.ticket_id}
            {:ok, provider_response, fake_ticket}
          else
            Logger.info("No authorization URL found - attempting direct ticket creation")

            case Tickets.create_ticket(booking_context) do
              {:ok, ticket} ->
                Logger.info("Ticket created for direct processing", ticket_id: ticket.ticket_id)
                {:ok, provider_response, ticket}

              {:error, changeset} ->
                Logger.error("Failed to create ticket", %{
                  ticket_id: booking_context.ticket_id,
                  errors: inspect(changeset.errors)
                })

                {:error, "Booking failed: #{inspect(changeset.errors)}"}
            end
          end

        {:error, reason} ->
          Logger.error("Payment initiation failed", %{
            error: reason,
            ticket_id: booking_context.ticket_id
          })

          {:error, reason}
      end

    Logger.info("process_payment finished", %{
      ticket_id: booking_context.ticket_id,
      result_status: elem(result, 0)
    })

    result
  end

  defp current_user_id(nil), do: nil

  defp current_user_id(current_user) when is_binary(current_user) do
    user =
      cond do
        String.match?(
          current_user,
          ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
        ) ->
          Accounts.get_user(current_user)

        true ->
          Accounts.get_user_by_phone(current_user)
      end

    if user, do: user.id, else: nil
  end

  defp current_user_id(current_user) when is_integer(current_user) do
    case Accounts.get_user(current_user) do
      nil -> nil
      user -> user.id
    end
  end

  defp current_user_id(_), do: nil

  # Helper logic for filtering
  defp toggle_filter(filters, value) do
    if value in filters, do: List.delete(filters, value), else: [value | filters]
  end

  defp filter_buses(
         buses,
         selected_operators,
         selected_departures,
         selected_seat_types,
         selected_amenities
       ) do
    Enum.filter(buses, fn bus ->
      operator_matches?(bus, selected_operators) and
        departure_matches?(bus, selected_departures) and
        seat_type_matches?(bus, selected_seat_types) and
        amenity_matches?(bus, selected_amenities)
    end)
  end

  defp operator_matches?(_bus, []), do: true

  defp operator_matches?(bus, selected_operators) do
    Enum.any?(selected_operators, &(&1 == String.downcase(bus.company)))
  end

  defp departure_matches?(_bus, []), do: true

  defp departure_matches?(bus, selected_departures) do
    period = Map.get(bus, :period) || departure_period(bus.departure)
    period in selected_departures
  end

  defp departure_period(departure) do
    cond do
      match = Regex.run(~r/^(\d{1,2}):\d{2}\s*(AM|PM)/i, departure || "") ->
        [_, hour, meridiem] = match
        hour = String.to_integer(hour) |> rem(12)
        hour = if String.upcase(meridiem) == "PM", do: hour + 12, else: hour
        period_for_hour(hour)

      match = Regex.run(~r/^(\d{1,2}):\d{2}$/, departure || "") ->
        [_, hour] = match
        period_for_hour(String.to_integer(hour))

      true ->
        "other"
    end
  end

  defp period_for_hour(hour) do
    cond do
      hour >= 6 and hour < 12 -> "morning"
      hour >= 12 and hour < 18 -> "afternoon"
      hour >= 18 -> "evening"
      true -> "other"
    end
  end

  defp seat_type_matches?(_bus, []), do: true

  defp seat_type_matches?(bus, selected_seat_types) do
    Enum.any?(selected_seat_types, &(&1 in (bus.seat_types || [])))
  end

  defp amenity_matches?(_bus, []), do: true

  defp amenity_matches?(bus, selected_amenities) do
    Enum.all?(selected_amenities, &(&1 in (bus.amenities || [])))
  end

  defp unique_operators(buses) do
    buses |> Enum.map(& &1.company) |> Enum.uniq() |> Enum.sort()
  end

  defp unique_seat_types(buses) do
    buses |> Enum.flat_map(&(&1.seat_types || [])) |> Enum.uniq() |> Enum.sort()
  end

  defp passenger_info(form, seat_id) do
    sid_str = to_string(seat_id)

    # Industrial Search: Scan params, data, and source for the passenger map
    # Maps from form submissions usually have string keys, but internally might use atoms
    sources = [form.params, form.data, form.source] |> Enum.filter(&is_map/1)

    Enum.find_value(sources, %{}, fn src ->
      passengers = Map.get(src, "passengers") || Map.get(src, :passengers)

      if is_map(passengers) do
        # Try finding by string ID first (form standard), then by original type
        Map.get(passengers, sid_str) || Map.get(passengers, seat_id)
      end
    end) || %{}
  end

  # Helper logic for formatting/rendering
  defp parse_date_parts(nil), do: %{day: 1, month: 1, year: Date.utc_today().year}

  defp parse_date_parts(date_str) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, %Date{day: d, month: m, year: y}} -> %{day: d, month: m, year: y}
      _ -> %{day: 1, month: 1, year: Date.utc_today().year}
    end
  end

  defp parse_date_parts(_), do: %{day: 1, month: 1, year: Date.utc_today().year}

  defp date_parts_to_string(%{day: d, month: m, year: y}) do
    "#{y}-#{String.pad_leading(to_string(m), 2, "0")}-#{String.pad_leading(to_string(d), 2, "0")}"
  end

  defp generate_date_range(center_date_str) do
    today = Date.utc_today()

    case Date.from_iso8601(center_date_str) do
      {:ok, center_date} ->
        0..6
        |> Enum.map(fn offset ->
          date = Date.add(today, offset)

          %{
            date: Date.to_string(date),
            day_label: Calendar.strftime(date, "%A, %-d %b"),
            month_label: Calendar.strftime(date, "%b"),
            is_past: false,
            is_today: Date.compare(date, today) == :eq,
            is_selected: Date.compare(date, center_date) == :eq
          }
        end)

      _ ->
        []
    end
  end

  defp generate_seat_layout(occupied_seats) do
    [
      [s("1", :first_class, occupied_seats), nil, nil, :driver],
      [
        s("2", :first_class, occupied_seats),
        s("3", :first_class, occupied_seats),
        nil,
        s("4", :first_class, occupied_seats)
      ],
      [
        s("5", :vip, occupied_seats),
        s("6", :vip, occupied_seats),
        nil,
        s("7", :vip, occupied_seats)
      ],
      [
        s("8", :vip, occupied_seats),
        s("9", :vip, occupied_seats),
        nil,
        s("10", :vip, occupied_seats)
      ],
      [
        s("11", :business, occupied_seats),
        s("12", :business, occupied_seats),
        nil,
        s("13", :business, occupied_seats)
      ],
      [
        s("14", :business, occupied_seats),
        s("15", :business, occupied_seats),
        nil,
        s("16", :business, occupied_seats)
      ],
      [
        s("17", :normal, occupied_seats),
        s("18", :normal, occupied_seats),
        s("19", :normal, occupied_seats),
        s("20", :normal, occupied_seats)
      ],
      [
        s("21", :normal, occupied_seats),
        s("22", :normal, occupied_seats),
        s("23", :normal, occupied_seats),
        s("24", :normal, occupied_seats)
      ],
      [
        s("25", :normal, occupied_seats),
        s("26", :normal, occupied_seats),
        s("27", :normal, occupied_seats),
        s("28", :normal, occupied_seats)
      ],
      [
        s("29", :normal, occupied_seats),
        s("30", :normal, occupied_seats),
        s("31", :normal, occupied_seats),
        s("32", :normal, occupied_seats)
      ],
      [
        s("33", :normal, occupied_seats),
        s("34", :normal, occupied_seats),
        s("35", :normal, occupied_seats),
        s("36", :normal, occupied_seats)
      ],
      [
        s("37", :normal, occupied_seats),
        s("38", :normal, occupied_seats),
        s("39", :normal, occupied_seats),
        s("40", :normal, occupied_seats)
      ]
    ]
  end

  defp s(id, type, occupied_seats) do
    status = if id in occupied_seats, do: :occupied, else: :available
    %{id: id, type: type, status: status}
  end

  defp seat_number(seat) do
    case Integer.parse(seat) do
      {number, _} -> number
      :error -> 0
    end
  end

  defp push_search_url(socket, from, to, date, return_date) do
    route = URI.encode("#{from}-to-#{to}", &URI.char_unreserved?/1)

    query =
      URI.encode_query(%{
        "fromCityName" => from,
        "toCityName" => to,
        "onward" => date,
        "return" => return_date
      })

    push_navigate(socket, to: "/buses/" <> route <> "?" <> query)
  end

  defp compute_suggestions(query, city_names) do
    q = String.downcase(query) |> String.trim()

    if byte_size(q) >= 2 do
      {prefixes, others} =
        Enum.split_with(city_names, &String.starts_with?(String.downcase(&1), q))

      (prefixes ++ Enum.filter(others, &String.contains?(String.downcase(&1), q))) |> Enum.take(8)
    else
      []
    end
  end

  defp initials_color(name) do
    colors = [
      "bg-slate-900",
      "bg-orange-500",
      "bg-emerald-600",
      "bg-blue-600",
      "bg-purple-600",
      "bg-pink-600",
      "bg-amber-600",
      "bg-indigo-600",
      "bg-rose-600",
      "bg-cyan-600"
    ]

    index = :erlang.phash2(name, length(colors))
    Enum.at(colors, index)
  end

  defp render_seat(%{seat: :driver} = assigns) do
    ~H"""
    <div class="w-9 h-9 flex items-center justify-center text-slate-200" title="Driver">
      <span class="material-symbols-outlined !text-xl">drive_eta</span>
    </div>
    """
  end

  defp render_seat(%{seat: nil} = assigns) do
    ~H"""
    <div class="w-9 h-9"></div>
    """
  end

  defp render_seat(assigns) do
    is_selected = assigns.seat.id in assigns.selected
    is_occupied = assigns.seat.status == :occupied

    assigns =
      assigns
      |> assign(:is_selected, is_selected)
      |> assign(:is_occupied, is_occupied)

    ~H"""
    <button
      type="button"
      phx-click={if not @is_occupied, do: "toggle_seat"}
      phx-value-seat={@seat.id}
      disabled={@is_occupied}
      class={[
        "w-9 h-9 rounded-lg flex items-center justify-center text-[10px] font-black transition-all",
        @is_occupied && "bg-slate-900 text-slate-700 cursor-not-allowed",
        @is_selected && "bg-[#FF4C00] text-white shadow-lg shadow-orange-100 scale-110 relative z-10",
        !@is_occupied && !@is_selected &&
          [
            "bg-white border-2 text-slate-400 hover:border-[#FF4C00] hover:text-[#FF4C00] hover:bg-orange-50/50",
            case @seat.type do
              :first_class -> "border-amber-400"
              :vip -> "border-orange-300"
              :business -> "border-indigo-300"
              :normal -> "border-slate-100"
              _ -> "border-slate-100"
            end
          ]
      ]}
      title={
        if(@is_occupied,
          do: "Occupied",
          else: "#{String.capitalize(to_string(@seat.type))} Seat #{@seat.id}"
        )
      }
    >
      {@seat.id}
    </button>
    """
  end

  defp phone_last4(nil), do: ""

  defp phone_last4(phone) do
    digits = phone |> to_string() |> String.replace(~r/[^0-9]/, "")
    if byte_size(digits) >= 4, do: String.slice(digits, -4, 4), else: ""
  end
end
