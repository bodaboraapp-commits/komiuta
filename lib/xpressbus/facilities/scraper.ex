defmodule Xpressbus.Facilities.Scraper do
  @moduledoc """
  Pulls facility data for the Xpressbus application.

  BuuPass is a single-page Angular app with no static facilities list, so the
  scraper attempts a handful of likely endpoints and falls back to a curated
  list of facilities commonly advertised by BuuPass operators.
  """

  require Logger
  alias Xpressbus.Repo
  alias Xpressbus.Facilities
  alias Xpressbus.Facilities.Facility

  @user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"

  @candidate_urls [
    "https://buupass.com/amenities",
    "https://buupass.com/facilities",
    "https://buupass.com/bus-types",
    "https://buupass.com/features"
  ]

  @fallback_facilities [
    %{
      name: "Air Conditioning",
      icon: "ac_unit",
      description: "Climate-controlled cabin for a comfortable ride."
    },
    %{name: "Wi-Fi", icon: "wifi", description: "Stay connected with on-board Wi-Fi."},
    %{name: "Charging Ports", icon: "power", description: "USB / power outlets at every seat."},
    %{
      name: "Reclining Seats",
      icon: "event_seat",
      description: "Spacious reclining seats with extra legroom."
    },
    %{
      name: "On-board Entertainment",
      icon: "tv",
      description: "Personal screens with music and video."
    },
    %{name: "Restroom", icon: "wc", description: "Clean on-board washroom facilities."},
    %{
      name: "Bottled Water",
      icon: "local_drink",
      description: "Complimentary bottled water for passengers."
    },
    %{
      name: "Snacks",
      icon: "restaurant",
      description: "Light snacks and refreshments available."
    },
    %{
      name: "Luggage Compartment",
      icon: "luggage",
      description: "Secure under-bus luggage storage."
    },
    %{
      name: "Reading Light",
      icon: "lightbulb",
      description: "Personal reading light for night travel."
    },
    %{
      name: "Blanket & Pillow",
      icon: "bed",
      description: "Soft blanket and pillow provided on long trips."
    },
    %{
      name: "GPS Tracking",
      icon: "gps_fixed",
      description: "Real-time GPS tracking for safety and updates."
    }
  ]

  def sync do
    facilities =
      case fetch_live() do
        [] -> @fallback_facilities
        live -> live
      end

    save_facilities(facilities)
    Facilities.list_facilities()
  end

  defp fetch_live do
    Enum.find_value(@candidate_urls, [], fn url ->
      case Req.get(url,
             headers: [{"user-agent", @user_agent}],
             redirect: true,
             receive_timeout: 15_000
           ) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          parsed = parse_html(body)
          if parsed == [], do: nil, else: parsed

        _ ->
          nil
      end
    end)
    |> case do
      [] ->
        Logger.warning("⚠️ Facilities scraper: no live data, using curated fallback set.")
        []

      facilities ->
        Logger.info("✅ Facilities scraper pulled #{length(facilities)} facilities from BuuPass.")
        facilities
    end
  end

  defp parse_html(html) do
    case Floki.parse_document(html) do
      {:ok, document} ->
        document
        |> Floki.find(
          "li, .facility, .amenity, [class*='Facility'], [class*='Amenity'], [class*='Feature']"
        )
        |> Enum.map(&extract_facility/1)
        |> Enum.reject(&is_nil/1)

      {:error, _} ->
        []
    end
  end

  defp extract_facility(node) do
    name = node |> Floki.text() |> String.trim() |> String.replace(~r/\s+/, " ")

    cond do
      name == "" -> nil
      String.length(name) > 80 -> nil
      true -> %{name: name, icon: nil, description: nil}
    end
  end

  defp save_facilities(facilities) do
    Enum.each(facilities, fn attrs ->
      attrs =
        attrs
        |> Map.put(:active, true)
        |> Map.delete(:icon)
        |> Map.delete(:description)
        |> Map.put_new(:icon, nil)
        |> Map.put_new(:description, nil)

      case Repo.get_by(Facility, name: attrs.name) do
        nil ->
          %Facility{}
          |> Facility.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> Ecto.Changeset.change(%{active: true})
          |> Repo.update()
      end
    end)
  end
end
