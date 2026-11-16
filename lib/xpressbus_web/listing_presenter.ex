defmodule XpressbusWeb.ListingPresenter do
  @moduledoc "Normalises Chyllz catalogue rows for public listing pages."

  alias Xpressbus.Chyllz
  alias XpressbusWeb.SEO

  def all("hotel"), do: Chyllz.hotels(limit: 60)
  def all("hidden_gem"), do: Chyllz.hidden_gems(limit: 60)
  def all("car_hire"), do: Chyllz.car_hires(limit: 60)

  def all("event") do
    Chyllz.upcoming_events(limit: 100) ++ Chyllz.past_events(limit: 100)
  end

  def find(kind, slug) do
    Enum.find(all(kind), &(SEO.listing_slug(kind, &1) == slug))
  end

  def to_map(kind, item) do
    %{
      kind: kind,
      name: SEO.listing_name(kind, item),
      location: Map.get(item, :location) || Map.get(item, :region),
      description: Map.get(item, :description),
      image: SEO.listing_image(kind, item),
      image_url: SEO.listing_image(kind, item) |> SEO.absolute_url(),
      rating: rating(item),
      reviews: Map.get(item, :review_count),
      details: SEO.listing_details(kind, item),
      maps_url: SEO.listing_maps_url(kind, item),
      website_url: SEO.listing_website_url(kind, item),
      path: SEO.listing_path(kind, item),
      url: SEO.listing_url(kind, item),
      kind_label: SEO.listing_label(kind),
      index_path: SEO.listing_index_path(kind),
      date_label: Map.get(item, :date) && Calendar.strftime(item.date, "%d %b %Y"),
      category: Map.get(item, :category),
      region: Map.get(item, :region)
    }
  end

  def meta_title(kind, item) do
    label = SEO.listing_label(kind)
    location = Map.get(item, :location) || Map.get(item, :region) || "Kenya"
    "#{SEO.listing_name(kind, item)} — #{label} in #{location}"
  end

  def meta_description(kind, item) do
    name = SEO.listing_name(kind, item)
    location = Map.get(item, :location) || Map.get(item, :region) || "Kenya"
    description = Map.get(item, :description) || ""

    String.slice("#{name} in #{location}: #{description} Book with Chyllz by KOMIUTA.", 0, 300)
  end

  def related(kind, item, limit \\ 3) do
    location = Map.get(item, :location) || Map.get(item, :region)

    same_region =
      all(kind)
      |> Enum.reject(&(&1.id == item.id))
      |> Enum.filter(&((Map.get(&1, :location) || Map.get(&1, :region)) == location))

    pool = same_region ++ Enum.reject(all(kind), &(&1.id == item.id))
    pool |> Enum.uniq_by(& &1.id) |> Enum.take(limit) |> Enum.map(&to_map(kind, &1))
  end

  defp rating(item) do
    case Map.get(item, :rating) do
      %Decimal{} = rating -> Decimal.to_float(rating) |> Float.round(1)
      rating when is_float(rating) or is_integer(rating) -> rating
      _other -> nil
    end
  end
end
