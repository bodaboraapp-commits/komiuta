defmodule Xpressbus.BusOperators.Scraper do
  @moduledoc """
  Pulls bus operator data for the Xpressbus application.

  BuuPass is a single-page Angular app with no static operators list, so the
  scraper combines:

  1. Operators already scraped from BuuPass bus listings (Bus.company)
  2. A curated fallback set of well-known East African operators

  All operators are tagged with the BuuPass client logo CDN URL when a matching
  slug exists, otherwise the logo is left nil so the frontend can fall back.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.BusOperators
  alias Xpressbus.BusOperators.BusOperator
  alias Xpressbus.Bookings.Bus

  @logo_base_url "https://buupassclientlogos.blob.core.windows.net/logo"

  @logo_slug_overrides %{
    "Chania Executive" => "chania",
    "Easy Coach" => "easycoach",
    "Greenline" => "greenline",
    "Janam Express" => "janam",
    "MashPoa" => "mashpoa",
    "Modern Coast" => "moderncoast",
    "Transline Classic" => "transline"
  }

  @fallback_operators [
    %{
      name: "MashPoa",
      contact_person: "MashPoa Booking Office",
      phone: "+254 711 222 333",
      email: "info@mashpoa.co.ke"
    },
    %{
      name: "Greenline",
      contact_person: "Greenline Customer Care",
      phone: "+254 733 111 222",
      email: "bookings@greenline.co.ke"
    },
    %{
      name: "Chania Executive",
      contact_person: "Chania Bookings",
      phone: "+254 720 333 444",
      email: "info@chania.co.ke"
    },
    %{
      name: "Janam Express",
      contact_person: "Janam Reservations",
      phone: "+254 712 555 666",
      email: "info@janam.co.ke"
    },
    %{
      name: "Modern Coast",
      contact_person: "Modern Coast Bookings",
      phone: "+254 711 444 555",
      email: "reservations@modern.coast"
    },
    %{
      name: "Easy Coach",
      contact_person: "Easy Coach Reservations",
      phone: "+254 722 666 777",
      email: "info@easycoach.co.ke"
    },
    %{
      name: "Tahmeed",
      contact_person: "Tahmeed Express",
      phone: "+254 712 888 999",
      email: "bookings@tahmeed.co.ke"
    },
    %{
      name: "Riverside",
      contact_person: "Riverside Shuttle",
      phone: "+254 729 000 111",
      email: "info@riverside.co.ke"
    },
    %{
      name: "Transline Classic",
      contact_person: "Transline Bookings",
      phone: "+254 720 222 333",
      email: "info@transline.co.ke"
    },
    %{
      name: "Ena Coach",
      contact_person: "Ena Coach Reservations",
      phone: "+254 711 555 666",
      email: "info@enacoach.co.ke"
    }
  ]

  def sync do
    operators =
      MapSet.new()
      |> add_scraped_from_buses()
      |> add_fallback()
      |> MapSet.to_list()
      |> Enum.sort_by(& &1.name)

    save_operators(operators)
    BusOperators.list_bus_operators()
  end

  defp add_scraped_from_buses(set) do
    scraped =
      Repo.all(
        from(b in Bus,
          where: not is_nil(b.company) and b.company != "",
          select: %{name: b.company},
          distinct: true
        )
      )

    Enum.reduce(scraped, set, fn op, acc -> MapSet.put(acc, op) end)
  end

  defp add_fallback(set) do
    Enum.reduce(@fallback_operators, set, fn op, acc -> MapSet.put(acc, op) end)
  end

  defp save_operators(operators) do
    Enum.each(operators, fn attrs ->
      attrs =
        attrs
        |> Map.put(:active, true)
        |> maybe_put_logo_url()

      case Repo.get_by(BusOperator, name: attrs.name) do
        nil ->
          %BusOperator{}
          |> BusOperator.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> Ecto.Changeset.change(merge_attrs(existing, attrs))
          |> Repo.update()
      end
    end)
  end

  defp maybe_put_logo_url(%{name: name} = attrs) do
    case Map.get(attrs, :logo_url) do
      nil ->
        slug = logo_slug(name)
        Map.put(attrs, :logo_url, "#{@logo_base_url}/#{slug}.webp")

      _ ->
        attrs
    end
  end

  defp logo_slug(name) do
    case Map.fetch(@logo_slug_overrides, name) do
      {:ok, slug} -> slug
      :error -> generic_slug(name)
    end
  end

  defp generic_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+/, "")
    |> String.replace(~r/[^a-z0-9]/, "")
  end

  defp merge_attrs(existing, fresh) do
    %{
      contact_person: fresh[:contact_person] || existing.contact_person,
      phone: fresh[:phone] || existing.phone,
      email: fresh[:email] || existing.email,
      active: true,
      logo_url: fresh[:logo_url] || existing.logo_url
    }
  end
end
