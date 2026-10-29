defmodule Xpressbus.CatalogueFixtures do
  @moduledoc """
  Test helpers for the Chyllz catalogue and the InSURE insurance catalogue.

  Names/questions are made unique so fixtures never collide with the defaults
  inserted by the insurance migration or with each other.
  """

  alias Xpressbus.{CarHires, Events, HiddenGems, Hotels, Insurance}

  @doc "Generates an active hotel, overridable through `attrs`."
  def hotel_fixture(attrs \\ %{}) do
    {:ok, hotel} =
      attrs
      |> Enum.into(%{
        name: "Hotel #{System.unique_integer([:positive])}",
        price_per_night: "12500",
        rating: "4.8",
        location: "Nairobi",
        description: "A boutique stay with skyline views.",
        amenities: ["Wi-Fi", "Pool", "Spa"],
        images: [],
        active: true
      })
      |> Hotels.create_hotel()

    hotel
  end

  @doc "Generates an active hidden gem, overridable through `attrs`."
  def hidden_gem_fixture(attrs \\ %{}) do
    {:ok, gem} =
      attrs
      |> Enum.into(%{
        title: "Gem #{System.unique_integer([:positive])}",
        location: "Lamu",
        description: "A serene Swahili coast escape.",
        images: [],
        active: true
      })
      |> HiddenGems.create_hidden_gem()

    gem
  end

  @doc "Generates an active car hire offer, overridable through `attrs`."
  def car_hire_fixture(attrs \\ %{}) do
    {:ok, car} =
      attrs
      |> Enum.into(%{
        car_name: "Toyota Rav4 #{System.unique_integer([:positive])}",
        type: "Compact 4x4",
        price_per_day: "8500",
        location: "Nairobi",
        active: true
      })
      |> CarHires.create_car_hire()

    car
  end

  @doc """
  Generates an active event.

  Defaults to two weeks in the future so `upcoming_events/1` picks it up;
  pass `%{date: ~D[...]}` to create a past event.
  """
  def event_fixture(attrs \\ %{}) do
    {:ok, event} =
      attrs
      |> Enum.into(%{
        title: "Event #{System.unique_integer([:positive])}",
        date: Date.add(Date.utc_today(), 14),
        location: "Naivasha",
        description: "A festival for the whole family.",
        images: [],
        active: true
      })
      |> Events.create_event()

    event
  end

  @doc "Generates an insurance plan, overridable through `attrs`."
  def insurance_plan_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, plan} =
      attrs
      |> Enum.into(%{
        name: "Plan #{unique}",
        price: "1500",
        period: "per trip",
        tagline: "Test cover",
        features: ["Trip cancellation up to Ksh 100,000", "24/7 Emergency assistance"],
        coverage: [
          %{"label" => "Trip Cancellation", "value" => "Ksh 100,000"},
          %{"label" => "Medical Expenses", "value" => "Ksh 500,000"},
          %{"label" => "24/7 Emergency Assist", "value" => "Included"}
        ],
        popular: false,
        active: true,
        position: unique
      })
      |> Insurance.create_plan()

    plan
  end

  @doc "Generates an insurance FAQ, overridable through `attrs`."
  def insurance_faq_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, faq} =
      attrs
      |> Enum.into(%{
        question: "Question #{unique}?",
        answer: "A clear, helpful answer.",
        position: unique,
        active: true
      })
      |> Insurance.create_faq()

    faq
  end
end
