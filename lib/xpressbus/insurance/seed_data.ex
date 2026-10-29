defmodule Xpressbus.Insurance.SeedData do
  @moduledoc """
  The default InSURE catalogue shipped with a fresh database.

  This module is the single source of truth for the launch content of the
  insurance page. It is used by:

    * the `create_insurance_tables` migration, so a production deploy that
      only runs `mix ecto.migrate` is never left with an empty insurance page;
    * `Xpressbus.Insurance.ensure_defaults/0`, which makes the seed idempotent
      and can be re-run safely;
    * `priv/repo/seeds.exs`, so development resets stay in sync.

  Content is intentionally data (not markup) so it can be replaced through the
  admin catalogue without a code change.
  """

  @plans [
    %{
      name: "Essential",
      price: Decimal.new("1500"),
      period: "per trip",
      tagline: "Smart cover for a single journey.",
      position: 1,
      popular: false,
      features: [
        "Trip cancellation up to Ksh 100,000",
        "Medical expenses up to Ksh 500,000",
        "Baggage loss up to Ksh 50,000",
        "24/7 Emergency assistance",
        "Flight delay compensation",
        "Personal liability cover"
      ],
      coverage: [
        %{"label" => "Trip Cancellation", "value" => "Ksh 100,000"},
        %{"label" => "Medical Expenses", "value" => "Ksh 500,000"},
        %{"label" => "Baggage Loss/Delay", "value" => "Ksh 50,000"},
        %{"label" => "Flight Delay (>6 hrs)", "value" => "Ksh 10,000"},
        %{"label" => "Personal Liability", "value" => "Ksh 500,000"},
        %{"label" => "Rental Car Excess", "value" => "—"},
        %{"label" => "Adventure Sports", "value" => "—"},
        %{"label" => "Gadget Protection", "value" => "—"},
        %{"label" => "24/7 Emergency Assist", "value" => "Included"}
      ]
    },
    %{
      name: "Comprehensive",
      price: Decimal.new("3500"),
      period: "per trip",
      tagline: "Our most popular all-round cover.",
      position: 2,
      popular: true,
      features: [
        "Trip cancellation up to Ksh 300,000",
        "Medical expenses up to Ksh 2,000,000",
        "Baggage loss up to Ksh 150,000",
        "24/7 Emergency assistance",
        "Flight delay compensation",
        "Personal liability cover",
        "Rental car excess cover",
        "Adventure sports cover",
        "Gadget protection up to Ksh 100,000"
      ],
      coverage: [
        %{"label" => "Trip Cancellation", "value" => "Ksh 300,000"},
        %{"label" => "Medical Expenses", "value" => "Ksh 2,000,000"},
        %{"label" => "Baggage Loss/Delay", "value" => "Ksh 150,000"},
        %{"label" => "Flight Delay (>6 hrs)", "value" => "Ksh 25,000"},
        %{"label" => "Personal Liability", "value" => "Ksh 1,000,000"},
        %{"label" => "Rental Car Excess", "value" => "Ksh 100,000"},
        %{"label" => "Adventure Sports", "value" => "Included"},
        %{"label" => "Gadget Protection", "value" => "Ksh 100,000"},
        %{"label" => "24/7 Emergency Assist", "value" => "Included"}
      ]
    },
    %{
      name: "Annual Multi-Trip",
      price: Decimal.new("12000"),
      period: "per year",
      tagline: "For frequent travellers and families.",
      position: 3,
      popular: false,
      features: [
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
      ],
      coverage: [
        %{"label" => "Trip Cancellation", "value" => "Ksh 500,000"},
        %{"label" => "Medical Expenses", "value" => "Ksh 5,000,000"},
        %{"label" => "Baggage Loss/Delay", "value" => "Ksh 200,000"},
        %{"label" => "Flight Delay (>6 hrs)", "value" => "Ksh 30,000"},
        %{"label" => "Personal Liability", "value" => "Ksh 2,000,000"},
        %{"label" => "Rental Car Excess", "value" => "Ksh 150,000"},
        %{"label" => "Adventure Sports", "value" => "Included"},
        %{"label" => "Gadget Protection", "value" => "Ksh 200,000"},
        %{"label" => "24/7 Emergency Assist", "value" => "Included"}
      ]
    }
  ]

  @faqs [
    %{
      question: "When should I purchase travel insurance?",
      answer:
        "We recommend purchasing insurance as soon as you book your trip. This ensures you're covered for trip cancellation from the moment you buy. You can purchase up to 24 hours before departure, but pre-existing conditions and some benefits may not apply.",
      position: 1
    },
    %{
      question: "Does insurance cover COVID-19 related issues?",
      answer:
        "Yes, our Comprehensive and Annual plans cover COVID-19 related medical expenses, trip cancellation if you test positive before travel, and quarantine accommodation costs (up to policy limits). The Essential plan has limited pandemic coverage.",
      position: 2
    },
    %{
      question: "Can I get a refund if I don't travel?",
      answer:
        "You can cancel your policy for a full refund within 14 days of purchase (free-look period), provided you haven't started your trip or made a claim. After 14 days, refunds are only available if the trip is cancelled for a covered reason.",
      position: 3
    },
    %{
      question: "How do I make a claim?",
      answer:
        "Contact our 24/7 claims hotline or submit online via the Komiuta app. You'll need your policy number, travel documents, and supporting evidence (medical reports, receipts, police reports for theft). Claims are typically processed within 10 business days.",
      position: 4
    },
    %{
      question: "Am I covered for adventure activities?",
      answer:
        "The Essential plan excludes adventure sports. Comprehensive and Annual plans cover activities like safari, hiking, zip-lining, snorkeling, and skiing. Extreme sports (bungee jumping, skydiving, scuba >30m) require an additional rider.",
      position: 5
    },
    %{
      question: "Can I extend coverage mid-trip?",
      answer:
        "Yes, you can extend your Annual plan or upgrade from Essential to Comprehensive mid-trip via the app, subject to underwriting approval. Contact support at least 48 hours before your current coverage expires.",
      position: 6
    }
  ]

  @doc "The default insurance plans, in display order."
  def plans, do: @plans

  @doc "The default insurance FAQs, in display order."
  def faqs, do: @faqs
end
