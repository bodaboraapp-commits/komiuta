defmodule XpressbusWeb.Blog do
  @moduledoc """
  Static launch articles for the Komiuta travel blog.

  Keeping these as structured data (not a database) makes the launch content
  reviewable in git while still giving each article a real URL, metadata,
  BlogPosting schema and internal links for SEO / AI search.
  """

  @posts [
    %{
      slug: "nairobi-to-kisumu-bus-guide",
      title: "Nairobi to Kisumu Bus Guide: Fares, Terminals & Travel Tips",
      description:
        "A practical guide to travelling by bus from Nairobi to Kisumu: typical fares, departure terminals, journey times, best seats and how to book online with M-PESA.",
      excerpt:
        "Everything you need for a smooth Nairobi to Kisumu journey — fares, terminals, journey times, seat classes and booking tips.",
      category: "Route guide",
      date: ~D[2026-10-31],
      updated: ~D[2026-10-31],
      read_minutes: 7,
      links: [
        {"Nairobi to Kisumu bus tickets", "/buses/Nairobi-to-Kisumu"},
        {"Buses from Nairobi", "/cities/nairobi"},
        {"Buses from Kisumu", "/cities/kisumu"}
      ],
      sections: [
        %{
          heading: "How long is the bus from Nairobi to Kisumu?",
          paragraphs: [
            "Most direct buses take between 7 and 9 hours, depending on the operator, departure time and traffic on the Nairobi–Nakuru–Kisumu highway. Early-morning departures usually avoid the heaviest Nairobi traffic and arrive in Kisumu in the afternoon.",
            "When you search on Komiuta, the journey time is shown on every bus card. Use the Fastest sort if you want the shortest scheduled trip."
          ]
        },
        %{
          heading: "Nairobi to Kisumu bus fare",
          paragraphs: [
            "Normal-class fares typically start around KES 1,200–1,400. VIP and business seats generally cost more because they offer extra legroom, reclining seats and sometimes onboard refreshments.",
            "Fares move with demand and fuel prices, so the price shown when you search is the price you pay. Promo codes can reduce the fare further at checkout."
          ]
        },
        %{
          heading: "Where do buses leave from in Nairobi?",
          paragraphs: [
            "Most intercity operators leave from the busy CBD terminals around Ronald Ngala Street, Accra Road and Country Bus Station. Arrive at least 30 minutes before departure to find your bus and load luggage.",
            "Your ticket shows the exact boarding point chosen at checkout. If you are unsure, contact the operator using the number on your ticket."
          ],
          bullets: [
            "Ronald Ngala Street — Easy Coach, Tahmeed, Greenline and others",
            "Accra Road — several Kisumu and western Kenya services",
            "Country Bus Station — regional and upcountry departures"
          ]
        },
        %{
          heading: "Arriving in Kisumu",
          paragraphs: [
            "Most long-distance buses arrive at Kisumu Bus Park, close to the town centre and the lakefront. From there you can take a boda boda or taxi to your hotel or continue to Kondele and other parts of the city.",
            "Keep your ticket until you leave the terminal. It is also useful if you need to follow up on lost luggage."
          ]
        },
        %{
          heading: "How to book a Nairobi to Kisumu bus ticket",
          paragraphs: [
            "Search your travel date, compare operators and fares, then choose an available seat. Enter your passenger details, pay with M-PESA, card or mobile money and receive your ticket instantly by SMS and email.",
            "If your plans change, check the cancellation rules before you pay. Free cancellation is available on eligible tickets up to 2 hours before departure."
          ]
        }
      ],
      faqs: [
        %{
          question: "How much is a bus from Nairobi to Kisumu?",
          answer:
            "Normal fares usually start around KES 1,200–1,400. VIP and business seats cost more. The live fare is always shown before you pay."
        },
        %{
          question: "Do buses from Nairobi to Kisumu run at night?",
          answer:
            "Some operators run evening departures, but most travellers prefer daytime buses. Check the departure and arrival times on each bus card."
        },
        %{
          question: "Can I book a Nairobi to Kisumu bus online?",
          answer:
            "Yes. Search on Komiuta, choose your seat, pay with M-PESA or card and receive your ticket by SMS and email."
        }
      ]
    },
    %{
      slug: "how-to-pay-for-bus-ticket-with-mpesa",
      title: "How to Pay for a Bus Ticket with M-PESA on Komiuta",
      description:
        "Step-by-step guide to paying for a Komiuta bus ticket with M-PESA, including the STK prompt, confirmation SMS, payment troubleshooting and ticket delivery.",
      excerpt:
        "A simple, secure walkthrough of paying for your bus ticket with M-PESA — from choosing your seat to receiving the ticket.",
      category: "Payment guide",
      date: ~D[2026-10-31],
      updated: ~D[2026-10-31],
      read_minutes: 5,
      links: [
        {"Bus tickets in Kenya", "/"},
        {"FAQs", "/faqs"},
        {"Nairobi to Mombasa bus tickets", "/buses/Nairobi-to-Mombasa"}
      ],
      sections: [
        %{
          heading: "Before you start",
          paragraphs: [
            "Make sure your phone has an active Safaricom line and enough M-PESA balance for the ticket. You will also need the phone number that receives the STK push — this can be different from the passenger phone number.",
            "Komiuta never asks for your M-PESA PIN. Only enter your PIN on the official M-PESA prompt on your phone."
          ]
        },
        %{
          heading: "Step-by-step M-PESA checkout",
          paragraphs: [
            "After choosing your bus and seat, continue to passenger details and the payment step. Select M-PESA, enter the paying phone number and tap Pay.",
            "An STK push appears on your phone. Enter your M-PESA PIN and wait for the confirmation SMS. The checkout page then shows your ticket and sends a copy by SMS and email."
          ],
          bullets: [
            "Enter the number without spaces or the +254 prefix",
            "Approve the prompt within the time limit",
            "Wait for both the M-PESA SMS and the Komiuta ticket SMS"
          ]
        },
        %{
          heading: "What if the M-PESA prompt does not appear?",
          paragraphs: [
            "First check that your phone has signal and that the number you entered is correct. If the prompt has expired, go back and try again — a new request creates a new prompt.",
            "If money was deducted but no ticket arrived, do not pay again. Contact support with your M-PESA confirmation code and the ticket route so the payment can be matched."
          ]
        },
        %{
          heading: "Ticket delivery and tracking",
          paragraphs: [
            "Your ticket includes a QR code and Code 128 barcode for boarding, plus a secure link to view it online. You can also open Track Ticket in the header and enter your ticket number and booking phone number.",
            "Keep the SMS and email until your journey is complete."
          ]
        }
      ],
      faqs: [
        %{
          question: "Does Komiuta accept M-PESA?",
          answer:
            "Yes. M-PESA is available on every booking, alongside card and mobile money options."
        },
        %{
          question: "What if I entered the wrong M-PESA number?",
          answer:
            "If the prompt goes to the wrong phone, cancel it and restart checkout with the correct number. If a payment succeeded but the ticket did not arrive, contact support with the confirmation code."
        },
        %{
          question: "Is it safe to pay on Komiuta?",
          answer:
            "Yes. Payments are handled by regulated payment partners and Komiuta never stores your M-PESA PIN or full card details."
        }
      ]
    },
    %{
      slug: "mombasa-to-nairobi-bus-guide",
      title: "Mombasa to Nairobi Bus Guide: Fares, Night Buses & Terminals",
      description:
        "Plan your Mombasa to Nairobi bus journey: typical fares, day and night departures, terminals in Mombasa, arrival points in Nairobi and booking tips.",
      excerpt:
        "Fares, departure times, terminals and practical tips for the Mombasa to Nairobi bus route.",
      category: "Route guide",
      date: ~D[2026-10-31],
      updated: ~D[2026-10-31],
      read_minutes: 6,
      links: [
        {"Mombasa to Nairobi bus tickets", "/buses/Mombasa-to-Nairobi"},
        {"Buses from Mombasa", "/cities/mombasa"},
        {"Buses from Nairobi", "/cities/nairobi"}
      ],
      sections: [
        %{
          heading: "Journey time and departures",
          paragraphs: [
            "The Mombasa to Nairobi bus usually takes 8 to 10 hours. Day buses leave through the morning and early afternoon, while night buses depart in the evening and arrive in Nairobi early the next morning.",
            "Night buses can suit travellers who want to save a hotel night, but choose a reputable operator and a seat class you are comfortable with. Komiuta shows operator ratings and seat availability before you book."
          ]
        },
        %{
          heading: "Mombasa to Nairobi bus fare",
          paragraphs: [
            "Normal fares generally start around KES 1,200–1,500 depending on the operator and season. Business and VIP seats cost more and often include wider seats, charging points and onboard washrooms.",
            "Book a few days ahead for holiday weekends and school breaks, when the cheapest seats sell out first."
          ]
        },
        %{
          heading: "Terminals in Mombasa and Nairobi",
          paragraphs: [
            "Mombasa departures use the main bus station near Mama Ngina Drive and nearby stages, depending on the operator. In Nairobi, most buses arrive at the CBD terminals around Accra Road, Ronald Ngala Street and River Road.",
            "Check the boarding point on your ticket before you travel. If you are connecting to another town, allow at least two hours between arrival and your next departure."
          ]
        },
        %{
          heading: "What to expect on board",
          paragraphs: [
            "Long-distance buses usually stop once or twice for a break. Amenities vary by operator and seat class, so check the icons on the bus card for AC, charging, Wi-Fi and washrooms.",
            "Carry water, a light jacket and any medication you need. Keep valuables with you rather than in the luggage compartment."
          ]
        }
      ],
      faqs: [
        %{
          question: "How long is the bus from Mombasa to Nairobi?",
          answer:
            "Most buses take 8 to 10 hours depending on the operator, departure time and traffic."
        },
        %{
          question: "Are there night buses from Mombasa to Nairobi?",
          answer:
            "Yes. Several operators run evening departures that arrive in Nairobi early the next morning."
        },
        %{
          question: "How much is a Mombasa to Nairobi bus ticket?",
          answer:
            "Normal fares usually start around KES 1,200–1,500. VIP and business seats cost more."
        }
      ]
    }
  ]

  def all, do: @posts

  def get(slug) when is_binary(slug), do: Enum.find(@posts, &(&1.slug == slug))

  def get(_), do: nil

  def slugs, do: Enum.map(@posts, & &1.slug)

  def related(current_slug) do
    @posts
    |> Enum.reject(&(&1.slug == current_slug))
    |> Enum.take(2)
  end
end
