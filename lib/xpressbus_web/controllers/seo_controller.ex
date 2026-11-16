defmodule XpressbusWeb.SeoController do
  use XpressbusWeb, :controller

  import Ecto.Query

  alias Xpressbus.Bookings.Search
  alias Xpressbus.Chyllz
  alias Xpressbus.Repo
  alias XpressbusWeb.SEO

  @static_paths [
    {"", "1.0", "daily"},
    {"tour-packages", "0.8", "weekly"},
    {"tour-packages/insurance", "0.8", "weekly"},
    {"tour-packages/hotels", "0.7", "weekly"},
    {"our-packages/hidden-gems", "0.7", "weekly"},
    {"tour-packages/car", "0.7", "weekly"},
    {"tour-packages/events", "0.7", "weekly"},
    {"terms", "0.3", "yearly"},
    {"privacy", "0.3", "yearly"},
    {"faqs", "0.7", "monthly"},
    {"about", "0.6", "monthly"},
    {"blog", "0.7", "weekly"},
    {"operators", "0.7", "weekly"},
    {"agent", "0.5", "monthly"}
  ]

  @doc "Dynamic XML sitemap for every public page, route, city and listing."
  def sitemap(conn, _params) do
    static_urls =
      Enum.map(@static_paths, fn {path, priority, changefreq} ->
        loc = if path == "", do: SEO.base_url() <> "/", else: SEO.base_url() <> "/" <> path
        {loc, priority, changefreq, nil, []}
      end)

    route_urls =
      Repo.all(
        from(b in Search.base_query(),
          where: not is_nil(b.from) and not is_nil(b.to),
          group_by: [b.from, b.to],
          select: %{from: b.from, to: b.to, count: count(b.id)},
          order_by: [desc: count(b.id)],
          limit: 55
        )
      )
      |> Enum.map(fn route ->
        {SEO.route_url(route.from, route.to), "0.9", "daily", nil, []}
      end)

    city_urls =
      XpressbusWeb.Cities.slugs()
      |> Enum.map(fn slug ->
        {SEO.base_url() <> "/cities/" <> slug, "0.8", "weekly", nil, []}
      end)

    blog_urls =
      XpressbusWeb.Blog.slugs()
      |> Enum.map(fn slug ->
        {SEO.base_url() <> "/blog/" <> slug, "0.6", "monthly", nil, []}
      end)

    operator_urls =
      XpressbusWeb.Operators.top(20)
      |> Enum.map(fn operator ->
        {SEO.base_url() <> "/operators/" <> XpressbusWeb.Operators.slug(operator.name), "0.7",
         "weekly", nil, []}
      end)

    urls =
      static_urls ++ city_urls ++ operator_urls ++ blog_urls ++ route_urls ++ listing_entries()

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
            xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
    #{Enum.map_join(urls, "\n", &url_entry/1)}
    </urlset>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, body)
  end

  @doc "Plain-text index for AI answer engines and recommendation crawlers."
  def llms(conn, _params) do
    hotels = Chyllz.hotels(limit: 60)
    gems = Chyllz.hidden_gems(limit: 60)
    cars = Chyllz.car_hires(limit: 60)
    events = Chyllz.upcoming_events(limit: 100)

    body = """
    # KOMIUTA — Bus tickets, hotels, hidden gems, car hire and events in Kenya

    > KOMIUTA is a Kenyan travel and transport platform. It sells intercity bus tickets
    > with M-PESA and curates hotels, hidden gems, car hire and events under the Chyllz brand.
    > All prices are in Kenyan shillings (KES). Public pages listed below are safe to quote.

    ## Bus tickets
    - [Search bus routes and fares](#{SEO.base_url()}/)
    - [Track a ticket](#{SEO.base_url()}/tickets)
    - [Bus cities in Kenya](#{SEO.base_url()}/cities)

    ## Hotels in Kenya (Chyllz)
    #{Enum.map_join(hotels, "\n", &llms_line("hotel", &1))}

    ## Hidden gems in Kenya (Chyllz)
    #{Enum.map_join(gems, "\n", &llms_line("hidden_gem", &1))}

    ## Car hire (Chyllz)
    #{Enum.map_join(cars, "\n", &llms_line("car_hire", &1))}

    ## Events (Chyllz)
    #{Enum.map_join(events, "\n", &llms_line("event", &1))}

    Contact: hello@komiuta.com · +254 800 211 211
    """

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body)
  end

  @doc "OpenSearch description so browsers and feed readers can discover site search."
  def opensearch(conn, _params) do
    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
      <ShortName>KOMIUTA</ShortName>
      <Description>Search bus tickets, hotels, hidden gems, car hire and events across Kenya.</Description>
      <InputEncoding>UTF-8</InputEncoding>
      <Image height="32" width="32" type="image/png">#{SEO.base_url()}/images/favicon-32.png</Image>
      <Url type="text/html" template="#{SEO.base_url()}/?q={searchTerms}" />
      <Url type="application/atom+xml" template="#{SEO.base_url()}/feeds/listings.xml?q={searchTerms}" />
    </OpenSearchDescription>
    """

    conn
    |> put_resp_content_type("application/opensearchdescription+xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body)
  end

  @doc "Atom feed of the latest Chyllz listings for feed readers and recommender services."
  def listings_feed(conn, _params) do
    hotels = Chyllz.hotels(limit: 20)
    gems = Chyllz.hidden_gems(limit: 20)
    cars = Chyllz.car_hires(limit: 12)
    events = Chyllz.upcoming_events(limit: 12)

    entries =
      Enum.flat_map(
        [{"hotel", hotels}, {"hidden_gem", gems}, {"car_hire", cars}, {"event", events}],
        fn {kind, items} -> Enum.map(items, &feed_entry(kind, &1)) end
      )
      |> Enum.sort_by(& &1.updated, :desc)
      |> Enum.take(40)

    body = """
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>KOMIUTA listings — hotels, hidden gems, car hire and events</title>
      <subtitle>Latest curated travel listings from Chyllz by KOMIUTA.</subtitle>
      <id>#{SEO.base_url()}/feeds/listings.xml</id>
      <link href="#{SEO.base_url()}/feeds/listings.xml" rel="self" />
      <link href="#{SEO.base_url()}/tour-packages" rel="alternate" />
      <updated>#{DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()}</updated>
      <author>
        <name>KOMIUTA</name>
        <uri>#{SEO.base_url()}</uri>
      </author>
    #{Enum.map_join(entries, "\n", &feed_entry_xml/1)}
    </feed>
    """

    conn
    |> put_resp_content_type("application/atom+xml")
    |> put_resp_header("cache-control", "public, max-age=900")
    |> send_resp(200, body)
  end

  defp listing_entries do
    hotels = Chyllz.hotels(limit: 60) |> Enum.map(&listing_entry("hotel", &1))
    gems = Chyllz.hidden_gems(limit: 60) |> Enum.map(&listing_entry("hidden_gem", &1))
    cars = Chyllz.car_hires(limit: 60) |> Enum.map(&listing_entry("car_hire", &1))
    events = Chyllz.upcoming_events(limit: 100) |> Enum.map(&listing_entry("event", &1))
    hotels ++ gems ++ cars ++ events
  end

  defp listing_entry(kind, item) do
    image = kind |> SEO.listing_image(item) |> SEO.absolute_url()
    lastmod = item.updated_at && Calendar.strftime(item.updated_at, "%Y-%m-%d")
    {SEO.listing_url(kind, item), "0.8", "weekly", lastmod, List.wrap(image)}
  end

  defp llms_line(kind, item) do
    "- [#{SEO.listing_name(kind, item)}](#{SEO.listing_url(kind, item)}): " <>
      (Map.get(item, :description) || "") |> String.replace(~r/\s+/, " ") |> String.slice(0, 220)
  end

  defp feed_entry(kind, item) do
    %{
      kind: kind,
      title: SEO.listing_name(kind, item),
      url: SEO.listing_url(kind, item),
      summary: Map.get(item, :description) || "",
      updated: item.updated_at || DateTime.utc_now()
    }
  end

  defp feed_entry_xml(entry) do
    """
        <entry>
          <title>#{escape(entry.title)}</title>
          <link href="#{escape(entry.url)}" />
          <id>#{escape(entry.url)}</id>
          <updated>#{entry.updated |> DateTime.truncate(:second) |> DateTime.to_iso8601()}</updated>
          <summary>#{escape(entry.summary)}</summary>
        </entry>\
    """
  end

  defp url_entry({loc, priority, changefreq, lastmod, images}) do
    lastmod_tag =
      case lastmod do
        nil -> ""
        date -> "\n      <lastmod>#{escape(date)}</lastmod>"
      end

    images =
      Enum.map_join(List.wrap(images), "", fn image ->
        "\n      <image:image><image:loc>#{escape(image)}</image:loc></image:image>"
      end)

    """
        <url>
          <loc>#{escape(loc)}</loc>#{lastmod_tag}
          <priority>#{priority}</priority>
          <changefreq>#{changefreq}</changefreq>#{images}
        </url>\
    """
  end

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
