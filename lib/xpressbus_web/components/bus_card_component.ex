defmodule XpressbusWeb.BusCardComponent do
  use Phoenix.LiveComponent

  attr :bus, :map, required: true
  attr :from, :string, default: nil
  attr :to, :string, default: nil
  attr :id, :string, required: true

  defp initials_color(name) do
    hash = :erlang.phash2(name)

    colors = [
      "bg-orange-500",
      "bg-emerald-500",
      "bg-blue-500",
      "bg-purple-500",
      "bg-pink-500",
      "bg-teal-500",
      "bg-indigo-500",
      "bg-amber-500"
    ]

    Enum.at(colors, rem(hash, length(colors)))
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="group relative overflow-hidden rounded-[1.5rem] bg-white border border-slate-100 shadow-sm hover:shadow-xl transition-all duration-500 text-slate-900"
    >
      <div class="p-6 md:p-8">
        <div class="flex flex-col lg:flex-row items-center gap-8">
          <div class="flex flex-col items-center gap-3 w-full lg:w-32 shrink-0 lg:border-r lg:border-slate-50 lg:pr-8">
            <div class="h-16 w-16 rounded-2xl bg-white p-2 flex items-center justify-center border border-slate-100 shadow-sm group-hover:scale-105 transition-transform duration-500">
              <%= if @bus.bus_operator && @bus.bus_operator.logo_url do %>
                <img
                  src={@bus.bus_operator.logo_url}
                  class="h-full w-full object-contain"
                  alt={@bus.company}
                />
              <% else %>
                <div class={"h-full w-full rounded-xl flex items-center justify-center text-white font-black text-[10px] #{initials_color(@bus.company)}"}>
                  {String.slice(@bus.company || "Komiuta Bus", 0, 2)}
                </div>
              <% end %>
            </div>
            <h4 class="text-xs font-black text-slate-900 tracking-tight text-center uppercase whitespace-nowrap">
              {@bus.company || "Komiuta Bus"}
            </h4>
          </div>

          <div class="flex-1 flex flex-col items-center w-full px-4 md:px-8 lg:px-12 text-center">
            <div class="flex items-center justify-between w-full">
              <div class="text-center min-w-[100px]">
                <span class="text-2xl font-black text-slate-900 tracking-tighter">{@bus.departure ||
                  "--:-- --"}</span>
                <p class="text-[11px] font-black text-slate-400 mt-1 uppercase">
                  {@from || "Nairobi"}
                </p>
              </div>

              <div class="flex-1 flex flex-col items-center px-6 relative">
                <div class="w-full h-px border-t-2 border-dashed border-slate-200 relative">
                  <div class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 bg-white px-4 text-[#FF4C00]">
                    <span class="material-symbols-outlined !text-2xl">directions_bus</span>
                  </div>
                </div>
                <div class="mt-5 inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-orange-50 border border-orange-100 shadow-sm">
                  <span class="material-symbols-outlined text-orange-500 !text-[12px]">airline_seat_recline_extra</span>
                  <span class="text-[10px] font-black text-orange-600 uppercase tracking-widest">{@bus.seats ||
                    "Limited seats"}</span>
                </div>
              </div>

              <div class="text-center min-w-[100px]">
                <span class="text-2xl font-black text-slate-900 tracking-tighter">{@bus.arrival ||
                  "--:xx --"}</span>
                <p class="text-[11px] font-black text-slate-400 mt-1 uppercase">{@to || "Kisumu"}</p>
              </div>
            </div>
          </div>

          <div class="w-full lg:w-48 flex flex-col items-end gap-5 lg:border-l lg:border-slate-50 lg:pl-8">
            <div class="flex flex-col items-end gap-1.5 w-full">
              <div class="flex items-center gap-3 w-full justify-end">
                <span class="text-[11px] font-bold text-slate-400 uppercase">Normal</span>
                <span class="text-sm font-black text-slate-900">KES {if is_binary(@bus.price),
                  do: String.replace(@bus.price, ~r/[^0-9]/, ""),
                  else: "1500"}</span>
              </div>
              <div class="flex items-center gap-3 w-full justify-end">
                <span class="text-[11px] font-bold text-slate-400 uppercase">Vip</span>
                <span class="text-sm font-black text-slate-900">KES {if is_binary(@bus.vip_price),
                  do: String.replace(@bus.vip_price, ~r/[^0-9]/, ""),
                  else: "2300"}</span>
              </div>
              <div class="flex items-center gap-3 w-full justify-end">
                <span class="text-[11px] font-bold text-slate-400 uppercase">First_class</span>
                <span class="text-sm font-black text-slate-900">KES {if is_binary(
                                                                          @bus.first_class_price
                                                                        ),
                                                                        do:
                                                                          String.replace(
                                                                            @bus.first_class_price,
                                                                            ~r/[^0-9]/,
                                                                            ""
                                                                          ),
                                                                        else: "1800"}</span>
              </div>
              <div class="flex items-center gap-3 w-full justify-end">
                <span class="text-[11px] font-bold text-slate-400 uppercase">Business</span>
                <span class="text-sm font-black text-slate-900">KES {if is_binary(
                                                                          @bus.business_price
                                                                        ),
                                                                        do:
                                                                          String.replace(
                                                                            @bus.business_price,
                                                                            ~r/[^0-9]/,
                                                                            ""
                                                                          ),
                                                                        else: "2000"}</span>
              </div>
            </div>

            <button
              type="button"
              phx-click="select_bus"
              phx-value-id={@bus.id}
              class="w-full bg-gradient-to-br from-[#d52263] via-[#ff4c00] to-[#ff4c00] text-white py-3.5 rounded-2xl font-black uppercase tracking-[0.2em] text-[10px] shadow-xl shadow-orange-500/20 hover:scale-[1.02] transition-all transform active:scale-95"
            >
              Select Seat
            </button>
          </div>
        </div>

        <div class="pt-5 border-t border-slate-50 flex items-center gap-3 overflow-x-auto no-scrollbar">
          <span class="text-[11px] font-black text-slate-400 uppercase tracking-widest shrink-0">Amenities:</span>
          <div class="flex items-center gap-2">
            <%= for amenity <- (@bus.amenities || ["AC", "Charging", "Wi-Fi"]) do %>
              <% icon =
                Map.get(
                  %{
                    "AC" => "ac_unit",
                    "Wi-Fi" => "wifi",
                    "Charging" => "power",
                    "TV" => "tv",
                    "Snacks" => "restaurant",
                    "Drinks" => "local_drink",
                    "Blanket" => "bed",
                    "Water" => "water_drop",
                    "Toilet" => "wc"
                  },
                  amenity,
                  "info"
                ) %>
              <div class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-slate-50 border border-slate-100 shrink-0">
                <span class="material-symbols-outlined !text-sm text-orange-400">{icon}</span>
                <span class="text-[10px] font-black text-slate-500 uppercase tracking-widest">{amenity}</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
