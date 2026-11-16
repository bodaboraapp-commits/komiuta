defmodule XpressbusWeb.PlacePhotoController do
  @moduledoc """
  Streams a Google Places photo through the app server.

  The Places photo media URL needs the server API key, and that key must never be
  exposed in page HTML. Hotel cards therefore store a `/places/photo?ref=...`
  path and this controller fetches the image with the key server-side, caching it
  in the browser for a day.
  """

  use XpressbusWeb, :controller

  alias Xpressbus.GooglePlaces

  def show(conn, %{"ref" => ref}) do
    case GooglePlaces.fetch_photo(ref) do
      {:ok, body, content_type} ->
        conn
        |> put_resp_header(
          "cache-control",
          "public, max-age=86400, stale-while-revalidate=604800"
        )
        |> put_resp_content_type(content_type)
        |> send_resp(200, body)

      {:error, _reason} ->
        send_resp(conn, 404, "Photo unavailable")
    end
  end

  def show(conn, _params), do: send_resp(conn, 404, "Photo unavailable")
end
