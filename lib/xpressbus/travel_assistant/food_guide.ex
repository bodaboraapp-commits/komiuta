defmodule Xpressbus.TravelAssistant.FoodGuide do
  @moduledoc """
  Small, curated food knowledge base used by the assistant's Food tab.

  This is deliberately *not* a list of invented restaurants. It only describes
  well-known East African dishes and how they are usually served, so the
  assistant can give honest recommendations even when no external AI provider
  is configured. Venue suggestions always come from the live Chyllz catalogue
  (which is managed in the admin), never from this module.

  Region tags are coarse on purpose: the assistant maps a destination to a
  culinary region and then filters by diet and budget.
  """

  @dishes [
    # Coast — Swahili kitchen
    %{
      name: "Biryani",
      region: :coast,
      diet: [:meat, :seafood],
      note: "Spiced rice slow-cooked with beef, chicken or fish; a Swahili coast staple."
    },
    %{
      name: "Pilau",
      region: :coast,
      diet: [:meat, :veg],
      note: "Fragrant rice with cumin and cardamom; often served with kachumbari."
    },
    %{
      name: "Mahamri & mbaazi",
      region: :coast,
      diet: [:veg],
      note: "Cardamom doughnuts with coconut pigeon peas — a classic coastal breakfast."
    },
    %{
      name: "Viazi karai",
      region: :coast,
      diet: [:veg],
      note: "Turmeric-battered potatoes with tamarind chutney; perfect street snack."
    },
    %{
      name: "Grilled seafood",
      region: :coast,
      diet: [:seafood],
      note: "Red snapper, prawns or octopus grilled with lime and garlic."
    },
    %{
      name: "Urojo (Zanzibar mix)",
      region: :coast,
      diet: [:veg],
      note: "Tangy tamarind soup with bhajia, cassava and chutneys."
    },
    %{
      name: "Coconut fish curry",
      region: :coast,
      diet: [:seafood],
      note: "Fish simmered in coconut milk with curry leaves and chilli."
    },

    # Nairobi / Central — city comfort food
    %{
      name: "Nyama choma",
      region: :central,
      diet: [:meat],
      note: "Charcoal-grilled goat or beef, served with kachumbari and ugali."
    },
    %{
      name: "Mutura",
      region: :central,
      diet: [:meat],
      note: "Spiced sausage grilled over coals; a beloved evening street bite."
    },
    %{
      name: "Samosa & bhajia",
      region: :central,
      diet: [:veg],
      note: "Crisp pastries and spiced potato fritters, usually with tamarind dip."
    },
    %{
      name: "Chapati & ndengu",
      region: :central,
      diet: [:veg],
      note: "Layered chapati with green-gram stew — a filling, budget-friendly plate."
    },
    %{
      name: "Githeri",
      region: :central,
      diet: [:veg],
      note: "Maize and beans stewed with tomato, onion and greens."
    },
    %{
      name: "Ugali & sukuma wiki",
      region: :central,
      diet: [:veg],
      note: "The everyday Kenyan plate: stiff maize meal with sautéed greens."
    },
    %{
      name: "Kuku kienyeji",
      region: :central,
      diet: [:meat],
      note: "Slow-cooked free-range chicken, often stewed with ginger and garlic."
    },

    # Western Kenya / Lake Victoria
    %{
      name: "Fried tilapia",
      region: :west,
      diet: [:seafood],
      note: "Whole Lake Victoria tilapia fried or grilled, with ugali and greens."
    },
    %{
      name: "Ugali & fish",
      region: :west,
      diet: [:seafood],
      note: "The lakeside classic — share a whole fish and eat with your hands."
    },
    %{
      name: "Mukimo",
      region: :central,
      diet: [:veg],
      note: "Mashed potatoes, maize and greens, often served with grilled meat."
    },
    %{
      name: "Amatoke / matoke",
      region: :west,
      diet: [:veg],
      note: "Steamed green bananas, sometimes in a rich peanut or beef stew."
    },

    # Rift Valley
    %{
      name: "Grilled trout",
      region: :rift,
      diet: [:seafood],
      note: "Fresh trout from the Rift Valley rivers, simply grilled with lemon."
    },
    %{
      name: "Kienyeji chicken stew",
      region: :rift,
      diet: [:meat],
      note: "Farm chicken stewed with vegetables — a Sunday favourite."
    },
    %{
      name: "Mursik & millet",
      region: :rift,
      diet: [:veg],
      note: "Fermented milk served with millet meal; a Kalenjin tradition."
    },

    # Uganda / Tanzania / Rwanda
    %{
      name: "Rolex",
      region: :uganda,
      diet: [:veg],
      note: "Chapati rolled with eggs, cabbage and tomato — Uganda's favourite street food."
    },
    %{
      name: "Luwombo",
      region: :uganda,
      diet: [:meat],
      note: "Chicken or beef steamed in banana leaves with groundnut sauce."
    },
    %{
      name: "Nyama choma & kachumbari",
      region: :tanzania,
      diet: [:meat],
      note: "Tanzania's grilled-meat social meal, best shared with friends."
    },
    %{
      name: "Zanzibar pizza",
      region: :tanzania,
      diet: [:veg],
      note: "Street-side folded pizza with egg, cheese and vegetables."
    },
    %{
      name: "Isombe",
      region: :rwanda,
      diet: [:veg],
      note: "Cassava leaves cooked with onions, spinach and sometimes peanut."
    },
    %{
      name: "Brochettes",
      region: :rwanda,
      diet: [:meat],
      note: "Skewered beef or goat grilled over charcoal, served with fried plantain."
    }
  ]

  @coast ~w(mombasa diani lamu malindi watamu kilifi zanzibar tanga dar es salaam paje kizingo)
  @west ~w(kisumu kakamega bungoma busia kisii homa bay migori)
  @rift ~w(naivasha nakuru eldoret kericho kitale iten kabarnet)
  @uganda ~w(kampala jinja entebbe)
  @tanzania ~w(tanzania arusha moshi dodoma)
  @rwanda ~w(kigali rwanda)

  @doc "Returns the culinary region atom for a free-text location."
  def region_for(nil), do: :central

  def region_for(location) do
    normalized = location |> to_string() |> String.downcase()

    cond do
      Enum.any?(@coast, &String.contains?(normalized, &1)) -> :coast
      Enum.any?(@west, &String.contains?(normalized, &1)) -> :west
      Enum.any?(@rift, &String.contains?(normalized, &1)) -> :rift
      Enum.any?(@uganda, &String.contains?(normalized, &1)) -> :uganda
      Enum.any?(@tanzania, &String.contains?(normalized, &1)) -> :tanzania
      Enum.any?(@rwanda, &String.contains?(normalized, &1)) -> :rwanda
      String.contains?(normalized, "nairobi") -> :central
      true -> :central
    end
  end

  @doc """
  Returns dish suggestions for a destination and preference list.

  Preferences are free text (`"vegetarian"`, `"vegan"`, `"seafood"`); they are
  matched against the dish diet tags. With no preference every dish for the
  region is returned (at most `limit`).
  """
  def suggestions(location, preferences \\ [], limit \\ 5) do
    region = region_for(location)
    preferences = Enum.map(preferences, &String.downcase(to_string(&1)))

    wants_veg? = Enum.any?(preferences, &String.contains?(&1, ["veget", "vegan", "plant"]))
    wants_seafood? = Enum.any?(preferences, &String.contains?(&1, "seafood"))

    wants_meat? =
      not wants_veg? and not wants_seafood? and
        Enum.any?(preferences, &String.contains?(&1, "meat"))

    regional = Enum.filter(@dishes, &(&1.region == region))

    regional
    |> Enum.filter(fn dish ->
      cond do
        wants_veg? -> :veg in dish.diet
        wants_seafood? -> :seafood in dish.diet
        wants_meat? -> :meat in dish.diet
        true -> true
      end
    end)
    |> Enum.take(limit)
  end

  @doc "Human-readable region name for assistant copy."
  def region_label(:coast), do: "the Swahili coast"
  def region_label(:central), do: "central Kenya"
  def region_label(:west), do: "western Kenya and Lake Victoria"
  def region_label(:rift), do: "the Rift Valley"
  def region_label(:uganda), do: "Uganda"
  def region_label(:tanzania), do: "Tanzania"
  def region_label(:rwanda), do: "Rwanda"
  def region_label(_region), do: "East Africa"
end
