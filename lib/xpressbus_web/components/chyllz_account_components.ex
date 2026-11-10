defmodule XpressbusWeb.ChyllzAccountComponents do
  @moduledoc """
  The Chyllz account experience: greeting, counters, recent trips, live weather
  and popular destinations.

  This used to be a standalone page (`/chyllz/account`). It now renders inside
  the user dashboard's **My Chyllz** tab, so the same account shell toggles
  between bus bookings and the Chyllz travel view.

  Every number comes from the database or the curated travel blog — nothing is
  demo content. The weather widget is fed by `Xpressbus.Weather` (Open-Meteo)
  and degrades to a friendly retry card when the service is unavailable. The
  palette stays Komiuta orange (`#FF4C00`) on white/slate cards.
  """

  use XpressbusWeb, :html

  import XpressbusWeb.ChyllzAccountArt
  import XpressbusWeb.Format, only: [money: 1, short_date: 1]

  @trend_points 7
  @city_max_length 60

  attr :user, :map, required: true
  attr :overview, :map, required: true
  attr :trips, :list, required: true
  attr :hotel_bookings, :list, default: []
  attr :picks, :list, default: []
  attr :story_cards, :list, default: []
  attr :member_since, :string, default: nil
  attr :weather, :map, default: nil
  attr :weather_error, :string, default: nil
  attr :weather_loading, :boolean, default: false
  attr :weather_chart, :map, required: true
  attr :weather_query, :string, default: ""
  attr :weather_city, :string, default: ""

  @doc """
  Renders the Chyllz account dashboard grid (main column + weather sidebar).
  """
  def account_dashboard(assigns) do
    ~H"""
    <div
      id="chyllz-account"
      class="grid grid-cols-1 items-start gap-5 md:gap-6 xl:grid-cols-[minmax(0,1fr)_384px]"
    >
      <%!-- ─────────────────────────── Main column ─────────────────────────── --%>
      <div class="min-w-0 space-y-5 md:space-y-6">
        <%!-- Greeting card --%>
        <section
          id="chyllz-welcome"
          class="relative overflow-hidden rounded-[26px] border border-slate-100 bg-white p-5 shadow-[0_1px_2px_rgba(15,23,42,0.04)] md:p-7"
        >
          <div
            class="pointer-events-none absolute -right-12 -top-16 h-44 w-44 rounded-full bg-orange-50/80 blur-2xl"
            aria-hidden="true"
          >
          </div>
          <div
            class="pointer-events-none absolute -bottom-20 left-24 h-40 w-40 rounded-full bg-amber-50/70 blur-2xl"
            aria-hidden="true"
          >
          </div>

          <div class="relative grid grid-cols-1 items-center gap-6 md:grid-cols-[auto_minmax(0,1fr)] xl:grid-cols-[auto_minmax(0,1fr)_auto]">
            <%!-- Photo collage --%>
            <div
              class="relative mx-auto hidden h-[152px] w-[172px] shrink-0 md:block"
              aria-hidden="true"
            >
              <div class="absolute inset-0 -rotate-6 rounded-[22px] bg-orange-50"></div>
              <div class="absolute left-1.5 top-1.5 h-full w-full rotate-[6deg] rounded-[20px] border border-orange-100 bg-white/70">
              </div>
              <div class="absolute left-1/2 top-1/2 w-[150px] -translate-x-1/2 -translate-y-1/2 -rotate-[7deg] rounded-xl bg-white p-1.5 shadow-xl ring-1 ring-slate-100">
                <img
                  src="/images/chyllz_account_hero.webp"
                  alt=""
                  width="600"
                  height="450"
                  loading="eager"
                  decoding="async"
                  class="h-[118px] w-full rounded-lg object-cover"
                />
                <div class="mt-1 flex items-center justify-between px-0.5 pb-0.5">
                  <span class="text-[7px] font-black uppercase tracking-[0.18em] text-slate-400">
                    Chyllz travels
                  </span>
                  <span class="h-1.5 w-1.5 rounded-full bg-[#FF4C00]"></span>
                </div>
              </div>
              <div class="absolute -bottom-2 -right-1 grid h-10 w-10 place-items-center rounded-full border-2 border-white bg-[#FF4C00] text-white shadow-lg">
                <.ui_icon name={:compass} class="h-5 w-5" />
              </div>
            </div>

            <%!-- Greeting + actions --%>
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <span class="inline-flex items-center gap-1.5 rounded-full bg-orange-50 px-2.5 py-1 text-[9px] font-black uppercase tracking-[0.18em] text-[#FF4C00]">
                  <.ui_icon name={:sparkles} class="h-3 w-3" /> Chyllz account
                </span>
                <%= if @member_since do %>
                  <span class="inline-flex items-center gap-1.5 rounded-full bg-slate-50 px-2.5 py-1 text-[9px] font-black uppercase tracking-[0.18em] text-slate-400">
                    Member since {@member_since}
                  </span>
                <% end %>
              </div>

              <h1 class="mt-3 text-2xl font-black leading-tight tracking-tight md:text-[28px] 2xl:text-[32px]">
                Welcome back, {first_name(@user)}!
              </h1>
              <p class="mt-2 max-w-md text-sm font-bold leading-relaxed text-slate-400">
                Ready to explore the world? Plan your next adventure or manage your trips.
              </p>
            </div>

            <%!-- Hand-lettered tagline --%>
            <div
              class="relative hidden w-[176px] shrink-0 select-none xl:block"
              aria-hidden="true"
            >
              <svg viewBox="0 0 230 102" class="h-[92px] w-[196px]" fill="none">
                <path
                  d="M6 68c30-46 62 22 96-16 22-25 46-26 74-8 16 10 26 26 30 44"
                  stroke="#FF4C00"
                  stroke-width="2"
                  stroke-dasharray="5 7"
                  stroke-linecap="round"
                  opacity="0.7"
                />
                <circle cx="6" cy="68" r="4" fill="#FF4C00" />
                <path d="m206 80 14 8-16 4 4-6z" fill="#FF4C00" opacity="0.9" />
                <text
                  x="12"
                  y="38"
                  font-family="'Segoe Script','Brush Script MT','Bradley Hand',cursive"
                  font-size="26"
                  font-weight="700"
                  fill="#0F172A"
                >
                  New places,
                </text>
                <text
                  x="34"
                  y="74"
                  font-family="'Segoe Script','Brush Script MT','Bradley Hand',cursive"
                  font-size="26"
                  font-weight="700"
                  fill="#FF4C00"
                  transform="rotate(-5 34 74)"
                >
                  New stories
                </text>
              </svg>
            </div>
          </div>

          <div
            id="chyllz-hero-actions"
            class="relative mt-5 flex flex-col gap-2.5 sm:flex-row sm:flex-wrap sm:items-center"
          >
            <a
              id="build-with-ai"
              href="/ai-trip-builder"
              class="inline-flex w-full items-center justify-center gap-2 rounded-full bg-[#FF4C00] px-5 py-3 text-[10px] font-black uppercase tracking-widest text-white shadow-lg shadow-orange-500/20 transition-all hover:-translate-y-0.5 hover:bg-[#E64400] hover:shadow-xl sm:w-auto"
            >
              <.ui_icon name={:sparkles} class="h-4 w-4" /> Build with AI
            </a>
            <a
              id="create-new-trip"
              href="/tour-packages"
              class="inline-flex w-full items-center justify-center gap-2 rounded-full border-2 border-[#FF4C00] bg-orange-50 px-5 py-3 text-[10px] font-black uppercase tracking-widest text-[#FF4C00] transition-all hover:-translate-y-0.5 hover:bg-[#FF4C00] hover:text-white sm:w-auto"
            >
              <.ui_icon name={:compass} class="h-4 w-4" /> Create New Trip
            </a>
            <a
              id="view-my-trips"
              href="/dashboard"
              class="inline-flex w-full items-center justify-center gap-2 rounded-full border border-slate-200 bg-white px-5 py-3 text-[10px] font-black uppercase tracking-widest text-slate-700 transition-all hover:-translate-y-0.5 hover:border-[#FF4C00] hover:text-[#FF4C00] sm:w-auto"
            >
              <.ui_icon name={:ticket} class="h-4 w-4" /> View My Trips
            </a>
          </div>
        </section>

        <%!-- Counters --%>
        <div class="grid grid-cols-1 gap-3.5 sm:grid-cols-3 md:gap-4">
          <a
            id="stat-total-trips"
            href="/dashboard"
            class="group flex items-center gap-4 rounded-[22px] border border-slate-100 bg-white p-4 shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition-all hover:-translate-y-0.5 hover:border-orange-200 hover:shadow-lg"
          >
            <span class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-orange-50 text-[#FF4C00]">
              <.ui_icon name={:route} class="h-6 w-6" />
            </span>
            <span class="min-w-0 flex-1">
              <span
                id="stat-total-trips-value"
                class="block text-2xl font-black tabular-nums tracking-tight text-slate-900"
              >
                {@overview.stats.trips}
              </span>
              <span class="block text-[10px] font-black uppercase tracking-[0.16em] text-slate-400">
                Total Trips
              </span>
            </span>
            <span class="shrink-0 text-slate-300 transition-colors group-hover:text-[#FF4C00]">
              <.ui_icon name={:chevron_right} class="h-4 w-4" />
            </span>
          </a>

          <a
            id="stat-upcoming-trips"
            href="/dashboard"
            class="group flex items-center gap-4 rounded-[22px] border border-slate-100 bg-white p-4 shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition-all hover:-translate-y-0.5 hover:border-orange-200 hover:shadow-lg"
          >
            <span class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-orange-50 text-[#FF4C00]">
              <.ui_icon name={:calendar} class="h-6 w-6" />
            </span>
            <span class="min-w-0 flex-1">
              <span
                id="stat-upcoming-trips-value"
                class="block text-2xl font-black tabular-nums tracking-tight text-slate-900"
              >
                {@overview.stats.upcoming}
              </span>
              <span class="block text-[10px] font-black uppercase tracking-[0.16em] text-slate-400">
                Upcoming Trips
              </span>
            </span>
            <span class="shrink-0 text-slate-300 transition-colors group-hover:text-[#FF4C00]">
              <.ui_icon name={:chevron_right} class="h-4 w-4" />
            </span>
          </a>

          <a
            id="stat-places-visited"
            href="/tour-packages"
            class="group flex items-center gap-4 rounded-[22px] border border-slate-100 bg-white p-4 shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition-all hover:-translate-y-0.5 hover:border-orange-200 hover:shadow-lg"
          >
            <span class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-orange-50 text-[#FF4C00]">
              <.ui_icon name={:pin} class="h-6 w-6" />
            </span>
            <span class="min-w-0 flex-1">
              <span
                id="stat-places-visited-value"
                class="block text-2xl font-black tabular-nums tracking-tight text-slate-900"
              >
                {@overview.stats.places_visited}
              </span>
              <span class="block text-[10px] font-black uppercase tracking-[0.16em] text-slate-400">
                Places Visited
              </span>
            </span>
            <span class="shrink-0 text-slate-300 transition-colors group-hover:text-[#FF4C00]">
              <.ui_icon name={:chevron_right} class="h-4 w-4" />
            </span>
          </a>
        </div>

        <%!-- Hotel / accommodation bookings --%>
        <section id="hotel-bookings" aria-labelledby="hotel-bookings-heading">
          <div class="mb-3.5 flex items-center justify-between gap-3 px-1">
            <h2
              id="hotel-bookings-heading"
              class="flex items-center gap-2.5 text-lg font-black tracking-tight text-slate-900"
            >
              <span class="grid h-8 w-8 place-items-center rounded-full bg-orange-50 text-[#FF4C00]">
                <.ui_icon name={:bag} class="h-4 w-4" />
              </span>
              Your Stays
            </h2>
            <a
              id="view-chyllz-stays"
              href="/tour-packages/hotels"
              class="inline-flex items-center gap-1.5 text-[10px] font-black uppercase tracking-[0.16em] text-[#FF4C00] transition hover:underline"
            >
              Book a stay <.ui_icon name={:arrow_right} class="h-3.5 w-3.5" />
            </a>
          </div>

          <div id="hotel-bookings-list" class="space-y-3.5">
            <%= if @hotel_bookings == [] do %>
              <div
                id="no-hotel-bookings"
                class="flex flex-col items-center gap-4 rounded-[24px] border border-dashed border-slate-200 bg-white p-6 text-center sm:flex-row sm:text-left"
              >
                <span class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-orange-50 text-[#FF4C00]">
                  <.ui_icon name={:bag} class="h-6 w-6" />
                </span>
                <div class="min-w-0 flex-1">
                  <h3 class="text-base font-black text-slate-900">No accommodation bookings yet</h3>
                  <p class="mt-1 text-xs font-bold leading-relaxed text-slate-400">
                    Reserve a hotel through Chyllz and every stay will appear here.
                  </p>
                </div>
              </div>
            <% else %>
              <%= for booking <- @hotel_bookings do %>
                <article
                  id={"hotel-booking-#{booking.reference}"}
                  class="rounded-[24px] border border-slate-100 bg-white p-5 shadow-[0_1px_2px_rgba(15,23,42,0.04)]"
                >
                  <div class="flex flex-wrap items-start justify-between gap-3">
                    <div class="min-w-0">
                      <p class="text-[10px] font-black uppercase tracking-[0.18em] text-[#FF4C00]">
                        {booking.reference}
                      </p>
                      <h3 class="mt-1 text-base font-black text-slate-900">{booking.hotel_name}</h3>
                      <p class="mt-1 flex items-center gap-1 text-xs font-bold text-slate-400">
                        <.ui_icon name={:pin} class="h-3.5 w-3.5" />
                        {booking.hotel_location || "Location shared on confirmation"}
                      </p>
                    </div>

                    <span class={[
                      "rounded-full px-3 py-1 text-[10px] font-black uppercase tracking-widest",
                      booking.status == "confirmed" && "bg-emerald-50 text-emerald-600",
                      booking.status == "pending" && "bg-amber-50 text-amber-600",
                      booking.status == "cancelled" && "bg-red-50 text-red-600",
                      booking.status == "completed" && "bg-slate-100 text-slate-500"
                    ]}>
                      {booking.status}
                    </span>
                  </div>

                  <dl class="mt-4 grid grid-cols-2 gap-3 border-t border-slate-50 pt-4 sm:grid-cols-4">
                    <div>
                      <dt class="text-[9px] font-black uppercase tracking-widest text-slate-400">
                        Check-in
                      </dt>
                      <dd class="mt-0.5 text-xs font-black text-slate-800">
                        {short_date(booking.check_in)}
                      </dd>
                    </div>
                    <div>
                      <dt class="text-[9px] font-black uppercase tracking-widest text-slate-400">
                        Check-out
                      </dt>
                      <dd class="mt-0.5 text-xs font-black text-slate-800">
                        {short_date(booking.check_out)}
                      </dd>
                    </div>
                    <div>
                      <dt class="text-[9px] font-black uppercase tracking-widest text-slate-400">
                        Stay
                      </dt>
                      <dd class="mt-0.5 text-xs font-black text-slate-800">
                        {booking.nights} night{if booking.nights == 1, do: "", else: "s"} · {booking.rooms} room{if booking.rooms ==
                                                                                                                      1,
                                                                                                                    do:
                                                                                                                      "",
                                                                                                                    else:
                                                                                                                      "s"}
                      </dd>
                    </div>
                    <div>
                      <dt class="text-[9px] font-black uppercase tracking-widest text-slate-400">
                        Total
                      </dt>
                      <dd class="mt-0.5 text-xs font-black text-[#FF4C00]">
                        KES {money(booking.total_amount)}
                      </dd>
                    </div>
                  </dl>
                </article>
              <% end %>
            <% end %>
          </div>
        </section>

        <%!-- Recent trips --%>
        <section aria-labelledby="recent-trips-heading">
          <div class="mb-3.5 flex items-center justify-between gap-3 px-1">
            <h2
              id="recent-trips-heading"
              class="flex items-center gap-2.5 text-lg font-black tracking-tight text-slate-900"
            >
              <span class="grid h-8 w-8 place-items-center rounded-full bg-orange-50 text-[#FF4C00]">
                <.ui_icon name={:route} class="h-4 w-4" />
              </span>
              Recent Trips
            </h2>
            <a
              id="view-all-trips"
              href="/dashboard"
              class="inline-flex items-center gap-1.5 text-[10px] font-black uppercase tracking-[0.16em] text-[#FF4C00] transition hover:underline"
            >
              View All Trips <.ui_icon name={:arrow_right} class="h-3.5 w-3.5" />
            </a>
          </div>

          <div id="recent-trips" class="space-y-3.5">
            <%= if @trips == [] do %>
              <div
                id="no-trips"
                class="flex flex-col items-center gap-4 rounded-[24px] border border-dashed border-slate-200 bg-white p-6 text-center sm:flex-row sm:items-center sm:text-left"
              >
                <span class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-orange-50 text-[#FF4C00]">
                  <.ui_icon name={:bag} class="h-6 w-6" />
                </span>
                <div class="min-w-0 flex-1">
                  <h3 class="text-base font-black text-slate-900">No trips yet</h3>
                  <p class="mt-1 text-xs font-bold leading-relaxed text-slate-400">
                    Book a bus or plan a Chyllz escape and your journeys will appear here.
                  </p>
                </div>
                <div class="flex shrink-0 flex-wrap justify-center gap-2">
                  <a
                    href="/"
                    class="rounded-full bg-[#FF4C00] px-5 py-2.5 text-[10px] font-black uppercase tracking-widest text-white transition hover:bg-[#E64400]"
                  >
                    Book a bus
                  </a>
                  <a
                    href="/tour-packages"
                    class="rounded-full border border-slate-200 px-5 py-2.5 text-[10px] font-black uppercase tracking-widest text-slate-700 transition hover:border-[#FF4C00] hover:text-[#FF4C00]"
                  >
                    Explore Chyllz
                  </a>
                </div>
              </div>
            <% else %>
              <%= for trip <- @trips do %>
                <article
                  id={"trip-card-" <> to_string(trip.id)}
                  class="group grid grid-cols-1 overflow-hidden rounded-[24px] border border-slate-100 bg-white shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition-all hover:-translate-y-0.5 hover:border-orange-100 hover:shadow-lg sm:grid-cols-[164px_minmax(0,1fr)]"
                >
                  <div class="relative h-36 overflow-hidden sm:h-auto sm:min-h-[156px]">
                    <.trip_art variant={trip.art} tag={trip.id} />
                    <span class="absolute left-3 top-3 inline-flex items-center gap-1 rounded-full bg-white/90 px-2.5 py-1 text-[9px] font-black uppercase tracking-widest text-slate-700 shadow-sm backdrop-blur">
                      {trip.company}
                    </span>
                  </div>

                  <div class="min-w-0 p-4 md:p-5">
                    <div class="flex items-start justify-between gap-3">
                      <div class="min-w-0">
                        <h3 class="truncate text-base font-black tracking-tight text-slate-900 md:text-lg">
                          {trip.title}
                        </h3>
                        <p class="mt-1 flex items-center gap-1.5 text-[11px] font-bold text-slate-400">
                          <.ui_icon name={:pin} class="h-3.5 w-3.5 shrink-0 text-[#FF4C00]" />
                          <span class="truncate">{trip.location}</span>
                        </p>
                      </div>
                      <span class={[
                        "inline-flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest",
                        status_badge_class(trip.status_key)
                      ]}>
                        {trip.status}
                      </span>
                    </div>

                    <div class="mt-3.5 grid grid-cols-1 gap-2 sm:grid-cols-3">
                      <%= for {icon, label, value} <- [
                            {:calendar, "Travel Date", trip.travel_date},
                            {:clock, "Departs", trip.departure},
                            {:wallet, "Fare", trip.fare}
                          ] do %>
                        <div class="flex items-center gap-2 rounded-xl border border-slate-100 bg-slate-50/70 px-2.5 py-2">
                          <span class="text-[#FF4C00]">
                            <.ui_icon name={icon} class="h-3.5 w-3.5" />
                          </span>
                          <span class="min-w-0">
                            <span class="block text-[8px] font-black uppercase tracking-[0.14em] text-slate-400">
                              {label}
                            </span>
                            <span class="block truncate text-[10px] font-black text-slate-700">
                              {value}
                            </span>
                          </span>
                        </div>
                      <% end %>
                    </div>

                    <div class="mt-3.5 flex items-center gap-2">
                      <a
                        href={trip.href}
                        id={"manage-itinerary-" <> to_string(trip.id)}
                        class="flex min-w-0 flex-1 items-center justify-center gap-2 rounded-xl border border-orange-200 bg-orange-50 px-4 py-2.5 text-[11px] font-black text-[#FF4C00] transition hover:border-orange-300 hover:bg-orange-100"
                      >
                        <.ui_icon name={:list} class="h-4 w-4 shrink-0" /> Manage Itinerary
                      </a>
                      <button
                        type="button"
                        id={"preview-trip-" <> to_string(trip.id)}
                        phx-click="view_ticket"
                        phx-value-ticket_id={trip.id}
                        aria-label={"Preview itinerary for " <> to_string(trip.title)}
                        title="Preview itinerary"
                        class="grid h-10 w-10 shrink-0 place-items-center rounded-xl border border-orange-100 bg-white text-[#FF4C00] transition hover:border-orange-300 hover:bg-orange-50"
                      >
                        <.ui_icon name={:eye} class="h-4 w-4" />
                      </button>
                      <button
                        type="button"
                        id={"share-trip-" <> to_string(trip.id)}
                        phx-click="share_trip"
                        phx-value-url={trip.href}
                        phx-value-title={trip.title}
                        aria-label={"Share trip " <> to_string(trip.title)}
                        title="Share itinerary"
                        class="grid h-10 w-10 shrink-0 place-items-center rounded-xl border border-orange-100 bg-white text-[#FF4C00] transition hover:border-orange-300 hover:bg-orange-50"
                      >
                        <.ui_icon name={:share} class="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                </article>
              <% end %>
            <% end %>
          </div>
        </section>

        <%!-- Chyllz suggestions for accounts without trip history, so the page
        still feels complete and the columns stay balanced. --%>
        <%= if @trips == [] and @picks != [] do %>
          <section id="chyllz-picks" aria-labelledby="chyllz-picks-heading">
            <div class="mb-3.5 flex items-center justify-between gap-3 px-1">
              <h2
                id="chyllz-picks-heading"
                class="flex items-center gap-2.5 text-lg font-black tracking-tight text-slate-900"
              >
                <span class="grid h-8 w-8 place-items-center rounded-full bg-orange-50 text-[#FF4C00]">
                  <.ui_icon name={:sparkles} class="h-4 w-4" />
                </span>
                Chyllz picks for you
              </h2>
              <a
                id="view-all-picks"
                href="/tour-packages"
                class="inline-flex items-center gap-1.5 text-[10px] font-black uppercase tracking-[0.16em] text-[#FF4C00] transition hover:underline"
              >
                Explore Chyllz <.ui_icon name={:arrow_right} class="h-3.5 w-3.5" />
              </a>
            </div>

            <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <%= for pick <- @picks do %>
                <a
                  id={pick.id}
                  href={pick.href}
                  class="group flex flex-col rounded-[20px] border border-slate-100 bg-white p-4 shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition-all hover:-translate-y-0.5 hover:border-orange-200 hover:shadow-lg"
                >
                  <div class="flex items-center justify-between gap-2">
                    <span class="grid h-10 w-10 shrink-0 place-items-center rounded-2xl bg-orange-50 text-[#FF4C00]">
                      <.ui_icon name={pick.icon} class="h-5 w-5" />
                    </span>
                    <span class="truncate text-[9px] font-black text-[#FF4C00]">{pick.meta}</span>
                  </div>
                  <span class="mt-2.5 block text-[8px] font-black uppercase tracking-[0.16em] text-slate-400">
                    {pick.kind}
                  </span>
                  <span class="mt-1 line-clamp-2 text-xs font-black leading-snug text-slate-900 transition group-hover:text-[#FF4C00]">
                    {pick.title}
                  </span>
                  <span class="mt-auto flex items-center justify-between gap-2 pt-2.5 text-[10px] font-bold text-slate-400">
                    <span class="truncate">{pick.location}</span>
                    <span class="grid h-6 w-6 shrink-0 place-items-center rounded-full bg-slate-50 text-slate-300 transition group-hover:bg-[#FF4C00] group-hover:text-white">
                      <.ui_icon name={:chevron_right} class="h-3 w-3" />
                    </span>
                  </span>
                </a>
              <% end %>
            </div>
          </section>
        <% end %>

        <%!-- Travel stories from the curated blog. Rendered for accounts without
        trips so the main column matches the height of the weather sidebar. --%>
        <%= if @trips == [] and @story_cards != [] do %>
          <section id="chyllz-stories" aria-labelledby="chyllz-stories-heading">
            <div class="mb-3.5 flex items-center justify-between gap-3 px-1">
              <h2
                id="chyllz-stories-heading"
                class="flex items-center gap-2.5 text-lg font-black tracking-tight text-slate-900"
              >
                <span class="grid h-8 w-8 place-items-center rounded-full bg-orange-50 text-[#FF4C00]">
                  <.ui_icon name={:map} class="h-4 w-4" />
                </span>
                Travel stories
              </h2>
              <a
                id="view-all-stories"
                href="/blog"
                class="inline-flex items-center gap-1.5 text-[10px] font-black uppercase tracking-[0.16em] text-[#FF4C00] transition hover:underline"
              >
                Read all <.ui_icon name={:arrow_right} class="h-3.5 w-3.5" />
              </a>
            </div>

            <div class="grid grid-cols-1 gap-3 sm:grid-cols-3">
              <%= for story <- @story_cards do %>
                <a
                  id={story.id}
                  href={story.href}
                  class="group flex flex-col rounded-[20px] border border-slate-100 bg-white p-4 shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition-all hover:-translate-y-0.5 hover:border-orange-200 hover:shadow-lg"
                >
                  <span class="inline-flex w-fit items-center rounded-full bg-orange-50 px-2 py-1 text-[8px] font-black uppercase tracking-[0.14em] text-[#FF4C00]">
                    {story.category}
                  </span>
                  <span class="mt-2 line-clamp-2 text-xs font-black leading-snug text-slate-900 transition group-hover:text-[#FF4C00]">
                    {story.title}
                  </span>
                  <span class="mt-auto flex items-center justify-between pt-3 text-[9px] font-black uppercase tracking-[0.14em] text-slate-400">
                    {story.read_minutes} min read <.ui_icon name={:arrow_right} class="h-3 w-3" />
                  </span>
                </a>
              <% end %>
            </div>
          </section>
        <% end %>
      </div>

      <%!-- ─────────────────────────── Sidebar ─────────────────────────── --%>
      <aside class="min-w-0 space-y-5 md:space-y-6">
        <%!-- Weather --%>
        <section
          id="weather-card"
          class="overflow-hidden rounded-[26px] border border-slate-100 bg-white p-5 shadow-[0_1px_2px_rgba(15,23,42,0.04)]"
          aria-labelledby="weather-heading"
        >
          <div class="flex items-center justify-between gap-3">
            <h2
              id="weather-heading"
              class="flex items-center gap-2 text-sm font-black tracking-tight text-slate-900"
            >
              <span class="grid h-8 w-8 place-items-center rounded-xl bg-orange-50 text-[#FF4C00]">
                <.weather_glyph icon={:clear} class="h-4 w-4" />
              </span>
              Weather
            </h2>
            <p
              id="weather-location"
              class="flex min-w-0 items-center gap-1 text-[10px] font-black uppercase tracking-[0.14em] text-slate-400"
            >
              <.ui_icon name={:pin} class="h-3.5 w-3.5 shrink-0 text-[#FF4C00]" />
              <%= if @weather do %>
                <span class="truncate">{location_label(@weather.location)}</span>
              <% else %>
                <span class="truncate">{@weather_city}</span>
              <% end %>
            </p>
          </div>

          <form
            id="weather-search-form"
            phx-submit="search_weather"
            class="mt-4 flex items-center gap-2"
          >
            <div class="relative min-w-0 flex-1">
              <span class="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-300">
                <.ui_icon name={:search} class="h-3.5 w-3.5" />
              </span>
              <input
                id="weather-city-input"
                type="search"
                name="city"
                value={@weather_query}
                placeholder="Search any city..."
                aria-label="Search the weather for a city"
                autocomplete="off"
                class="h-10 w-full rounded-full border border-slate-200 bg-white pl-9 pr-3 text-[11px] font-bold text-slate-700 outline-none transition placeholder:text-slate-300 focus:border-[#FF4C00] focus:ring-2 focus:ring-orange-100"
              />
            </div>
            <button
              type="submit"
              id="weather-search-button"
              class="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-[#FF4C00] text-white shadow-lg shadow-orange-500/20 transition hover:bg-[#E64400] active:scale-95"
              aria-label="Search weather"
            >
              <.ui_icon name={:search} class="h-4 w-4" />
            </button>
          </form>

          <%= cond do %>
            <% @weather_loading -> %>
              <div
                id="weather-loading"
                class="mt-4 animate-pulse space-y-3"
                aria-hidden="true"
              >
                <div class="flex items-center gap-4 rounded-2xl bg-slate-50 p-4">
                  <div class="h-14 w-14 rounded-2xl bg-slate-100"></div>
                  <div class="flex-1 space-y-2">
                    <div class="h-6 w-24 rounded-full bg-slate-100"></div>
                    <div class="h-2.5 w-16 rounded-full bg-slate-100"></div>
                  </div>
                  <div class="h-8 w-16 rounded-xl bg-slate-100"></div>
                </div>
                <div class="h-2.5 w-28 rounded-full bg-slate-100"></div>
                <div class="h-[64px] rounded-2xl bg-slate-100"></div>
                <div class="grid grid-cols-3 gap-2">
                  <div :for={_index <- 1..3} class="h-16 rounded-xl bg-slate-100"></div>
                </div>
              </div>
            <% @weather -> %>
              <div class="mt-4">
                <div class="flex items-center gap-4 rounded-2xl bg-gradient-to-br from-orange-50 to-amber-50/40 p-4">
                  <div class="grid h-14 w-14 shrink-0 place-items-center rounded-2xl bg-white text-slate-400 shadow-sm">
                    <.weather_glyph icon={@weather.icon} class="h-9 w-9" />
                  </div>
                  <div class="min-w-0">
                    <div
                      id="weather-current"
                      class="text-[32px] font-black leading-none tracking-tighter tabular-nums text-slate-900"
                    >
                      {temperature_label(@weather.temperature)}
                    </div>
                    <div class="mt-1 truncate text-[10px] font-black uppercase tracking-[0.16em] text-slate-400">
                      {@weather.condition}
                    </div>
                  </div>
                  <div class="ml-auto shrink-0 text-right">
                    <div class="text-[11px] font-black tabular-nums text-slate-600">
                      H: {degree(@weather.high)} L: {degree(@weather.low)}
                    </div>
                    <div class="mt-0.5 text-[10px] font-bold text-slate-400">
                      Feels like {degree(@weather.feels_like)}
                    </div>
                  </div>
                </div>

                <div class="mt-3 grid grid-cols-2 gap-2.5">
                  <div class="flex items-center gap-2.5 rounded-xl bg-slate-50 px-3 py-2.5">
                    <span class="grid h-7 w-7 place-items-center rounded-lg bg-white text-[#FF4C00] shadow-sm">
                      <.ui_icon name={:drop} class="h-3.5 w-3.5" />
                    </span>
                    <span>
                      <span class="block text-[8px] font-black uppercase tracking-[0.14em] text-slate-400">
                        Humidity
                      </span>
                      <span class="block text-[11px] font-black tabular-nums text-slate-900">
                        {percent_label(@weather.humidity)}
                      </span>
                    </span>
                  </div>
                  <div class="flex items-center gap-2.5 rounded-xl bg-slate-50 px-3 py-2.5">
                    <span class="grid h-7 w-7 place-items-center rounded-lg bg-white text-[#FF4C00] shadow-sm">
                      <.ui_icon name={:wind} class="h-3.5 w-3.5" />
                    </span>
                    <span>
                      <span class="block text-[8px] font-black uppercase tracking-[0.14em] text-slate-400">
                        Wind
                      </span>
                      <span class="block text-[11px] font-black tabular-nums text-slate-900">
                        {wind_label(@weather.wind)}
                      </span>
                    </span>
                  </div>
                </div>

                <div class="mt-4">
                  <div class="flex items-center justify-between">
                    <h3 class="flex items-center gap-1.5 text-[10px] font-black uppercase tracking-[0.14em] text-slate-400">
                      <.ui_icon name={:clock} class="h-3.5 w-3.5 text-[#FF4C00]" /> Hourly Temperature
                    </h3>
                  </div>
                  <div class="mt-2.5 rounded-2xl border border-slate-100 bg-white p-3">
                    <svg
                      viewBox="0 0 300 90"
                      class="h-[62px] w-full"
                      preserveAspectRatio="none"
                      aria-hidden="true"
                    >
                      <defs>
                        <linearGradient id="weather-spark" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0" stop-color="#FF4C00" stop-opacity="0.22" />
                          <stop offset="1" stop-color="#FF4C00" stop-opacity="0" />
                        </linearGradient>
                      </defs>
                      <polygon points={@weather_chart.area} fill="url(#weather-spark)" />
                      <polyline
                        points={@weather_chart.line}
                        fill="none"
                        stroke="#FF4C00"
                        stroke-width="2.6"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                      />
                      <%= for {x, y, _label, _temperature} <- @weather_chart.points do %>
                        <circle
                          cx={x}
                          cy={y}
                          r="3"
                          fill="#ffffff"
                          stroke="#FF4C00"
                          stroke-width="2"
                        />
                      <% end %>
                    </svg>
                    <div
                      id="weather-hourly"
                      class="mt-1 grid gap-1"
                      style={"grid-template-columns: repeat(#{hourly_columns(length(@weather.hourly))}, minmax(0, 1fr))"}
                    >
                      <%= for hour <- trend_hours(@weather.hourly) do %>
                        <div class="text-center">
                          <div class="text-[8px] font-bold text-slate-400">{hour.label}</div>
                          <div class="text-[10px] font-black tabular-nums text-slate-900">
                            {trend_temperature(hour.temperature)}
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>

                <div class="mt-4 border-t border-slate-100 pt-4">
                  <h3 class="flex items-center gap-1.5 text-[10px] font-black uppercase tracking-[0.14em] text-slate-400">
                    <.ui_icon name={:calendar} class="h-3.5 w-3.5 text-[#FF4C00]" /> 3-Day Forecast
                  </h3>
                  <div id="weather-daily" class="mt-2.5 grid grid-cols-3 gap-2">
                    <%= for day <- @weather.daily do %>
                      <div class="flex flex-col items-center gap-1.5 rounded-2xl bg-slate-50/80 px-2 py-3 text-center">
                        <span class="text-[9px] font-black uppercase tracking-[0.16em] text-slate-400">
                          {day.label}
                        </span>
                        <span class="text-slate-400">
                          <.weather_glyph icon={day.icon} class="h-8 w-8" />
                        </span>
                        <span class="text-[11px] font-black tabular-nums text-slate-900">
                          {degree(day.low)}
                          <span class="font-bold text-slate-400">/ {degree(day.high)}</span>
                        </span>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% true -> %>
              <div
                id="weather-unavailable"
                class="mt-4 rounded-2xl border border-dashed border-slate-200 bg-slate-50/70 p-5 text-center"
              >
                <div class="mx-auto grid h-12 w-12 place-items-center rounded-2xl bg-white text-[#FF4C00] shadow-sm">
                  <.weather_glyph icon={:cloud} class="h-7 w-7" />
                </div>
                <p class="mt-3 text-xs font-black text-slate-700">Weather unavailable</p>
                <p class="mt-1 text-[11px] font-bold leading-relaxed text-slate-400">
                  {@weather_error}
                </p>
                <button
                  type="button"
                  id="weather-retry"
                  phx-click="refresh_weather"
                  class="mt-3 inline-flex items-center gap-1.5 rounded-full bg-[#FF4C00] px-4 py-2 text-[10px] font-black uppercase tracking-widest text-white transition hover:bg-[#E64400]"
                >
                  <.ui_icon name={:refresh} class="h-3.5 w-3.5" /> Try again
                </button>
              </div>
          <% end %>
        </section>

        <%!-- Popular destinations --%>
        <section
          class="rounded-[26px] border border-slate-100 bg-white p-5 shadow-[0_1px_2px_rgba(15,23,42,0.04)]"
          aria-labelledby="popular-destinations-heading"
        >
          <h2
            id="popular-destinations-heading"
            class="flex items-center gap-2 text-sm font-black tracking-tight text-slate-900"
          >
            <span class="grid h-8 w-8 place-items-center rounded-xl bg-orange-50 text-[#FF4C00]">
              <.ui_icon name={:map} class="h-4 w-4" />
            </span>
            Popular Destinations
          </h2>

          <div id="popular-destinations" class="mt-4 flex flex-wrap gap-2">
            <%= for destination <- @overview.destinations do %>
              <a
                href={destination.search_url}
                class="destination-chip inline-flex items-center gap-1.5 rounded-full border border-slate-100 bg-white px-3.5 py-2 text-[11px] font-black text-slate-600 transition-all hover:-translate-y-0.5 hover:border-[#FF4C00] hover:bg-orange-50 hover:text-[#FF4C00]"
              >
                {destination.name}
              </a>
            <% end %>
          </div>

          <div class="mt-4 space-y-2.5 border-t border-slate-100 pt-4">
            <a
              href="/tour-packages"
              class="flex items-center justify-between gap-3 text-[10px] font-black uppercase tracking-[0.16em] text-slate-500 transition hover:text-[#FF4C00]"
            >
              Explore Chyllz stays <.ui_icon name={:arrow_right} class="h-3.5 w-3.5" />
            </a>
            <a
              href="/blog"
              class="flex items-center justify-between gap-3 text-[10px] font-black uppercase tracking-[0.16em] text-slate-500 transition hover:text-[#FF4C00]"
            >
              Read {@overview.stories} travel stories
              <.ui_icon name={:arrow_right} class="h-3.5 w-3.5" />
            </a>
          </div>
        </section>
      </aside>
    </div>
    """
  end

  # ------------------------------------------------------ presentation helpers

  @doc "An empty sparkline, used while the weather is loading or unavailable."
  def empty_chart, do: %{line: nil, area: nil, points: []}

  @doc """
  Turns hourly temperatures into a 300x90 sparkline (polyline points + filled
  area). Returns an empty chart when there is not enough data.
  """
  def chart_for(hourly) when is_list(hourly) do
    points = Enum.filter(hourly, &is_number(&1.temperature))

    if length(points) < 2 do
      empty_chart()
    else
      temps = Enum.map(points, & &1.temperature)
      max = Enum.max(temps)
      min = Enum.min(temps)
      span = max - min
      count = length(points)
      step = 300 / max(count - 1, 1)

      plotted =
        points
        |> Enum.with_index()
        |> Enum.map(fn {%{label: label, temperature: temperature}, index} ->
          x = Float.round(index * step, 2)

          y =
            if span == 0 do
              48.0
            else
              Float.round(76 - (temperature - min) / span * 54, 2)
            end

          {x, y, label, temperature}
        end)

      line = plotted |> Enum.map(fn {x, y, _label, _temp} -> "#{x},#{y}" end) |> Enum.join(" ")

      %{line: line, area: "0,90 " <> line <> " 300,90", points: plotted}
    end
  end

  def chart_for(_hourly), do: empty_chart()

  @doc "Normalises a city typed into the weather search box."
  def normalize_city(city) do
    city
    |> to_string()
    |> String.replace(~r/[\r\n\t]/, " ")
    |> String.trim()
    |> String.slice(0, @city_max_length)
  end

  @doc "A friendly message for every weather failure reason."
  def weather_error_message(:disabled), do: "Live weather is unavailable right now."
  def weather_error_message(:empty_query), do: "Type a city name to see its weather."

  def weather_error_message(:not_found),
    do: "We couldn't find that city. Check the spelling and try again."

  def weather_error_message(:timeout),
    do: "The weather service took too long to respond. Please try again."

  def weather_error_message({:http_status, _status}),
    do: "The weather service is unavailable right now. Please try again shortly."

  def weather_error_message(_reason),
    do: "Weather is unavailable right now. Please try again shortly."

  @doc "The \"Member since Month Year\" label for the greeting card."
  def member_since(%{inserted_at: nil}), do: nil

  def member_since(%{inserted_at: %DateTime{} = inserted_at}),
    do: Calendar.strftime(inserted_at, "%B %Y")

  def member_since(%{inserted_at: %NaiveDateTime{} = inserted_at}),
    do: Calendar.strftime(inserted_at, "%B %Y")

  def member_since(_user), do: nil

  # ------------------------------------------------------------ private helpers

  defp first_name(%{name: name}) when is_binary(name) do
    case String.split(name, ~r/\s+/, trim: true) do
      [first | _rest] -> String.capitalize(first)
      _empty -> "Traveller"
    end
  end

  defp first_name(_user), do: "Traveller"

  defp status_badge_class(:ongoing), do: "bg-orange-50 text-[#FF4C00] ring-1 ring-orange-100"

  defp status_badge_class(:upcoming),
    do: "bg-white text-slate-600 ring-1 ring-slate-200"

  defp status_badge_class(:completed),
    do: "bg-emerald-50 text-emerald-600 ring-1 ring-emerald-100"

  defp status_badge_class(:cancelled), do: "bg-red-50 text-red-600 ring-1 ring-red-100"

  defp status_badge_class(_status),
    do: "bg-slate-50 text-slate-500 ring-1 ring-slate-100"

  defp degree(nil), do: "—"
  defp degree(value) when is_number(value), do: "#{round(value)}°"

  defp temperature_label(nil), do: "—"
  defp temperature_label(value) when is_number(value), do: "#{round(value)}°C"

  defp trend_temperature(nil), do: "—"
  defp trend_temperature(value) when is_number(value), do: "#{round(value)}°"

  defp percent_label(nil), do: "—"
  defp percent_label(value) when is_number(value), do: "#{round(value)}%"

  defp location_label(%{name: name} = location) when is_binary(name) do
    case Map.get(location, :country) || Map.get(location, "country") do
      country when is_binary(country) and country != "" -> "#{name}, #{country}"
      _missing -> name
    end
  end

  defp location_label(location) when is_binary(location), do: location
  defp location_label(_location), do: "—"

  defp wind_label(nil), do: "—"
  defp wind_label(value) when is_number(value), do: "#{round(value)} km/h"

  defp hourly_columns(count) when is_integer(count) and count > 0 do
    min(count, @trend_points)
  end

  defp hourly_columns(_count), do: 1

  defp trend_hours(hourly) when is_list(hourly), do: Enum.take(hourly, @trend_points)
  defp trend_hours(_hourly), do: []
end
