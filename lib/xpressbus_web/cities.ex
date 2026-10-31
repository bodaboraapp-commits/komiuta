defmodule XpressbusWeb.Cities do
  @moduledoc """
  Curated city landing pages for SEO / AI search.

  Each entry powers `/cities/:slug`: a server-rendered page with routes, fares,
  terminals and FAQs, plus a link in the footer and XML sitemap.
  """

  @cities %{
    "nairobi" => %{
      name: "Nairobi",
      region: "Kenya",
      tagline: "Kenya's capital and the busiest intercity bus hub in East Africa.",
      terminals: "Ronald Ngala Street, Accra Road and Country Bus Station",
      intro:
        "Nairobi is the main departure point for buses to Mombasa, Kisumu, Eldoret, Nakuru, Kericho and most towns in Kenya. Compare fares, operators and departure times, then book a seat with M-PESA."
    },
    "mombasa" => %{
      name: "Mombasa",
      region: "Kenya",
      tagline: "Coastal gateway with daily buses to Nairobi, Malindi, Kilifi and Lamu.",
      terminals: "Mombasa Bus Station (Mama Ngina Drive area) and Likoni terminals",
      intro:
        "Buses from Mombasa to Nairobi run day and night. Choose a normal, business or VIP seat, pick your boarding point and pay securely with M-PESA or card."
    },
    "kisumu" => %{
      name: "Kisumu",
      region: "Kenya",
      tagline: "Lake Victoria's largest city, connected to Nairobi, Eldoret and Mombasa.",
      terminals: "Kisumu Bus Park and Kondele stage",
      intro:
        "Travelling from Kisumu to Nairobi, Eldoret or Mombasa? Compare daily departures and fares from trusted operators on Komiuta."
    },
    "eldoret" => %{
      name: "Eldoret",
      region: "Kenya",
      tagline: "Rift Valley hub with fast buses to Nairobi, Kitale and Kisumu.",
      terminals: "Eldoret Main Bus Stage and Uganda Road terminals",
      intro:
        "Book Eldoret to Nairobi, Kisumu or Kitale bus tickets online. Compare operators, departure times and seat classes before paying with M-PESA."
    },
    "nakuru" => %{
      name: "Nakuru",
      region: "Kenya",
      tagline: "Central Rift Valley stop with frequent buses to Nairobi and Eldoret.",
      terminals: "Nakuru Bus Station and KFA roundabout stages",
      intro:
        "Find buses from Nakuru to Nairobi, Eldoret, Kisumu and Kericho, compare fares and reserve a seat in minutes."
    },
    "kitale" => %{
      name: "Kitale",
      region: "Kenya",
      tagline: "Trans Nzoia farming hub with buses to Nairobi, Eldoret and Kisumu.",
      terminals: "Kitale Main Bus Station",
      intro:
        "Book Kitale to Nairobi, Eldoret or Kisumu bus tickets online. Compare operators, departure times and fares before paying securely with M-PESA."
    },
    "kericho" => %{
      name: "Kericho",
      region: "Kenya",
      tagline: "Tea-country town with direct services to Nairobi, Kisumu and Nakuru.",
      terminals: "Kericho Main Bus Stage",
      intro:
        "Book Kericho to Nairobi and Kisumu bus tickets online, with live seat availability and secure M-PESA payment."
    }
  }

  def all, do: @cities

  def get(slug), do: Map.get(@cities, to_string(slug))

  def slugs, do: Map.keys(@cities)
end
