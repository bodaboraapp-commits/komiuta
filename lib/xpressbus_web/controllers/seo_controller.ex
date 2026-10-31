defmodule XpressbusWeb.SeoController do
  use XpressbusWeb, :controller

  import Ecto.Query

  alias Xpressbus.Bookings.Bus
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
    {"faqs", "0.7", "monthly"}
  ]

  @doc "Dynamic XML sitemap for static pages plus the top bus routes."
  def sitemap(conn, _params) do
    static_urls =
      Enum.map(@static_paths, fn {path, priority, changefreq} ->
        loc = if path == "", do: SEO.base_url() <> "/", else: SEO.base_url() <> "/" <> path
        {loc, priority, changefreq}
      end)

    route_urls =
      Repo.all(
        from(b in Bus,
          where: not is_nil(b.from) and not is_nil(b.to),
          group_by: [b.from, b.to],
          select: %{from: b.from, to: b.to, count: count(b.id)},
          order_by: [desc: count(b.id)],
          limit: 55
        )
      )
      |> Enum.map(fn route ->
        {SEO.route_url(route.from, route.to), "0.9", "daily"}
      end)

    city_urls =
      XpressbusWeb.Cities.slugs()
      |> Enum.map(fn slug ->
        {SEO.base_url() <> "/cities/" <> slug, "0.8", "weekly"}
      end)

    urls = static_urls ++ city_urls ++ route_urls

    body = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{Enum.map_join(urls, "\n", &url_entry/1)}
    </urlset>
    """

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, body)
  end

  defp url_entry({loc, priority, changefreq}) do
    """
        <url>
          <loc>#{escape(loc)}</loc>
          <priority>#{priority}</priority>
          <changefreq>#{changefreq}</changefreq>
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
