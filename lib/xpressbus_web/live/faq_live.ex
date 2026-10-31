defmodule XpressbusWeb.FaqLive do
  @moduledoc """
  Public FAQ page targeting question-heavy and AI-search queries about booking,
  payment, seats, tickets and cancellations.
  """

  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents

  alias XpressbusWeb.SEO

  @faqs [
    %{
      question: "How do I book a bus ticket on Komiuta?",
      answer:
        "Search your route and travel date, compare buses and fares, choose your seat, enter the passenger details and pay with M-PESA, card or mobile money. Your ticket is sent instantly by SMS and email."
    },
    %{
      question: "How much do bus tickets cost in Kenya?",
      answer:
        "Fares depend on the route, operator and seat class. Nairobi to Mombasa typically starts around KES 1,200, while shorter routes such as Nairobi to Nakuru can start below KES 1,000. The live fare is always shown before you pay."
    },
    %{
      question: "Can I pay for my bus ticket with M-PESA?",
      answer:
        "Yes. Select M-PESA at checkout, enter the phone number you want to pay from, approve the STK push on your phone and your ticket is issued immediately."
    },
    %{
      question: "Do I need to create an account to book?",
      answer:
        "No. You can book as a guest with your name, phone number and email. Creating an account lets you track bookings, save passenger details and earn referral rewards."
    },
    %{
      question: "Can I choose my seat?",
      answer:
        "Yes. After choosing a bus, the seat map shows taken and available seats. Tap the seat you want and confirm before continuing to passenger details."
    },
    %{
      question: "How will I receive my ticket?",
      answer:
        "Your ticket is delivered by SMS and email after payment. It includes a QR code and barcode for boarding and a link to view the ticket online."
    },
    %{
      question: "Can I cancel or change my ticket?",
      answer:
        "Changes and cancellations follow the operator's fare rules. Free cancellation is available up to 2 hours before departure on eligible tickets, shown before you pay."
    },
    %{
      question: "What happens if my bus is delayed?",
      answer:
        "Contact the operator using the details on your ticket or our support team if you need help. Your ticket remains valid for the booked trip, and we will assist with any operator changes."
    },
    %{
      question: "How do I track my ticket?",
      answer:
        "Open Track Ticket in the header, enter your ticket number and the full phone number used at booking. You can also use the secure ticket link from your confirmation SMS."
    },
    %{
      question: "Is my payment secure?",
      answer:
        "Yes. Payments are processed through PCI-compliant payment partners. Komiuta never stores your M-PESA PIN or full card details."
    }
  ]

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:step, :faq)
     |> assign(:footer_tab, "about")
     |> assign(:current_user, session["user_id"])
     |> assign(:faqs, @faqs)
     |> assign(:page_title, "Bus Booking FAQs — Tickets, M-PESA & Cancellations")
     |> assign(
       :page_description,
       "Answers to common Komiuta questions: booking a bus ticket, fares, M-PESA payment, seat selection, ticket delivery, tracking, changes and cancellations."
     )
     |> assign(:page_canonical, SEO.base_url() <> "/faqs")
     |> assign(:page_robots, "index,follow")
     |> assign(:page_json_ld, [SEO.organization(), SEO.faq_page(@faqs)])}
  end

  @impl true
  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end
end
