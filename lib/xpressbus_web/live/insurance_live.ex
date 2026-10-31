defmodule XpressbusWeb.InsuranceLive do
  @moduledoc """
  Public InSURE travel insurance page.

  Plans, feature bullets, the coverage comparison table and the FAQ list are
  all rendered from the database via `Xpressbus.Insurance`; nothing on this
  page is hard-coded cover text any more. Editing a row in `insurance_plans`
  or `insurance_faqs` (or toggling `active`) changes what customers see
  without a deploy.
  """

  use XpressbusWeb, :live_view

  import XpressbusWeb.BrandComponents
  import XpressbusWeb.Format, only: [money: 1]

  alias Xpressbus.Insurance

  @impl true
  def mount(_params, session, socket) do
    plans = Insurance.list_active_plans()

    {:ok,
     socket
     |> assign(:step, :insurance)
     |> assign(:footer_tab, "about")
     |> assign(:current_user, session["user_id"])
     |> assign(:plans, plans)
     |> assign(:coverage_rows, Insurance.coverage_rows(plans))
     |> assign(:faqs, Insurance.list_active_faqs())
     |> assign(:starting_price, Insurance.starting_price(plans))
     |> assign(:selected_plan, nil)
     |> assign(
       :page_description,
       "Compare travel insurance plans from InSURE by Komiuta. Cover for medical emergencies, trip cancellation, baggage and delays across Kenya, Uganda and Tanzania."
     )
     |> assign(:page_canonical, XpressbusWeb.Endpoint.url() <> "/tour-packages/insurance")
     |> assign(
       :page_json_ld,
       [
         XpressbusWeb.SEO.organization(),
         XpressbusWeb.SEO.faq_page(
           Enum.map(Insurance.list_active_faqs(), fn faq ->
             %{
               question: Map.get(faq, :question, "Travel insurance FAQ"),
               answer: Map.get(faq, :answer, "")
             }
           end)
         )
       ]
     )
     |> assign(:page_title, "Travel Insurance · InSURE")}
  end

  @impl true
  def handle_event("select_plan", %{"name" => name}, socket) do
    {:noreply,
     socket
     |> assign(:selected_plan, name)
     |> put_flash(
       :info,
       "#{name} cover selected. Call 0800 211 211 or email hello@komiuta.com to activate it on your next trip."
     )}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_plan, nil)}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  def handle_event("back_to_search", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-white text-slate-900">
        <.main_header step={@step} current_user={@current_user} />
        <main class="pt-[72px] md:pt-[80px]">
          <section class="relative pt-20 pb-32 px-6 rounded-b-[4rem] md:rounded-b-[8rem] overflow-hidden bg-gradient-to-br from-slate-950 via-slate-900 to-[#431407] text-white">
            <span
              class="material-symbols-outlined absolute -right-10 -top-10 text-white/5 !text-[22rem] pointer-events-none select-none"
              aria-hidden="true"
            >
              shield
            </span>

            <div class="max-w-[1350px] mx-auto flex flex-col items-center justify-center relative z-10 text-center">
              <div class="inline-flex items-center justify-center w-20 h-20 rounded-full bg-[#FF4C00]/20 mb-8">
                <span class="material-symbols-outlined text-[#FF4C00] !text-4xl">shield</span>
              </div>

              <h1 class="text-4xl md:text-7xl font-black tracking-tighter mb-6 leading-tight">
                Travel with Confidence
              </h1>

              <p class="text-xl md:text-2xl font-medium opacity-90 mb-12 max-w-2xl">
                Comprehensive travel insurance for your Komiuta journeys. Coverage for trip cancellations, medical emergencies, baggage loss, and more.
              </p>

              <div class="flex flex-col sm:flex-row items-center gap-4 w-full max-w-md">
                <%= if @plans != [] do %>
                  <a
                    href="#plans"
                    class="bg-[#FF4C00] text-white px-10 py-4 rounded-full font-black hover:bg-[#E64400] transition shadow-lg shadow-orange-200 text-center"
                  >
                    View Plans
                  </a>
                <% end %>
                <%= if @faqs != [] do %>
                  <a
                    href="#faq"
                    class="bg-white/10 text-white px-10 py-4 rounded-full font-black hover:bg-white/20 transition text-center border border-white/20"
                  >
                    FAQs
                  </a>
                <% end %>
              </div>
            </div>
          </section>

          <div class="max-w-[1350px] mx-auto px-6 space-y-20 py-[58px]">
            <section id="plans" class="space-y-16">
              <div class="text-center max-w-3xl mx-auto mb-16">
                <span class="material-symbols-outlined text-[#FF4C00] !text-3xl mb-4 block">card_membership</span>
                <h2 class="text-3xl md:text-4xl font-black tracking-tight text-slate-900 mb-4">
                  Choose Your Coverage
                </h2>
                <p class="text-slate-500 font-bold text-lg">
                  Flexible plans for every type of traveler. All plans include 24/7 emergency assistance.
                </p>
              </div>

              <%= if @plans == [] do %>
                <div
                  id="insurance-empty"
                  class="bg-slate-50 border border-dashed border-slate-200 rounded-[2.5rem] py-16 px-8 text-center"
                >
                  <span class="material-symbols-outlined text-slate-300 !text-5xl mb-4">policy</span>
                  <p class="text-slate-500 font-bold">
                    Our cover plans are being updated. Call 0800 211 211 and we'll help you find the right protection.
                  </p>
                </div>
              <% else %>
                <div id="insurance-plan-grid" class="grid grid-cols-1 md:grid-cols-3 gap-8">
                  <%= for plan <- @plans do %>
                    <.plan_card plan={plan} selected={@selected_plan == plan.name} />
                  <% end %>
                </div>

                <%= if @selected_plan do %>
                  <div
                    id="insurance-selection"
                    class="bg-orange-50 border border-orange-200 rounded-[2rem] p-8 flex flex-col md:flex-row items-center justify-between gap-6"
                  >
                    <div>
                      <p class="text-[10px] font-black uppercase tracking-widest text-[#FF4C00]">
                        Selected cover
                      </p>
                      <h3 class="text-2xl font-black text-slate-900 mt-1">{@selected_plan}</h3>
                      <p class="text-sm font-bold text-slate-500 mt-2">
                        Call
                        <a href="tel:0800211211" class="text-[#FF4C00] hover:underline">0800 211 211</a>
                        or email
                        <a
                          href="mailto:hello@komiuta.com?subject=InSURE%20cover%20activation"
                          class="text-[#FF4C00] hover:underline"
                        >hello@komiuta.com</a>
                        to activate this cover on your next Komiuta trip.
                      </p>
                    </div>

                    <button
                      type="button"
                      phx-click="clear_selection"
                      class="bg-white border border-slate-200 text-slate-700 px-8 py-3 rounded-full font-black uppercase text-xs tracking-widest hover:bg-slate-100 transition shrink-0"
                    >
                      Choose another plan
                    </button>
                  </div>
                <% end %>
              <% end %>
            </section>

            <%= if @coverage_rows != [] do %>
              <section
                id="coverage-details"
                class="bg-slate-50 rounded-[4rem] p-8 md:p-14 space-y-16"
              >
                <div class="text-center max-w-3xl mx-auto">
                  <span class="material-symbols-outlined text-[#FF4C00] !text-3xl mb-4 block">policy</span>
                  <h2 class="text-3xl md:text-4xl font-black tracking-tight text-slate-900 mb-4">
                    What's Covered
                  </h2>
                  <p class="text-slate-500 font-bold text-lg">
                    Detailed breakdown of coverage benefits across all plans
                  </p>
                </div>

                <div class="overflow-x-auto">
                  <table id="coverage-table" class="w-full min-w-[800px] text-left">
                    <thead>
                      <tr class="border-b-2 border-slate-200">
                        <th class="pb-4 font-black text-slate-900 text-sm uppercase tracking-wider">
                          Coverage
                        </th>
                        <%= for plan <- @plans do %>
                          <th class="pb-4 font-black text-slate-900 text-sm uppercase tracking-wider text-center">
                            {plan.name}
                          </th>
                        <% end %>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-100">
                      <%= for {label, values} <- @coverage_rows do %>
                        <tr class="hover:bg-white transition-colors">
                          <td class="py-4 font-bold text-slate-900">{label}</td>
                          <%= for value <- values do %>
                            <td class="py-4 text-center font-bold text-slate-600">
                              <%= case value do %>
                                <% "Included" -> %>
                                  <span
                                    class="material-symbols-outlined text-[#00AC4E] !text-base"
                                    title="Included"
                                  >check_circle</span>
                                <% "—" -> %>
                                  <span class="text-slate-400">—</span>
                                <% other -> %>
                                  {other}
                              <% end %>
                            </td>
                          <% end %>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </section>
            <% end %>

            <%= if @faqs != [] do %>
              <section id="faq" class="space-y-16">
                <div class="text-center max-w-3xl mx-auto mb-16">
                  <span class="material-symbols-outlined text-[#FF4C00] !text-3xl mb-4 block">help</span>
                  <h2 class="text-3xl md:text-4xl font-black tracking-tight text-slate-900 mb-4">
                    Frequently Asked Questions
                  </h2>
                  <p class="text-slate-500 font-bold text-lg">
                    Everything you need to know about InSURE travel insurance
                  </p>
                </div>

                <div id="insurance-faq-list" class="max-w-3xl mx-auto space-y-4">
                  <%= for faq <- @faqs do %>
                    <.faq_item faq={faq} />
                  <% end %>
                </div>
              </section>
            <% end %>

            <section class="bg-slate-900 rounded-[4rem] p-8 md:p-14 text-white relative overflow-hidden">
              <div class="absolute top-0 right-0 w-96 h-96 bg-[#FF4C00]/20 rounded-full blur-[120px]">
              </div>

              <div class="relative z-10 text-center max-w-3xl mx-auto">
                <span class="material-symbols-outlined text-[#FF4C00] !text-4xl mb-6 block">rocket_launch</span>
                <h2 class="text-3xl md:text-4xl font-black tracking-tight text-white mb-6">
                  Ready to Travel Protected?
                </h2>
                <p
                  id="insurance-starting-price"
                  class="text-slate-300 font-bold text-lg mb-10 max-w-xl mx-auto"
                >
                  <%= if @starting_price do %>
                    Add InSURE to your next booking or purchase standalone coverage. Peace of mind starts at just Ksh {money(
                      @starting_price
                    )} per trip.
                  <% else %>
                    Add InSURE to your next booking or purchase standalone coverage.
                  <% end %>
                </p>
                <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
                  <a
                    href="/"
                    class="bg-[#FF4C00] text-white px-10 py-4 rounded-full font-black uppercase text-xs tracking-widest hover:bg-[#E64400] transition shadow-xl shadow-orange-950/40"
                  >
                    Book a Bus Trip
                  </a>
                  <%= if @plans != [] do %>
                    <a
                      href="#plans"
                      class="bg-white/10 text-white px-10 py-4 rounded-full font-black uppercase text-xs tracking-widest hover:bg-white/20 transition border border-white/20"
                    >
                      View Insurance Plans
                    </a>
                  <% end %>
                </div>
              </div>
            </section>
          </div>
        </main>
        <.main_footer footer_tab={@footer_tab} />
      </div>
    </Layouts.app>
    """
  end

  attr :plan, :any, required: true
  attr :selected, :boolean, default: false

  defp plan_card(assigns) do
    ~H"""
    <div
      id={"plan-card-#{@plan.id}"}
      class={[
        "relative bg-white rounded-[2.5rem] p-8 border-2 transition-all hover:shadow-2xl",
        @plan.popular && "border-[#FF4C00] shadow-xl shadow-orange-100",
        !@plan.popular && "border-slate-100 hover:border-orange-200",
        @selected && "ring-4 ring-orange-200"
      ]}
    >
      <%= if @plan.popular do %>
        <div class="absolute -top-4 left-1/2 -translate-x-1/2 bg-[#FF4C00] text-white text-[10px] font-black uppercase tracking-widest px-4 py-1 rounded-full whitespace-nowrap">
          MOST POPULAR
        </div>
      <% end %>

      <div class="text-center mb-8">
        <h3 class="text-2xl font-black text-slate-900 mb-2">{@plan.name}</h3>
        <div class="flex items-baseline justify-center gap-1 mb-2">
          <span class="text-4xl font-black text-slate-900">Ksh {money(@plan.price)}</span>
          <span class="text-sm font-bold text-slate-400">/{@plan.period}</span>
        </div>
        <%= if @plan.tagline do %>
          <p class="text-xs font-bold text-slate-400">{@plan.tagline}</p>
        <% end %>
      </div>

      <ul class="space-y-4 mb-10">
        <%= for feature <- @plan.features || [] do %>
          <li class="flex items-start gap-3 text-slate-600 font-bold">
            <span class="material-symbols-outlined text-[#00AC4E] !text-base mt-0.5 shrink-0">check_circle</span>
            <span>{feature}</span>
          </li>
        <% end %>
      </ul>

      <button
        type="button"
        phx-click="select_plan"
        phx-value-name={@plan.name}
        class={[
          "w-full py-4 rounded-full font-black uppercase text-xs tracking-widest transition-all",
          @plan.popular && "bg-[#FF4C00] text-white hover:bg-[#E64400] shadow-lg shadow-orange-200",
          !@plan.popular &&
            "bg-slate-100 text-slate-900 hover:bg-slate-200 border border-slate-200"
        ]}
      >
        {if @selected, do: "Selected", else: "Select #{@plan.name}"}
      </button>
    </div>
    """
  end

  attr :faq, :any, required: true

  defp faq_item(assigns) do
    ~H"""
    <details
      id={"insurance-faq-#{@faq.id}"}
      class="group bg-white rounded-2xl border border-slate-100 overflow-hidden open:border-[#FF4C00] open:shadow-lg transition-all"
    >
      <summary class="flex items-center justify-between p-6 cursor-pointer list-none">
        <h3 class="text-lg font-black text-slate-900 pr-8">{@faq.question}</h3>
        <span class="material-symbols-outlined text-slate-400 group-open:rotate-180 transition-transform duration-200 shrink-0">expand_more</span>
      </summary>
      <div class="px-6 pb-6 text-slate-500 font-bold leading-relaxed border-t border-slate-100">
        {@faq.answer}
      </div>
    </details>
    """
  end
end
