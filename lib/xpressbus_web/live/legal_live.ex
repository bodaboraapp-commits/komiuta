defmodule XpressbusWeb.LegalLive do
  @moduledoc """
  Public Terms & Conditions and Privacy Policy pages.

  These pages are linked from checkout, the footer and the registration form;
  they must stay reachable without authentication.
  """

  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents

  @page_content %{
    terms: %{title: "Terms & Conditions", eyebrow: "Legal"},
    privacy: %{title: "Privacy Policy", eyebrow: "Legal"}
  }

  @impl true
  def mount(params, session, socket) do
    action = socket.assigns.live_action
    content = Map.fetch!(@page_content, action)

    {:ok,
     socket
     |> assign(:step, :legal)
     |> assign(:footer_tab, "about")
     |> assign(:current_user, session["user_id"])
     |> assign(:page_title, content.title)
     |> assign(
       :page_description,
       case action do
         :terms ->
           "Komiuta terms and conditions for bus ticket bookings, payments, cancellations and travel."

         :privacy ->
           "How Komiuta collects, uses and protects your personal data when you book bus tickets."
       end
     )
     |> assign(:page_canonical, XpressbusWeb.SEO.base_url() <> "/" <> to_string(action))
     |> assign(
       :page_json_ld,
       [
         XpressbusWeb.SEO.organization(),
         XpressbusWeb.SEO.breadcrumb([
           {"Home", XpressbusWeb.SEO.base_url() <> "/"},
           {content.title, XpressbusWeb.SEO.base_url() <> "/" <> to_string(action)}
         ])
       ]
     )
     |> assign(:legal_action, action)
     |> assign(:content, content)
     |> assign(:ticket_id, Map.get(params, "ticket_id"))}
  end

  @impl true
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
          <section class="bg-slate-950 text-white pt-16 pb-14 px-6">
            <div class="max-w-4xl mx-auto">
              <p class="text-[11px] font-black uppercase tracking-[0.4em] text-[#FF4C00] mb-4">
                {@content.eyebrow}
              </p>

              <h1 class="text-4xl md:text-6xl font-black tracking-tighter leading-none mb-4">
                {@content.title}
              </h1>

              <p class="text-sm font-bold text-slate-400">
                Last updated {Calendar.strftime(Date.utc_today(), "%B %d, %Y")}
              </p>
            </div>
          </section>

          <div class="max-w-4xl mx-auto px-6 py-16">
            <nav
              class="flex flex-wrap gap-3 mb-12"
              aria-label="Legal documents"
            >
              <.link
                navigate={~p"/terms"}
                class={[
                  "px-5 py-2.5 rounded-full text-[11px] font-black uppercase tracking-widest transition",
                  @legal_action == :terms && "bg-[#FF4C00] text-white shadow-lg shadow-orange-200",
                  @legal_action != :terms && "bg-slate-100 text-slate-500 hover:bg-slate-200"
                ]}
              >
                Terms &amp; Conditions
              </.link>

              <.link
                navigate={~p"/privacy"}
                class={[
                  "px-5 py-2.5 rounded-full text-[11px] font-black uppercase tracking-widest transition",
                  @legal_action == :privacy && "bg-[#FF4C00] text-white shadow-lg shadow-orange-200",
                  @legal_action != :privacy && "bg-slate-100 text-slate-500 hover:bg-slate-200"
                ]}
              >
                Privacy Policy
              </.link>
            </nav>

            <%= if @legal_action == :terms do %>
              <.terms_body />
            <% else %>
              <.privacy_body />
            <% end %>

            <div class="mt-16 rounded-3xl border border-slate-100 bg-slate-50 p-8">
              <h2 class="text-lg font-black text-slate-900 mb-2">Questions?</h2>

              <p class="text-sm font-bold text-slate-500 mb-4">
                Reach our support team and we will get back to you within one business day.
              </p>

              <div class="flex flex-wrap gap-3">
                <a
                  href="mailto:hello@komiuta.com"
                  class="px-5 py-2.5 rounded-full bg-slate-900 text-white text-[11px] font-black uppercase tracking-widest hover:bg-slate-800 transition"
                >
                  hello@komiuta.com
                </a>

                <a
                  href="tel:0800211211"
                  class="px-5 py-2.5 rounded-full bg-white border border-slate-200 text-slate-700 text-[11px] font-black uppercase tracking-widest hover:border-[#FF4C00] hover:text-[#FF4C00] transition"
                >
                  0800 211 211
                </a>
              </div>
            </div>
          </div>
        </main>
        <.main_footer footer_tab={@footer_tab} />
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, default: nil

  defp terms_body(assigns) do
    ~H"""
    <div class="space-y-10 text-sm md:text-base font-bold text-slate-500 leading-relaxed">
      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">1. About these terms</h2>

        <p>
          These terms govern your use of the Komiuta bus booking platform operated by
          Komiuta WanCom Engineering Sol ("Komiuta", "we", "us"). By searching for a trip,
          reserving a seat or completing a payment you accept these terms. If you do not
          agree with them, please do not use the service.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">2. Bookings and tickets</h2>

        <p class="mb-3">
          A booking is confirmed only after the payment provider has confirmed your payment
          and a valid e-ticket has been issued. Until then, seats are held on a best-effort
          basis and may be released.
        </p>

        <p>
          Tickets are personal and must be presented together with a matching national ID or
          passport. The passenger name, phone number and travel date on the ticket must match
          the traveller. Tickets are non-transferable unless the operating bus company agrees
          otherwise in writing.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">3. Prices, fees and payments</h2>

        <p>
          Prices are displayed in Kenya Shillings (KES) and include the operator fare. Any
          booking, payment or convenience fees are shown before you pay. Payment is collected
          by our payment partners (M-PESA, Flutterwave or Paystack depending on availability)
          and their own terms apply to the payment transaction. Coupon discounts are applied
          before payment and are subject to the conditions shown with each coupon.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">4. Changes, cancellations and refunds</h2>

        <p>
          Once seats are selected and paid for they cannot be changed, and tickets are
          non-refundable, except where the operating bus company cancels the trip or where
          the law requires a refund. If a trip is cancelled by the operator, contact support
          with your ticket number and we will coordinate a refund or rebooking with the
          operator.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">5. Travel documents and conduct</h2>

        <p>
          You are responsible for carrying valid travel documents for your route, including
          any cross-border requirements. Passengers must comply with the operating company's
          luggage, safety and conduct rules. Komiuta may refuse or cancel a booking where
          fraud, abuse or a safety risk is suspected.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">6. Service availability</h2>

        <p>
          We work to keep the platform available and accurate, but schedules, fares and
          availability are supplied by third-party operators and may change without notice.
          We are not liable for indirect losses caused by delays, operator changes or
          interruptions outside our reasonable control.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">7. Contact</h2>

        <p>
          Questions about a booking or these terms can be sent to
          <a class="text-[#FF4C00] underline underline-offset-4" href="mailto:hello@komiuta.com">
            hello@komiuta.com
          </a>
          or by calling 0800 211 211.
        </p>
      </section>
    </div>
    """
  end

  defp privacy_body(assigns) do
    ~H"""
    <div class="space-y-10 text-sm md:text-base font-bold text-slate-500 leading-relaxed">
      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">1. Information we collect</h2>

        <p class="mb-3">
          To create your account and issue a ticket we collect your name, phone number, email
          address (where you provide one) and the details of the trip you book. If you sign in
          with Google we also receive your Google name, email address and Google account
          identifier.
        </p>

        <p>
          When you pay, our payment partners process your payment details. Komiuta does not
          store your card number or M-PESA PIN. We retain payment references and status so
          that we can reconcile a booking and support you if a payment is disputed.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">2. How we use your information</h2>

        <p>
          We use your information to issue and deliver tickets, take payments, prevent fraud,
          provide support, meet legal and accounting obligations, and improve the reliability
          of the platform. We only send marketing messages where you have asked to receive
          them, and you can unsubscribe at any time.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">3. Sharing with operators</h2>

        <p>
          We share the passenger name, phone number, travel date and seat number with the bus
          operator that operates your trip, because the operator needs those details to carry
          you and to verify your ticket at boarding.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">4. Security</h2>

        <p>
          Access to personal data is restricted to staff and systems that need it. Data in
          transit is protected with HTTPS. No system is perfectly secure, so please use a
          strong, unique password where a password is offered and keep your phone and email
          account secure.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">5. Your rights</h2>

        <p>
          You may request a copy of the personal data we hold about you, ask us to correct it,
          or ask us to delete data that we are not required to keep. To make a request, email
          <a class="text-[#FF4C00] underline underline-offset-4" href="mailto:hello@komiuta.com">
            hello@komiuta.com
          </a>
          from the address or phone number linked to your account.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">6. Retention</h2>

        <p>
          Booking and payment records are kept for as long as required for accounting, tax
          and dispute-resolution purposes. Marketing subscriber records are kept until you
          unsubscribe, after which we keep only a suppression record.
        </p>
      </section>

      <section>
        <h2 class="text-xl font-black text-slate-900 mb-3">7. Contact</h2>

        <p>
          Privacy questions can be sent to <a
            class="text-[#FF4C00] underline underline-offset-4"
            href="mailto:hello@komiuta.com"
          >
            hello@komiuta.com
          </a>.
        </p>
      </section>
    </div>
    """
  end
end
