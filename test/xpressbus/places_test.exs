defmodule Xpressbus.PlacesTest do
  use Xpressbus.DataCase, async: false

  alias Xpressbus.Places

  setup do
    Places.reset_cache()

    ai_config = Application.get_env(:xpressbus, :ai)
    override = Application.get_env(:xpressbus, :places_search_override)

    on_exit(fn ->
      Places.reset_cache()
      restore_env(:ai, ai_config)
      restore_env(:places_search_override, override)
    end)

    :ok
  end

  describe "search/2" do
    test "returns real geocoded places with labels and coordinates" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v1/search"
        assert conn.query_string =~ "name=Paris"

        Req.Test.json(conn, %{
          "results" => [
            %{
              "name" => "Paris",
              "country" => "France",
              "admin1" => "Île-de-France",
              "latitude" => 48.8566,
              "longitude" => 2.3522,
              "timezone" => "Europe/Paris",
              "population" => 2_138_551
            },
            %{
              "name" => "Paris",
              "country" => "United States",
              "admin1" => "Texas",
              "latitude" => 33.6609,
              "longitude" => -95.5555
            }
          ]
        })
      end)

      assert {:ok, [paris | _rest] = places} =
               Places.search("Paris", req_options: [plug: {Req.Test, __MODULE__}])

      assert length(places) == 2
      assert paris.name == "Paris"
      assert paris.country == "France"
      assert paris.label == "Paris, Île-de-France, France"
      assert paris.latitude == 48.8566
      assert paris.source == :geocoding
    end

    test "short queries never call the network" do
      Req.Test.stub(__MODULE__, fn _conn -> flunk("the geocoder must not be called") end)

      assert {:ok, []} = Places.search("p", req_options: [plug: {Req.Test, __MODULE__}])
    end

    test "returns an empty list when the geocoder has no match" do
      Req.Test.stub(__MODULE__, fn conn -> Req.Test.json(conn, %{"results" => []}) end)

      assert {:ok, []} = Places.search("zzzz", req_options: [plug: {Req.Test, __MODULE__}])
    end

    test "returns an error tuple when the geocoder is unavailable" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"error" => "unavailable"})
      end)

      assert {:error, {:http_status, 503}} =
               Places.search("Nairobi", req_options: [plug: {Req.Test, __MODULE__}])
    end

    test "the test override injects real-looking results without HTTP" do
      Application.put_env(:xpressbus, :places_search_override, fn _query ->
        [
          %{
            name: "Zanzibar City",
            country: "Tanzania",
            region: "Zanzibar Urban/West",
            latitude: -6.1659,
            longitude: 39.2026
          }
        ]
      end)

      assert {:ok, [place]} = Places.search("zanzibar")
      assert place.name == "Zanzibar City"
      assert place.label == "Zanzibar City, Zanzibar Urban/West, Tanzania"
    end
  end

  describe "resolve/2" do
    test "returns the best geocoded match" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "results" => [
            %{
              "name" => "Nairobi",
              "country" => "Kenya",
              "admin1" => "Nairobi County",
              "latitude" => -1.2921,
              "longitude" => 36.8219
            }
          ]
        })
      end)

      assert {:ok, place, [place]} =
               Places.resolve("Nairobi", req_options: [plug: {Req.Test, __MODULE__}])

      assert place.name == "Nairobi"
      assert place.country == "Kenya"
    end

    test "falls back to the AI model for landmarks and natural-language queries" do
      configure_ai(req_options: [plug: {Req.Test, __MODULE__}])

      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/v1/search" ->
            query = URI.decode_query(conn.query_string)["name"] || ""

            if String.downcase(query) == "paris" do
              Req.Test.json(conn, %{
                "results" => [
                  %{
                    "name" => "Paris",
                    "country" => "France",
                    "admin1" => "Île-de-France",
                    "latitude" => 48.8566,
                    "longitude" => 2.3522
                  }
                ]
              })
            else
              Req.Test.json(conn, %{"results" => []})
            end

          "/search" ->
            # Nominatim has no match for this query; the AI fallback takes over.
            Req.Test.json(conn, [])

          "/v1/chat/completions" ->
            Req.Test.json(conn, %{
              "choices" => [
                %{
                  "message" => %{
                    "content" => ~s([{"name": "Paris", "country": "France"}])
                  }
                }
              ]
            })
        end
      end)

      assert {:ok, place, _all} =
               Places.resolve("the city of lights",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )

      assert place.name == "Paris"
      assert place.country == "France"
      assert place.source == :ai
    end

    test "falls back to OpenStreetMap for landmarks the city geocoder cannot match" do
      Req.Test.stub(__MODULE__, fn conn ->
        case conn.request_path do
          "/v1/search" ->
            Req.Test.json(conn, %{"results" => []})

          "/search" ->
            assert conn.query_string =~ "eiffel"

            assert Plug.Conn.get_req_header(conn, "user-agent") == [
                     "KomiutaTripBuilder/1.0 (+https://www.komiuta.com)"
                   ]

            Req.Test.json(conn, [
              %{
                "name" => "Eiffel Tower",
                "display_name" => "Eiffel Tower, 5, Avenue Anatole France, Paris, France",
                "lat" => "48.8582599",
                "lon" => "2.2945006",
                "address" => %{
                  "country" => "France",
                  "state" => "Île-de-France",
                  "city" => "Paris"
                }
              }
            ])
        end
      end)

      assert {:ok, place, _all} =
               Places.resolve("eiffel tower", req_options: [plug: {Req.Test, __MODULE__}])

      assert place.name == "Eiffel Tower"
      assert place.country == "France"
      assert place.region == "Île-de-France"
      assert place.source == :osm
      assert place.latitude == 48.8582599
    end

    test "returns :not_found when AI is not configured and geocoding finds nothing" do
      Req.Test.stub(__MODULE__, fn conn -> Req.Test.json(conn, %{"results" => []}) end)

      assert {:error, :not_found} =
               Places.resolve("the city of lights",
                 req_options: [plug: {Req.Test, __MODULE__}]
               )
    end
  end

  defp configure_ai(overrides) do
    config =
      Application.get_env(:xpressbus, :ai, %{})
      |> Map.merge(%{
        enabled: true,
        api_key: "test-key",
        base_url: "https://api.test/v1"
      })
      |> Map.merge(Map.new(overrides))

    Application.put_env(:xpressbus, :ai, config)
  end

  defp restore_env(key, nil), do: Application.delete_env(:xpressbus, key)
  defp restore_env(key, value), do: Application.put_env(:xpressbus, key, value)
end
