defmodule XpressbusWeb.PartnerRegistrationLive do
  use XpressbusWeb, :live_view
  alias Xpressbus.{BusOperators, Buses, Cities, Repo}
  require Logger

  def mount(_params, _session, socket) do
    cities =
      Cities.list_cities() |> Enum.filter(& &1.active) |> Enum.map(& &1.name) |> Enum.sort()

    {:ok,
     socket
     |> assign(:page_title, "Partner Registration")
     # For header highlight
     |> assign(:step, :fleet)
     |> assign(:cities, cities)
     |> assign(:error, nil)
     |> assign(:success, false)
     |> assign(
       :form,
       to_form(%{
         "operator" => %{
           "name" => "",
           "contact_person" => "",
           "email" => "",
           "phone" => ""
         },
         "bus" => %{
           "from" => "",
           "to" => "",
           "departure" => "08:00 AM",
           "arrival" => "04:00 PM",
           "price" => "KSH 1500",
           "registration" => "",
           "total_seats" => 40
         }
       })
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f8fafc] font-sans pt-32 pb-24 px-6">
      <div class="max-w-4xl mx-auto">
        <div class="text-center mb-16">
          <h1 class="text-4xl md:text-5xl font-black text-slate-900 uppercase tracking-tighter mb-4">
            Become a Partner
          </h1>

          <p class="text-slate-500 font-bold uppercase tracking-widest text-sm max-w-2xl mx-auto">
            Join East Africa's fastest growing bus network. Register your company and add your first fleet vehicle in minutes.
          </p>
        </div>

        <%= if @success do %>
          <div class="bg-white rounded-[3rem] border border-slate-100 p-12 text-center shadow-2xl animate-fade-in">
            <div class="w-20 h-20 bg-emerald-50 text-emerald-500 rounded-full flex items-center justify-center mx-auto mb-8 shadow-lg shadow-emerald-50">
              <span class="material-symbols-outlined !text-4xl">check_circle</span>
            </div>

            <h2 class="text-2xl font-black text-slate-900 uppercase tracking-tight mb-4">
              Application Received!
            </h2>

            <p class="text-slate-500 font-bold leading-relaxed mb-8">
              Thank you for choosing Komiuta. Your partner account and fleet registration are being reviewed by our industrial operations team. We will contact you within 24 hours.
            </p>

            <a
              href="/"
              class="inline-block px-10 py-4 bg-[#FF4C00] text-white rounded-2xl font-black uppercase tracking-widest text-xs hover:bg-[#E64400] transition shadow-xl"
            >Back to Home</a>
          </div>
        <% else %>
          <div class="bg-white rounded-[3rem] border border-slate-100 shadow-2xl overflow-hidden overflow-visible">
            <form phx-submit="register_partner" class="p-8 md:p-16 space-y-12">
              <%!-- Operator Details --%>
              <div class="space-y-8">
                <div class="flex items-center gap-4 border-b border-slate-50 pb-6">
                  <div class="w-12 h-12 rounded-2xl bg-orange-50 flex items-center justify-center text-[#FF4C00]">
                    <span class="material-symbols-outlined">corporate_fare</span>
                  </div>

                  <div>
                    <h3 class="text-xl font-black text-slate-900 uppercase tracking-tight">
                      Company Details
                    </h3>

                    <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-0.5">
                      Your Operational Identity
                    </p>
                  </div>
                </div>

                <div class="grid md:grid-cols-2 gap-8">
                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Company Name</label>
                    <input
                      type="text"
                      name="operator[name]"
                      required
                      placeholder="e.g. Komiuta Express"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Contact Person</label>
                    <input
                      type="text"
                      name="operator[contact_person]"
                      required
                      placeholder="Full Name"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Official Email</label>
                    <input
                      type="email"
                      name="operator[email]"
                      required
                      placeholder="partner@company.co.ke"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Contact Phone</label>
                    <input
                      type="tel"
                      name="operator[phone]"
                      required
                      placeholder="07XX..."
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all"
                    />
                  </div>
                </div>
              </div>
              <%!-- First Bus Details --%>
              <div class="space-y-8">
                <div class="flex items-center gap-4 border-b border-slate-50 pb-6">
                  <div class="w-12 h-12 rounded-2xl bg-blue-50 flex items-center justify-center text-blue-500">
                    <span class="material-symbols-outlined">directions_bus</span>
                  </div>

                  <div>
                    <h3 class="text-xl font-black text-slate-900 uppercase tracking-tight">
                      Fleet Information
                    </h3>

                    <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-0.5">
                      Register Your First Vehicle
                    </p>
                  </div>
                </div>

                <div class="grid md:grid-cols-2 gap-8">
                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Vehicle Registration</label>
                    <input
                      type="text"
                      name="bus[registration]"
                      required
                      placeholder="KAA 123X"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Total Seats</label>
                    <input
                      type="number"
                      name="bus[total_seats]"
                      required
                      value="40"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">From City</label>
                    <select
                      name="bus[from]"
                      required
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    >
                      <option value="">Select Origin</option>

                      <%= for city <- @cities do %>
                        <option value={city}>{city}</option>
                      <% end %>
                    </select>
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">To City</label>
                    <select
                      name="bus[to]"
                      required
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    >
                      <option value="">Select Destination</option>

                      <%= for city <- @cities do %>
                        <option value={city}>{city}</option>
                      <% end %>
                    </select>
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Base Price (KES)</label>
                    <input
                      type="text"
                      name="bus[price]"
                      required
                      value="KSH 1500"
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all uppercase"
                    />
                  </div>

                  <div class="space-y-2">
                    <label class="text-[10px] font-black text-slate-400 uppercase tracking-widest ml-1">Initial Travel Date</label>
                    <input
                      type="date"
                      name="bus[travel_date]"
                      required
                      value={Date.to_string(Date.utc_today())}
                      class="w-full px-6 py-4 bg-slate-50 border-slate-100 rounded-2xl text-sm font-bold focus:ring-4 focus:ring-orange-50 focus:border-[#FF4C00] transition-all"
                    />
                  </div>
                </div>
              </div>

              <%= if @error do %>
                <div class="p-4 bg-red-50 border border-red-100 rounded-2xl text-red-600 text-xs font-black uppercase tracking-widest flex items-center gap-3">
                  <span class="material-symbols-outlined">error</span> {@error}
                </div>
              <% end %>

              <div class="pt-6">
                <button
                  type="submit"
                  class="w-full bg-[#FF4C00] text-white py-6 rounded-3xl font-black uppercase tracking-[0.2em] text-sm hover:bg-[#E64400] transition shadow-2xl shadow-orange-500/20 active:scale-[0.99] flex items-center justify-center gap-4 group"
                >
                  <span>Register Fleet & Join Komiuta</span>
                  <span class="material-symbols-outlined !text-2xl group-hover:translate-x-2 transition-transform">arrow_forward</span>
                </button>
              </div>
            </form>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("register_partner", %{"operator" => op_params, "bus" => bus_params}, socket) do
    # 1. Start Transaction
    Repo.transaction(fn ->
      # 2. Create Operator
      op_attrs = %{
        name: String.trim(op_params["name"]),
        contact_person: String.trim(op_params["contact_person"]),
        email: String.trim(op_params["email"]),
        phone: String.trim(op_params["phone"]),
        # Requires admin approval
        active: false
      }

      case BusOperators.create_bus_operator(op_attrs) do
        {:ok, operator} ->
          # 3. Create Bus linked to Operator
          bus_attrs = %{
            bus_operator_id: operator.id,
            company: operator.name,
            registration: String.trim(bus_params["registration"]),
            from: bus_params["from"],
            to: bus_params["to"],
            price: bus_params["price"],
            travel_date: bus_params["travel_date"],
            departure: bus_params["departure"],
            arrival: bus_params["arrival"],
            total_seats: String.to_integer(bus_params["total_seats"]),
            amenities: ["AC", "Charging"],
            seat_types: ["Normal", "VIP"],
            occupied_seats: []
          }

          case Buses.create_bus(bus_attrs) do
            {:ok, _bus} ->
              :ok

            {:error, changeset} ->
              Logger.error("Failed to create bus: #{inspect(changeset.errors)}")
              Repo.rollback("Vehicle registration failed. Check fields.")
          end

        {:error, changeset} ->
          Logger.error("Failed to create operator: #{inspect(changeset.errors)}")
          Repo.rollback("Company name already exists or invalid details.")
      end
    end)
    |> case do
      {:ok, :ok} ->
        {:noreply, assign(socket, success: true, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: reason)}
    end
  end
end
