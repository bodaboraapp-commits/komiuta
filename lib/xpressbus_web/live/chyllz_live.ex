defmodule XpressbusWeb.ChyllzLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents

  def mount(_params, session, socket) do
    current_user = session["user_id"]

    {:ok,
     socket
     |> assign(:footer_tab, "about")
     |> assign(:step, :chyllz)
     |> assign(:current_user, current_user)}
  end

  def handle_params(_params, _url, socket) do
    step =
      case socket.assigns.live_action do
        :hotels -> :hotels
        :gems -> :gems
        :car -> :car
        :events -> :events
        _ -> :chyllz
      end

    {:noreply, assign(socket, :step, step)}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white text-slate-900">
      <.main_header step={@step} current_user={@current_user} />
      <main class="pt-[72px] md:pt-[80px]">
        <%!-- 1. Hero Section --%>
        <section class="relative pt-20 pb-[200px] px-6 rounded-b-[4rem] md:rounded-b-[8rem] overflow-hidden bg-slate-950 text-white">
          <video
            autoplay
            muted
            loop
            playsinline
            preload="none"
            poster="/images/hero_bg.png"
            class="absolute inset-0 w-full h-full object-cover opacity-95"
          >
            <source src="/images/hero_video.mp4" type="video/mp4" />
          </video>

          <div class="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black/40">
          </div>

          <div class="max-w-[1350px] mx-auto flex flex-col items-center justify-center relative z-10 text-center">
            <h1 class="text-4xl md:text-7xl font-black tracking-tighter mb-8 leading-tight">
              Find Your Perfect Stay with Chyllz
            </h1>

            <p class="text-xl md:text-2xl font-medium opacity-90 mb-12 max-w-2xl">
              Premium rooms, apartments, and staycations curated for the modern traveler.
            </p>
            <%!-- Room Search Pill --%>
            <div class="w-full max-w-4xl bg-white p-4 rounded-[2.5rem] shadow-2xl flex flex-col md:flex-row items-center gap-4 text-slate-900">
              <div class="flex-1 flex items-center gap-3 px-6 border-r border-slate-100">
                <span class="material-symbols-outlined text-orange-500">location_on</span>
                <input
                  type="text"
                  placeholder="Where are you going?"
                  class="w-full py-4 font-bold outline-none"
                />
              </div>

              <div class="flex-1 flex items-center gap-3 px-6 border-r border-slate-100">
                <span class="material-symbols-outlined text-orange-500">calendar_month</span>
                <input type="text" placeholder="Dates" class="w-full py-4 font-bold outline-none" />
              </div>

              <button class="bg-[#FF4C00] text-white px-10 py-4 rounded-full font-black hover:bg-[#E64400] transition shadow-lg shadow-orange-200">
                Search Rooms
              </button>
            </div>
          </div>
        </section>
        <%!-- 2. Service Listings --%>
        <div class="max-w-[1350px] mx-auto px-6 space-y-20 py-[58px]">
          <%!-- Hotels Section --%>
          <section id="hotels">
            <div class="flex justify-between items-end mb-8">
              <div>
                <div class="flex items-center gap-3 mb-2">
                  <span class="material-symbols-outlined text-[#FF4C00] !text-3xl">hotel</span>
                  <h2 class="text-3xl md:text-4xl font-black tracking-tight text-slate-900">
                    Premium Hotels
                  </h2>
                </div>

                <p class="text-slate-400 font-bold">
                  Curated luxury stays and boutique hotels for every budget.
                </p>
              </div>

              <a
                href="/tour-packages/hotels"
                class="text-[#FF4C00] font-black uppercase text-xs tracking-widest flex items-center gap-2 hover:underline transition-all hover:gap-3"
              >
                View All Hotels <span class="material-symbols-outlined !text-sm">arrow_forward</span>
              </a>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
              <%= for {name, price, img} <- [{"The Sands Resort", "12,500", "room_1"}, {"Sarova Stanley", "18,000", "room_2"}, {"Hemingways Watamu", "25,000", "room_3"}] do %>
                <div class="group cursor-pointer">
                  <div class="aspect-[4/3] rounded-[2.5rem] overflow-hidden mb-6 relative shadow-lg">
                    <div class="absolute inset-0 bg-slate-100 animate-pulse"></div>

                    <img
                      src={"/images/#{img}.jpg"}
                      alt={name}
                      loading="lazy"
                      class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                      onerror="this.style.display='none'"
                    />
                    <div class="absolute top-6 right-6 bg-white/95 backdrop-blur-md px-5 py-2 rounded-full font-black text-xs shadow-xl border border-slate-50">
                      Ksh {price}/night
                    </div>
                  </div>

                  <h3 class="text-xl font-black text-slate-900 group-hover:text-[#FF4C00] transition-colors">
                    {name}
                  </h3>

                  <p class="text-sm font-bold text-slate-400 mt-1 flex items-center gap-2">
                    <span class="material-symbols-outlined !text-sm text-yellow-500">star</span>
                    4.9 • All Inclusive • Free Cancellation
                  </p>
                </div>
              <% end %>
            </div>
          </section>
          <%!-- Hidden Gems Section --%>
          <section id="hidden-gems">
            <div class="flex justify-between items-end mb-8">
              <div>
                <div class="flex items-center gap-3 mb-2">
                  <span class="material-symbols-outlined text-[#FF4C00] !text-3xl">explore</span>
                  <h2 class="text-3xl md:text-4xl font-black tracking-tight text-slate-900">
                    Hidden Gems
                  </h2>
                </div>

                <p class="text-slate-400 font-bold">
                  Discover East Africa's best-kept secrets and off-the-beaten-path adventures.
                </p>
              </div>

              <a
                href="/our-packages/hidden-gems"
                class="text-[#FF4C00] font-black uppercase text-xs tracking-widest flex items-center gap-2 hover:underline transition-all hover:gap-3"
              >
                Explore All Gems <span class="material-symbols-outlined !text-sm">arrow_forward</span>
              </a>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
              <%= for {title, loc, img} <- [{"Chale Island Retreat", "Kwale", "room_1"}, {"Hell's Gate Gorges", "Naivasha", "room_2"}, {"Lamu Archipelago", "Lamu", "room_3"}] do %>
                <div class="relative rounded-[3rem] overflow-hidden group cursor-pointer aspect-square shadow-2xl">
                  <img
                    src={"/images/#{img}.jpg"}
                    alt={title}
                    loading="lazy"
                    class="absolute inset-0 w-full h-full object-cover transition-transform duration-1000 group-hover:scale-110"
                    onerror="this.style.display='none'"
                  />
                  <div class="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent">
                  </div>

                  <div class="absolute bottom-10 left-10 right-10">
                    <div class="text-[11px] font-black uppercase tracking-[0.3em] text-yellow-400 mb-2">
                      {loc}
                    </div>

                    <h3 class="text-2xl font-black text-white leading-tight">{title}</h3>

                    <div class="mt-4 flex items-center gap-2 text-white/80 font-bold text-xs group-hover:gap-4 transition-all">
                      Read Story
                      <span class="material-symbols-outlined !text-base">arrow_right_alt</span>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </section>
          <%!-- Car Hire Section --%>
          <section id="car-hire">
            <div class="flex justify-between items-end mb-8">
              <div>
                <div class="flex items-center gap-3 mb-2">
                  <span class="material-symbols-outlined text-[#FF4C00] !text-3xl">directions_car</span>
                  <h2 class="text-3xl md:text-4xl font-black tracking-tight text-slate-900">
                    Premium Car Hire
                  </h2>
                </div>

                <p class="text-slate-400 font-bold">
                  Reliable vehicles for self-drive or chauffeured regional travel.
                </p>
              </div>

              <a
                href="/tour-packages/car"
                class="text-[#FF4C00] font-black uppercase text-xs tracking-widest flex items-center gap-2 hover:underline transition-all hover:gap-3"
              >
                Book a Vehicle <span class="material-symbols-outlined !text-sm">arrow_forward</span>
              </a>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
              <%= for {car, type, price} <- [{"Toyota Landcruiser", "4x4 Safari", "15,000"}, {"Range Rover Sport", "Luxury SUV", "35,000"}, {"Toyota Rav4", "Compact 4x4", "8,500"}, {"Mercedes S-Class", "Corporate", "45,000"}] do %>
                <div class="bg-slate-50 rounded-[2rem] p-8 border border-slate-100 hover:border-orange-200 transition-all group">
                  <div class="text-[10px] font-black uppercase tracking-widest text-slate-400 mb-4">
                    {type}
                  </div>

                  <h3 class="text-xl font-black text-slate-900 mb-6">{car}</h3>

                  <div class="flex justify-between items-end">
                    <div>
                      <div class="text-[10px] font-bold text-slate-400 uppercase">From</div>

                      <div class="text-lg font-black text-slate-900">Ksh {price}</div>
                    </div>

                    <div class="w-10 h-10 rounded-full bg-white flex items-center justify-center text-[#FF4C00] shadow-md group-hover:bg-[#FF4C00] group-hover:text-white transition-all">
                      <span class="material-symbols-outlined !text-xl">add</span>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </section>
          <%!-- Events Section --%>
          <section
            id="events"
            class="bg-slate-900 rounded-[4rem] p-8 md:p-14 text-white relative overflow-hidden"
          >
            <div class="absolute top-0 right-0 w-96 h-96 bg-[#FF4C00]/20 rounded-full blur-[120px]">
            </div>

            <div class="relative z-10">
              <div class="flex flex-col md:flex-row justify-between items-center md:items-end gap-8 mb-12">
                <div class="text-center md:text-left">
                  <div class="flex items-center justify-center md:justify-start gap-3 mb-2">
                    <span class="material-symbols-outlined text-[#FF4C00] !text-3xl">local_activity</span>
                    <h2 class="text-3xl md:text-4xl font-black tracking-tight text-white">
                      Upcoming Events
                    </h2>
                  </div>

                  <p class="text-slate-400 font-bold">
                    The most anticipated festivals, concerts, and cultural experiences in the region.
                  </p>
                </div>

                <a
                  href="/tour-packages/events"
                  class="bg-[#FF4C00] text-white px-8 py-4 rounded-full font-black uppercase text-xs tracking-widest hover:bg-[#E64400] transition-all shadow-xl shadow-orange-950/40"
                >
                  See All Events
                </a>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                <%= for {event, date, loc} <- [{"Safari Rally Kenya", "June 24-27", "Naivasha"}, {"Blankets & Wine", "Dec 15", "Nairobi"}] do %>
                  <div class="flex gap-8 items-center group cursor-pointer border-b border-white/10 pb-12 last:border-0 last:pb-0">
                    <div class="flex flex-col items-center justify-center w-24 h-24 rounded-3xl bg-white/5 border border-white/10 shrink-0 text-center">
                      <div class="text-2xl font-black text-[#FF4C00]">
                        {String.slice(date, -2, 2)}
                      </div>

                      <div class="text-[10px] font-black uppercase tracking-widest opacity-60">
                        {String.slice(date, 0, 3)}
                      </div>
                    </div>

                    <div class="flex-1">
                      <h3 class="text-2xl md:text-3xl font-black group-hover:text-[#FF4C00] transition-colors">
                        {event}
                      </h3>

                      <div class="flex items-center gap-4 mt-2 text-slate-400 font-bold text-sm">
                        <span class="flex items-center gap-1"><span class="material-symbols-outlined !text-sm text-[#FF4C00]">location_on</span> {loc}</span>
                        <span class="flex items-center gap-1"><span class="material-symbols-outlined !text-sm text-[#FF4C00]">confirmation_number</span>
                        Tickets Available</span>
                      </div>
                    </div>

                    <div class="w-12 h-12 rounded-full border border-white/20 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-all group-hover:translate-x-2">
                      <span class="material-symbols-outlined">arrow_forward</span>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </section>
        </div>
      </main>
      <.main_footer footer_tab={@footer_tab} />
    </div>
    """
  end
end
