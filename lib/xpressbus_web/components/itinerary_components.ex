defmodule XpressbusWeb.ItineraryComponents do
  @moduledoc """
  Trip cards for AI itineraries saved from the Chyllz trip builder.

  The cards are shown on the **My Chyllz** dashboard tab: cover art, travel
  status (upcoming / ongoing / completed), title, destination, dates, duration
  and budget, with actions to reopen or share the itinerary. The palette stays
  Komiuta orange on white/slate cards.
  """

  use XpressbusWeb, :html

  import XpressbusWeb.ChyllzAccountArt

  alias Xpressbus.Itineraries

  attr :itineraries, :list, default: []
  attr :class, :string, default: ""

  @doc "AI itineraries section: a grid of saved-trip cards, or a first-trip prompt."
  def saved_itineraries(assigns) do
    ~H"""
    <section
      id="saved-itineraries"
      class={["mt-6", @class]}
      aria-labelledby="saved-itineraries-heading"
    >
      <div class="mb-3.5 flex items-center justify-between gap-3 px-1">
        <h2
          id="saved-itineraries-heading"
          class="flex items-center gap-2.5 text-lg font-black tracking-tight text-slate-900"
        >
          <span class="grid h-8 w-8 place-items-center rounded-full bg-orange-50 text-[#FF4C00]">
            <.ui_icon name={:sparkles} class="h-4 w-4" />
          </span>
          Itineraries
        </h2>

        <a
          id="plan-new-itinerary"
          href="/trip/build-with-ai"
          class="inline-flex items-center gap-1.5 text-[10px] font-black uppercase tracking-[0.16em] text-[#FF4C00] transition hover:underline"
        >
          Plan a trip <.ui_icon name={:arrow_right} class="h-3.5 w-3.5" />
        </a>
      </div>

      <%= if @itineraries == [] do %>
        <div
          id="no-saved-itineraries"
          class="flex flex-col items-center gap-4 rounded-[24px] border border-dashed border-slate-200 bg-white p-6 text-center sm:flex-row sm:text-left"
        >
          <span class="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-orange-50 text-[#FF4C00]">
            <.ui_icon name={:sparkles} class="h-6 w-6" />
          </span>

          <div class="min-w-0 flex-1">
            <h3 class="text-base font-black text-slate-900">No saved itineraries yet</h3>

            <p class="mt-1 text-xs font-bold leading-relaxed text-slate-400">
              Build a trip with Chyllz AI, then press Save on the itinerary to keep every detail
              here.
            </p>
          </div>

          <a
            id="start-ai-itinerary"
            href="/trip/build-with-ai"
            class="shrink-0 rounded-full bg-[#FF4C00] px-5 py-2.5 text-[10px] font-black uppercase tracking-widest text-white transition hover:bg-[#E64400]"
          >
            Build with AI
          </a>
        </div>
      <% else %>
        <div id="saved-itineraries-grid" class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          <%= for itinerary <- @itineraries do %>
            <.saved_itinerary_card itinerary={itinerary} />
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end

  attr :itinerary, :map, required: true

  @doc "A single saved-itinerary card."
  def saved_itinerary_card(assigns) do
    itinerary = assigns.itinerary
    status = Itineraries.status(itinerary)
    path = Itineraries.path(itinerary)

    assigns =
      assign(assigns,
        status: status,
        status_label: status_label(status),
        status_class: status_class(status),
        status_meta: Itineraries.status_meta(itinerary),
        path: path,
        manage_path: Itineraries.manage_path(itinerary),
        edit_path: Itineraries.edit_path(itinerary),
        share_url: Itineraries.share_url(itinerary),
        art: art_variant(itinerary.art),
        dates: Itineraries.dates_label(itinerary),
        duration: Itineraries.duration_label(itinerary),
        budget: Itineraries.budget_label(itinerary),
        location: Itineraries.city_label(itinerary)
      )

    ~H"""
    <article
      id={"itinerary-card-" <> to_string(@itinerary.id)}
      class="group flex flex-col overflow-hidden rounded-[24px] border border-slate-100 bg-white shadow-[0_1px_2px_rgba(15,23,42,0.04)] transition-all hover:-translate-y-0.5 hover:border-orange-100 hover:shadow-lg"
    >
      <div class="relative h-40 overflow-hidden">
        <.trip_art variant={@art} tag={"itinerary-" <> to_string(@itinerary.id)} />
        <span class="absolute inset-0 bg-gradient-to-t from-slate-950/55 via-transparent to-transparent"></span>
        <span class={[
          "absolute left-3 top-3 inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[9px] font-black uppercase tracking-widest",
          @status_class
        ]}>
          <span class="h-1.5 w-1.5 rounded-full bg-current"></span>{@status_label}
        </span>

        <a
          id={"itinerary-card-menu-" <> to_string(@itinerary.id)}
          href={@path}
          aria-label="Open saved itinerary"
          class="absolute right-3 top-3 grid h-8 w-8 place-items-center rounded-full bg-white/90 text-sm font-black leading-none text-slate-500 shadow-sm backdrop-blur transition hover:text-[#FF4C00]"
        >
          ...
        </a>

        <span class="absolute bottom-3 left-3 inline-flex items-center gap-1 rounded-full bg-slate-950/70 px-2.5 py-1 text-[9px] font-black uppercase tracking-widest text-white backdrop-blur">
          <.ui_icon name={:clock} class="h-3 w-3" /> {@status_meta}
        </span>
      </div>

      <div class="flex flex-1 flex-col p-4">
        <h3 class="line-clamp-2 text-base font-black leading-snug tracking-tight text-slate-900">
          {@itinerary.title}
        </h3>

        <p class="mt-1.5 flex items-center gap-1.5 text-[11px] font-bold text-slate-400">
          <.ui_icon name={:pin} class="h-3.5 w-3.5 shrink-0 text-[#FF4C00]" />
          <span class="truncate">{@location}</span>
        </p>

        <div class="mt-3 grid grid-cols-3 gap-2">
          <%= for {icon, label, value} <- [
                {:calendar, "Dates", @dates},
                {:clock, "Duration", @duration},
                {:wallet, "Budget", @budget}
              ] do %>
            <div class="min-w-0 rounded-xl border border-slate-100 bg-slate-50/70 px-2 py-1.5">
              <span class="flex items-center gap-1 text-[8px] font-black uppercase tracking-[0.12em] text-slate-400">
                <.ui_icon name={icon} class="h-3 w-3 text-[#FF4C00]" /> {label}
              </span>

              <span class="mt-0.5 block truncate text-[10px] font-black text-slate-700">
                {value}
              </span>
            </div>
          <% end %>
        </div>

        <div class="mt-3 flex items-center gap-2">
          <a
            id={"manage-itinerary-" <> to_string(@itinerary.id)}
            href={@manage_path}
            class="inline-flex flex-1 items-center justify-center gap-1.5 rounded-xl border border-orange-200 bg-orange-50 px-3 py-2.5 text-[10px] font-black uppercase tracking-widest text-[#FF4C00] transition hover:bg-[#FF4C00] hover:text-white"
          >
            <.ui_icon name={:list} class="h-3.5 w-3.5" /> Manage Itinerary
          </a>

          <a
            id={"view-itinerary-" <> to_string(@itinerary.id)}
            href={@path}
            target="_blank"
            rel="noopener noreferrer"
            aria-label="View itinerary"
            class="grid h-9 w-9 shrink-0 place-items-center rounded-xl border border-slate-200 text-slate-400 transition hover:border-[#FF4C00] hover:text-[#FF4C00]"
          >
            <.ui_icon name={:eye} class="h-4 w-4" />
          </a>

          <a
            id={"share-itinerary-" <> to_string(@itinerary.id)}
            href={@share_url}
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Share itinerary"
            class="grid h-9 w-9 shrink-0 place-items-center rounded-xl border border-slate-200 text-slate-400 transition hover:border-[#FF4C00] hover:text-[#FF4C00]"
          >
            <.ui_icon name={:share} class="h-4 w-4" />
          </a>
        </div>
        
        <div class="mt-2 grid grid-cols-3 gap-1.5 border-t border-slate-100 pt-2">
          <a
            id={"edit-itinerary-" <> to_string(@itinerary.id)}
            href={@edit_path}
            class="inline-flex items-center justify-center gap-1 rounded-lg px-2 py-2 text-[9px] font-black uppercase tracking-widest text-slate-500 transition hover:bg-slate-50 hover:text-[#FF4C00]"
          >
            <.ui_icon name={:edit} class="h-3 w-3" /> Edit
          </a>
          
          <button
            type="button"
            id={"duplicate-itinerary-" <> to_string(@itinerary.id)}
            phx-click="duplicate_itinerary"
            phx-value-id={@itinerary.id}
            class="inline-flex items-center justify-center gap-1 rounded-lg px-2 py-2 text-[9px] font-black uppercase tracking-widest text-slate-500 transition hover:bg-slate-50 hover:text-[#FF4C00]"
          >
            <.ui_icon name={:content_copy} class="h-3 w-3" /> Duplicate
          </button>
          
          <button
            type="button"
            id={"delete-itinerary-" <> to_string(@itinerary.id)}
            phx-click="delete_itinerary"
            phx-value-id={@itinerary.id}
            data-confirm="Delete this saved itinerary? This cannot be undone."
            class="inline-flex items-center justify-center gap-1 rounded-lg px-2 py-2 text-[9px] font-black uppercase tracking-widest text-slate-400 transition hover:bg-red-50 hover:text-red-600"
          >
            <.ui_icon name={:delete} class="h-3 w-3" /> Delete
          </button>
        </div>
      </div>
    </article>
    """
  end

  defp status_label(:upcoming), do: "Upcoming"
  defp status_label(:ongoing), do: "Ongoing"
  defp status_label(:completed), do: "Completed"

  defp status_class(:upcoming), do: "bg-amber-100 text-amber-700"
  defp status_class(:ongoing), do: "bg-sky-100 text-sky-700"
  defp status_class(:completed), do: "bg-emerald-100 text-emerald-700"

  defp art_variant("coast"), do: :coast
  defp art_variant("savanna"), do: :savanna
  defp art_variant(_art), do: :mountains
end
