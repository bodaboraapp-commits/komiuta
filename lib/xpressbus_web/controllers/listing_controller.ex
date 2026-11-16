defmodule XpressbusWeb.ListingController do
  @moduledoc "Crawlable, server-rendered pages for every Chyllz listing."

  use XpressbusWeb, :controller

  alias Xpressbus.Accounts
  alias XpressbusWeb.{ListingPresenter, SEO}

  def hotel(conn, %{"slug" => slug}), do: show(conn, "hotel", slug)
  def hidden_gem(conn, %{"slug" => slug}), do: show(conn, "hidden_gem", slug)
  def car_hire(conn, %{"slug" => slug}), do: show(conn, "car_hire", slug)
  def event(conn, %{"slug" => slug}), do: show(conn, "event", slug)

  defp show(conn, kind, slug) do
    case ListingPresenter.find(kind, slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> send_resp(404, "This listing does not exist or is no longer available.")

      item ->
        listing = ListingPresenter.to_map(kind, item)
        image = SEO.absolute_url(listing.image)

        breadcrumb =
          SEO.breadcrumb([
            {"Home", SEO.base_url() <> "/"},
            {"Chyllz", SEO.base_url() <> "/tour-packages"},
            {listing.kind_label, SEO.base_url() <> listing.index_path},
            {listing.name, listing.url}
          ])

        json_ld = [
          SEO.organization(),
          breadcrumb,
          SEO.listing_schema(kind, item, listing.url, image)
        ]

        conn
        |> assign(:page_title, ListingPresenter.meta_title(kind, item))
        |> assign(:page_description, ListingPresenter.meta_description(kind, item))
        |> assign(:page_canonical, listing.url)
        |> assign(:page_og_image, image)
        |> assign(:page_robots, "index,follow")
        |> assign(:page_json_ld, json_ld)
        |> assign(:current_user, current_user(conn))
        |> assign(:listing, listing)
        |> assign(:related, ListingPresenter.related(kind, item))
        |> render(:show)
    end
  end

  defp current_user(conn) do
    with user_id when is_binary(user_id) <- get_session(conn, :user_id),
         %{phone: phone} when is_binary(phone) <- Accounts.get_user(user_id) do
      phone
    else
      _other -> nil
    end
  end
end
