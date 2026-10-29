defmodule XpressbusWeb.InsuranceLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents

  @impl true
  def mount(_params, session, socket) do
    current_user = session["user_id"]

    {:ok,
     socket
     |> assign(:step, :insurance)
     |> assign(:current_user, current_user)
     |> assign(:page_title, "Travel Insurance - InSURE")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-white text-slate-900">
        <.main_header step={@step} current_user={@current_user} />
        <main class="pt-[72px] md:pt-[80px]">
          <section class="relative pt-20 pb-32 px-6 rounded-b-[4rem] md:rounded-b-[8rem] overflow-hidden bg-slate-950 text-white">
            <div class="absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-black/40">
            </div>

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
                <a
                  href="#plans"
                  class="bg-[#FF4C00] text-white px-10 py-4 rounded-full font-black hover:bg-[#E64400] transition shadow-lg shadow-orange-200 text-center"
                >
                  View Plans
                </a>
                <a
                  href="#faq"
                  class="bg-white/10 text-white px-10 py-4 rounded-full font-black hover:bg-white/20 transition text-center border border-white/20"
                >
                  FAQs
                </a>
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

              <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
                <.plan_card
                  name="Essential"
                  price="Ksh 1,500"
                  period="per trip"
                  features={[
                    "Trip cancellation up to Ksh 100,000",
                    "Medical expenses up to Ksh 500,000",
                    "Baggage loss up to Ksh 50,000",
                    "24/7 Emergency assistance",
                    "Flight delay compensation",
                    "Personal liability cover"
                  ]}
                  cta="Select Essential"
                  popular={false}
                />

                <.plan_card
                  name="Comprehensive"
                  price="Ksh 3,500"
                  period="per trip"
                  features={[
                    "Trip cancellation up to Ksh 300,000",
                    "Medical expenses up to Ksh 2,000,000",
                    "Baggage loss up to Ksh 150,000",
                    "24/7 Emergency assistance",
                    "Flight delay compensation",
                    "Personal liability cover",
                    "Rental car excess cover",
                    "Adventure sports cover",
                    "Gadget protection up to Ksh 100,000"
                  ]}
                  cta="Select Comprehensive"
                  popular={true}
                />

                <.plan_card
                  name="Annual Multi-Trip"
                  price="Ksh 12,000"
                  period="per year"
                  features={[
                    "Unlimited trips per year (max 90 days each)",
                    "Trip cancellation up to Ksh 500,000",
                    "Medical expenses up to Ksh 5,000,000",
                    "Baggage loss up to Ksh 200,000",
                    "24/7 Emergency assistance",
                    "Flight delay compensation",
                    "Personal liability cover",
                    "Rental car excess cover",
                    "Adventure sports cover",
                    "Gadget protection up to Ksh 200,000",
                    "Family coverage option available"
                  ]}
                  cta="Select Annual"
                  popular={false}
                />
              </div>
            </section>

            <section id="coverage-details" class="bg-slate-50 rounded-[4rem] p-8 md:p-14 space-y-16">
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
                <table class="w-full min-w-[800px] text-left">
                  <thead>
                    <tr class="border-b-2 border-slate-200">
                      <th class="pb-4 font-black text-slate-900 text-sm uppercase tracking-wider">
                        Coverage
                      </th>
                      <th class="pb-4 font-black text-slate-900 text-sm uppercase tracking-wider text-center">
                        Essential
                      </th>
                      <th class="pb-4 font-black text-slate-900 text-sm uppercase tracking-wider text-center">
                        Comprehensive
                      </th>
                      <th class="pb-4 font-black text-slate-900 text-sm uppercase tracking-wider text-center">
                        Annual
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-100">
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">Trip Cancellation</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 100,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 300,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 500,000</td>
                    </tr>
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">Medical Expenses</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 500,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 2,000,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 5,000,000</td>
                    </tr>
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">Baggage Loss/Delay</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 50,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 150,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 200,000</td>
                    </tr>
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">Flight Delay (>6 hrs)</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 10,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 25,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 30,000</td>
                    </tr>
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">Personal Liability</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 500,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 1,000,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 2,000,000</td>
                    </tr>
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">Rental Car Excess</td>
                      <td class="py-4 text-center text-slate-400">—</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 100,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 150,000</td>
                    </tr>
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">Adventure Sports</td>
                      <td class="py-4 text-center text-slate-400">—</td>
                      <td class="py-4 text-center font-bold text-slate-600">Included</td>
                      <td class="py-4 text-center font-bold text-slate-600">Included</td>
                    </tr>
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">Gadget Protection</td>
                      <td class="py-4 text-center text-slate-400">—</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 100,000</td>
                      <td class="py-4 text-center font-bold text-slate-600">Ksh 200,000</td>
                    </tr>
                    <tr class="hover:bg-white transition-colors">
                      <td class="py-4 font-bold text-slate-900">24/7 Emergency Assist</td>
                      <td class="py-4 text-center">
                        <span class="material-symbols-outlined text-[#00AC4E] !text-base">check_circle</span>
                      </td>
                      <td class="py-4 text-center">
                        <span class="material-symbols-outlined text-[#00AC4E] !text-base">check_circle</span>
                      </td>
                      <td class="py-4 text-center">
                        <span class="material-symbols-outlined text-[#00AC4E] !text-base">check_circle</span>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>

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

              <div class="max-w-3xl mx-auto space-y-4">
                <.faq_item
                  question="When should I purchase travel insurance?"
                  answer="We recommend purchasing insurance as soon as you book your trip. This ensures you're covered for trip cancellation from the moment you buy. You can purchase up to 24 hours before departure, but pre-existing conditions and some benefits may not apply."
                />
                <.faq_item
                  question="Does insurance cover COVID-19 related issues?"
                  answer="Yes, our Comprehensive and Annual plans cover COVID-19 related medical expenses, trip cancellation if you test positive before travel, and quarantine accommodation costs (up to policy limits). Essential plan has limited pandemic coverage."
                />
                <.faq_item
                  question="Can I get a refund if I don't travel?"
                  answer="You can cancel your policy for a full refund within 14 days of purchase (free-look period), provided you haven't started your trip or made a claim. After 14 days, refunds are only available if the trip is cancelled for a covered reason."
                />
                <.faq_item
                  question="How do I make a claim?"
                  answer="Contact our 24/7 claims hotline or submit online via the Komiuta app. You'll need your policy number, travel documents, and supporting evidence (medical reports, receipts, police reports for theft). Claims are typically processed within 10 business days."
                />
                <.faq_item
                  question="Am I covered for adventure activities?"
                  answer="Essential plan excludes adventure sports. Comprehensive and Annual plans cover activities like safari, hiking, zip-lining, snorkeling, and skiing. Extreme sports (bungee jumping, skydiving, scuba >30m) require an additional rider."
                />
                <.faq_item
                  question="Can I extend coverage mid-trip?"
                  answer="Yes, you can extend your Annual plan or upgrade from Essential to Comprehensive mid-trip via the app, subject to underwriting approval. Contact support at least 48 hours before your current coverage expires."
                />
              </div>
            </section>

            <section class="bg-slate-900 rounded-[4rem] p-8 md:p-14 text-white relative overflow-hidden">
              <div class="absolute top-0 right-0 w-96 h-96 bg-[#FF4C00]/20 rounded-full blur-[120px]">
              </div>

              <div class="relative z-10 text-center max-w-3xl mx-auto">
                <span class="material-symbols-outlined text-[#FF4C00] !text-4xl mb-6 block">rocket_launch</span>
                <h2 class="text-3xl md:text-4xl font-black tracking-tight text-white mb-6">
                  Ready to Travel Protected?
                </h2>
                <p class="text-slate-300 font-bold text-lg mb-10 max-w-xl mx-auto">
                  Add InSURE to your next booking or purchase standalone coverage. Peace of mind starts at just Ksh 1,500 per trip.
                </p>
                <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
                  <a
                    href="/"
                    class="bg-[#FF4C00] text-white px-10 py-4 rounded-full font-black uppercase text-xs tracking-widest hover:bg-[#E64400] transition shadow-xl shadow-orange-950/40"
                  >
                    Book a Bus Trip
                  </a>
                  <a
                    href="#plans"
                    class="bg-white/10 text-white px-10 py-4 rounded-full font-black uppercase text-xs tracking-widest hover:bg-white/20 transition border border-white/20"
                  >
                    View Insurance Plans
                  </a>
                </div>
              </div>
            </section>
          </div>
        </main>
        <.main_footer footer_tab="about" />
      </div>
    </Layouts.app>
    """
  end

  attr :name, :string, required: true
  attr :price, :string, required: true
  attr :period, :string, required: true
  attr :features, :list, required: true
  attr :cta, :string, required: true
  attr :popular, :boolean, default: false

  defp plan_card(assigns) do
    ~H"""
    <div class={[
      "relative bg-white rounded-[2.5rem] p-8 border-2 transition-all hover:shadow-2xl",
      @popular && "border-[#FF4C00] shadow-xl shadow-orange-100",
      @popular == false && "border-slate-100 hover:border-orange-200"
    ]}>
      <%= if @popular do %>
        <div class="absolute -top-4 left-1/2 -translate-x-1/2 bg-[#FF4C00] text-white text-[10px] font-black uppercase tracking-widest px-4 py-1 rounded-full">
          MOST POPULAR
        </div>
      <% end %>

      <div class="text-center mb-8">
        <h3 class="text-2xl font-black text-slate-900 mb-2">{@name}</h3>
        <div class="flex items-baseline justify-center gap-1 mb-2">
          <span class="text-4xl font-black text-slate-900">{@price}</span>
          <span class="text-sm font-bold text-slate-400">/{@period}</span>
        </div>
      </div>

      <ul class="space-y-4 mb-10">
        <%= for feature <- @features do %>
          <li class="flex items-start gap-3 text-slate-600 font-bold">
            <span class="material-symbols-outlined text-[#00AC4E] !text-base mt-0.5 shrink-0">check_circle</span>
            <span>{feature}</span>
          </li>
        <% end %>
      </ul>

      <button class={[
        "w-full py-4 rounded-full font-black uppercase text-xs tracking-widest transition-all",
        @popular && "bg-[#FF4C00] text-white hover:bg-[#E64400] shadow-lg shadow-orange-200",
        @popular == false && "bg-slate-100 text-slate-900 hover:bg-slate-200 border border-slate-200"
      ]}>
        {@cta}
      </button>
    </div>
    """
  end

  attr :question, :string, required: true
  attr :answer, :string, required: true

  defp faq_item(assigns) do
    ~H"""
    <details class="group bg-white rounded-2xl border border-slate-100 overflow-hidden open:border-[#FF4C00] open:shadow-lg transition-all">
      <summary class="flex items-center justify-between p-6 cursor-pointer list-none">
        <h3 class="text-lg font-black text-slate-900 pr-8">{@question}</h3>
        <span class="material-symbols-outlined text-slate-400 group-open:rotate-180 transition-transform duration-200 shrink-0">expand_more</span>
      </summary>
      <div class="px-6 pb-6 text-slate-500 font-bold leading-relaxed border-t border-slate-100">
        {@answer}
      </div>
    </details>
    """
  end
end
