defmodule XpressbusWeb.PlacePhotoTest do
  use XpressbusWeb.ConnCase

  test "serves a proxied Google place photo", %{conn: conn} do
    Application.put_env(:xpressbus, :place_photo_override, fn "places/a/photos/b" ->
      {:ok, <<137, 80, 78, 71>>, "image/png"}
    end)

    on_exit(fn -> Application.delete_env(:xpressbus, :place_photo_override) end)

    conn = get(conn, "/places/photo?ref=places%2Fa%2Fphotos%2Fb")

    assert response(conn, 200) == <<137, 80, 78, 71>>
    assert get_resp_header(conn, "content-type") |> hd() =~ "image/png"
  end

  test "rejects invalid photo references", %{conn: conn} do
    conn = get(conn, "/places/photo?ref=https%3A%2F%2Fevil.example%2Fimage.png")
    assert response(conn, 404) == "Photo unavailable"
  end
end
