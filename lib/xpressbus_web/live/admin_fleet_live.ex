defmodule XpressbusWeb.AdminFleetLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents
  alias Xpressbus.{Buses, BusOperators, Cities}
  require Logger

  def mount(_params, session, socket) do
    admin_id = session["admin_id"]

    if admin_id do
      page = 1
      page_size = 10
      total_count = Buses.count_buses()
      operators = BusOperators.list_active_bus_operators()

      cities =
        Cities.list_cities() |> Enum.filter(& &1.active) |> Enum.map(& &1.name) |> Enum.sort()

      {:ok,
       socket
       |> assign(:page_title, "Fleet Management")
       |> assign(:active_tab, "fleet")
       |> assign(:page, page)
       |> assign(:page_size, page_size)
       |> assign(:total_count, total_count)
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, true)
       |> assign(:chyllz_expanded, true)
       |> assign(:settings_expanded, true)
       |> assign(:buses, Buses.paginate_buses(page, page_size))
       |> assign(:operators, operators)
       |> assign(:cities, cities)
       |> assign(:show_modal, false)
       |> assign(:editing_bus, nil)
       |> assign(:search_query, "")
       |> assign(:error, nil)}
    else
      {:ok,
       socket
       |> assign(:page_title, "Fleet Management")
       |> Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def render(assigns) do
    XpressbusWeb.AdminFleetLive.render_template(assigns)
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = String.to_integer(page)
    page_size = socket.assigns.page_size

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:buses, Buses.paginate_buses(page, page_size))}
  end

  def handle_event("open_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_bus, nil)
     |> assign(:error, nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:editing_bus, nil)
     |> assign(:error, nil)}
  end

  def handle_event("save_bus", %{"bus" => bus_params}, socket) do
    # Convert empty strings to nil where appropriate
    bus_params = sanitize_params(bus_params)

    case socket.assigns.editing_bus do
      nil ->
        case Buses.create_bus(bus_params) do
          {:ok, _bus} ->
            {:noreply,
             socket
             |> put_flash(:success, "Bus added to fleet successfully")
             |> assign(:show_modal, false)
             |> assign(
               :buses,
               Buses.paginate_buses(socket.assigns.page, socket.assigns.page_size)
             )
             |> assign(:total_count, Buses.count_buses())}

          {:error, changeset} ->
            Logger.error("Failed to add bus", errors: inspect(changeset.errors))
            {:noreply, assign(socket, :error, "Failed to add bus. Please check all fields.")}
        end

      bus ->
        case Buses.update_bus(bus, bus_params) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:success, "Bus updated successfully")
             |> assign(:show_modal, false)
             |> assign(:editing_bus, nil)
             |> assign(
               :buses,
               Buses.paginate_buses(socket.assigns.page, socket.assigns.page_size)
             )}

          {:error, _changeset} ->
            {:noreply, assign(socket, :error, "Failed to update bus")}
        end
    end
  end

  def handle_event("edit_bus", %{"id" => id}, socket) do
    bus = Buses.get_bus!(id)

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_bus, bus)
     |> assign(:error, nil)}
  end

  def handle_event("delete_bus", %{"id" => id}, socket) do
    bus = Buses.get_bus!(id)
    {:ok, _} = Buses.delete_bus(bus)

    {:noreply,
     socket
     |> put_flash(:success, "Bus removed from fleet")
     |> assign(:buses, Buses.paginate_buses(socket.assigns.page, socket.assigns.page_size))
     |> assign(:total_count, Buses.count_buses())}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, not socket.assigns.sidebar_collapsed)}
  end

  def handle_event("toggle_bus", %{"category" => "bus"}, socket) do
    {:noreply, assign(socket, :bus_expanded, not socket.assigns.bus_expanded)}
  end

  def handle_event("toggle_chyllz", %{"category" => "chyllz"}, socket) do
    {:noreply, assign(socket, :chyllz_expanded, not socket.assigns.chyllz_expanded)}
  end

  def handle_event("toggle_settings", %{"category" => "settings"}, socket) do
    {:noreply, assign(socket, :settings_expanded, not socket.assigns.settings_expanded)}
  end

  defp sanitize_params(params) do
    params
    |> Map.update("total_seats", 40, fn v ->
      case Integer.parse(to_string(v)) do
        {n, _} -> n
        _ -> 40
      end
    end)
    |> Map.update("travel_date", Date.to_string(Date.utc_today()), fn v ->
      if v == "", do: Date.to_string(Date.utc_today()), else: v
    end)
  end

  def render_template(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-slate-50/50 font-sans">
      <.sidebar
        active_tab={@active_tab}
        collapsed={@sidebar_collapsed}
        bus_expanded={@bus_expanded}
        chyllz_expanded={@chyllz_expanded}
        settings_expanded={@settings_expanded}
      />
      <main class={[
        "flex-1 transition-all duration-300",
        if(@sidebar_collapsed, do: "pl-20", else: "pl-72")
      ]}>
        <div class="p-8 md:p-12 max-w-[1600px] mx-auto">
          <header class="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-12">
            <div>
              <h1 class="text-3xl font-black text-slate-900 uppercase tracking-tighter">
                Fleet Management
              </h1>

              <p class="text-sm font-bold text-slate-400 mt-1 uppercase tracking-widest">
                Manage your buses, routes and schedules
              </p>
            </div>

            <button
              phx-click="open_add_modal"
              class="bg-[#FF4C00] text-white px-8 py-4 rounded-2xl font-black text-sm uppercase tracking-widest hover:bg-[#E64400] transition shadow-lg shadow-orange-200 active:scale-95 flex items-center justify-center gap-3"
            >
              <span class="material-symbols-outlined !text-xl">add_circle</span> Add New Bus
            </button>
          </header>

          <div class="bg-white rounded-[2.5rem] shadow-sm border border-slate-100 overflow-hidden">
            <div class="p-8 border-b border-slate-50 flex flex-col md:flex-row justify-between items-center gap-6 bg-slate-50/30">
              <div class="relative w-full md:w-96 group">
                <span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-slate-300 group-focus-within:text-[#FF4C00] transition-colors">search</span>
                <input
                  type="text"
                  placeholder="Search fleet (Reg, Operator...)"
                  class="w-full pl-12 pr-6 py-3.5 bg-white border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all"
                />
              </div>

              <div class="flex items-center gap-3">
                <button class="w-11 h-11 rounded-xl bg-white border border-slate-100 flex items-center justify-center text-slate-400 hover:text-slate-900 transition-all">
                  <span class="material-symbols-outlined !text-xl">filter_list</span>
                </button>
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full text-left border-collapse">
                <thead>
                  <tr class="bg-slate-50/50 border-b border-slate-50">
                    <th class="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">
                      Vehicle Details
                    </th>

                    <th class="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">
                      Route
                    </th>

                    <th class="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">
                      Schedule
                    </th>

                    <th class="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">
                      Pricing
                    </th>

                    <th class="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[0.2em]">
                      Capacity
                    </th>

                    <th class="px-8 py-5 text-[10px] font-black text-slate-400 uppercase tracking-[0.2em] text-right">
                      Actions
                    </th>
                  </tr>
                </thead>

                <tbody class="divide-y divide-slate-50">
                  <%= for bus <- @buses do %>
                    <tr class="hover:bg-slate-50/30 transition-colors group">
                      <td class="px-8 py-6">
                        <div class="flex items-center gap-4">
                          <div class="w-12 h-12 rounded-xl bg-slate-100 flex items-center justify-center text-slate-400">
                            <span class="material-symbols-outlined">directions_bus</span>
                          </div>

                          <div>
                            <div class="text-sm font-black text-slate-900 uppercase">
                              {bus.company}
                            </div>

                            <div class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-0.5">
                              {bus.registration || "NO REG"}
                            </div>
                          </div>
                        </div>
                      </td>

                      <td class="px-8 py-6">
                        <div class="flex items-center gap-3">
                          <div class="text-xs font-black text-slate-700 uppercase">{bus.from}</div>

                          <span class="material-symbols-outlined !text-xs text-slate-300">arrow_forward</span>
                          <div class="text-xs font-black text-slate-700 uppercase">{bus.to}</div>
                        </div>
                      </td>

                      <td class="px-8 py-6">
                        <div class="space-y-1">
                          <div class="text-xs font-black text-slate-900 flex items-center gap-2">
                            <span class="material-symbols-outlined !text-xs text-[#FF4C00]">schedule</span> {bus.departure} - {bus.arrival}
                          </div>

                          <div class="text-[10px] font-bold text-slate-400 uppercase">
                            {Calendar.strftime(bus.travel_date, "%b %d, %Y")}
                          </div>
                        </div>
                      </td>

                      <td class="px-8 py-6">
                        <div class="text-sm font-black text-[#FF4C00]">{bus.price}</div>

                        <div class="text-[9px] font-bold text-slate-400 uppercase mt-0.5 tracking-widest">
                          Normal fare
                        </div>
                      </td>

                      <td class="px-8 py-6">
                        <div class="flex items-center gap-3">
                          <div class="h-2 w-24 rounded-full bg-slate-100 overflow-hidden">
                            <% occupied = length(bus.occupied_seats || []) %> <% percent =
                              occupied / (bus.total_seats || 40) * 100 %>
                            <div
                              class="h-full bg-emerald-500 rounded-full"
                              style={"width: #{percent}%"}
                            >
                            </div>
                          </div>

                          <span class="text-xs font-black text-slate-700">{bus.total_seats} Seats</span>
                        </div>
                      </td>

                      <td class="px-8 py-6 text-right">
                        <div class="flex items-center justify-end gap-2">
                          <button
                            phx-click="edit_bus"
                            phx-value-id={bus.id}
                            class="w-9 h-9 rounded-lg bg-slate-50 flex items-center justify-center text-slate-400 hover:bg-[#FF4C00] hover:text-white transition-all"
                          >
                            <span class="material-symbols-outlined !text-lg">edit</span>
                          </button>

                          <button
                            phx-click="delete_bus"
                            phx-value-id={bus.id}
                            data-confirm="Are you sure you want to remove this bus from the fleet?"
                            class="w-9 h-9 rounded-lg bg-slate-50 flex items-center justify-center text-slate-400 hover:bg-red-500 hover:text-white transition-all"
                          >
                            <span class="material-symbols-outlined !text-lg">delete</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            <.pager page={@page} page_size={@page_size} total_count={@total_count} />
          </div>
        </div>
      </main>
      <%!-- Add/Edit Modal --%>
      <%= if @show_modal do %>
        <div class="fixed inset-0 z-[60] flex items-center justify-center p-6">
          <div class="absolute inset-0 bg-slate-900/80 backdrop-blur-sm" phx-click="close_modal">
          </div>

          <div class="relative bg-white w-full max-w-2xl rounded-[3rem] shadow-2xl overflow-hidden animate-in fade-in zoom-in duration-300">
            <div class="p-8 md:p-12">
              <div class="flex items-center justify-between mb-10">
                <div>
                  <h2 class="text-2xl font-black text-slate-900 uppercase tracking-tighter">
                    {if @editing_bus, do: "Edit Bus Details", else: "Add New Bus to Fleet"}
                  </h2>

                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-1">
                    Industrial Fleet Management Engine
                  </p>
                </div>

                <button
                  phx-click="close_modal"
                  class="w-12 h-12 rounded-full bg-slate-50 flex items-center justify-center text-slate-400 hover:text-slate-900 transition-all"
                >
                  <span class="material-symbols-outlined">close</span>
                </button>
              </div>

              <%= if @error do %>
                <div class="mb-8 p-4 bg-red-50 border border-red-100 rounded-2xl text-red-600 text-xs font-black uppercase tracking-widest flex items-center gap-3">
                  <span class="material-symbols-outlined">error</span> {@error}
                </div>
              <% end %>

              <form phx-submit="save_bus" class="space-y-8">
                <div class="grid grid-cols-2 gap-8">
                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Bus Operator</label>
                    <select
                      name="bus[bus_operator_id]"
                      required
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    >
                      <option value="">Select Operator</option>

                      <%= for op <- @operators do %>
                        <option
                          value={op.id}
                          selected={@editing_bus && @editing_bus.bus_operator_id == op.id}
                        >
                          {op.name}
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Operator Name (Display)</label>
                    <input
                      type="text"
                      name="bus[company]"
                      value={if @editing_bus, do: @editing_bus.company, else: ""}
                      required
                      placeholder="e.g. Komiuta Bus"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">From City</label>
                    <select
                      name="bus[from]"
                      required
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    >
                      <option value="">Select Origin</option>

                      <%= for city <- @cities do %>
                        <option value={city} selected={@editing_bus && @editing_bus.from == city}>
                          {city}
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">To City</label>
                    <select
                      name="bus[to]"
                      required
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    >
                      <option value="">Select Destination</option>

                      <%= for city <- @cities do %>
                        <option value={city} selected={@editing_bus && @editing_bus.to == city}>
                          {city}
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Travel Date</label>
                    <input
                      type="date"
                      name="bus[travel_date]"
                      value={
                        if @editing_bus,
                          do: @editing_bus.travel_date,
                          else: Date.to_string(Date.utc_today())
                      }
                      required
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Base Price (KES)</label>
                    <input
                      type="text"
                      name="bus[price]"
                      value={if @editing_bus, do: @editing_bus.price, else: "KSH 1500"}
                      required
                      placeholder="KSH 1500"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Departure Time</label>
                    <input
                      type="text"
                      name="bus[departure]"
                      value={if @editing_bus, do: @editing_bus.departure, else: "08:00 AM"}
                      required
                      placeholder="08:00 AM"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Arrival Time</label>
                    <input
                      type="text"
                      name="bus[arrival]"
                      value={if @editing_bus, do: @editing_bus.arrival, else: "04:00 PM"}
                      required
                      placeholder="04:00 PM"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Vehicle Registration</label>
                    <input
                      type="text"
                      name="bus[registration]"
                      value={if @editing_bus, do: @editing_bus.registration, else: ""}
                      placeholder="KAA 123X"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest">Total Capacity</label>
                    <input
                      type="number"
                      name="bus[total_seats]"
                      value={if @editing_bus, do: @editing_bus.total_seats, else: 40}
                      required
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all"
                    />
                  </div>
                </div>

                <div class="flex gap-4 pt-6">
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="flex-1 px-8 py-5 border-2 border-slate-100 rounded-2xl font-black text-xs uppercase tracking-widest text-slate-400 hover:border-slate-200 hover:text-slate-900 transition"
                  >
                    Cancel
                  </button>

                  <button
                    type="submit"
                    class="flex-1 px-8 py-5 bg-[#FF4C00] text-white rounded-2xl font-black text-xs uppercase tracking-widest hover:bg-[#E64400] transition shadow-xl shadow-orange-200 active:scale-95"
                  >
                    {if @editing_bus, do: "Update Bus", else: "Register Bus"}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
