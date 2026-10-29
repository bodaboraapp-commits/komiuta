# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias Xpressbus.Repo
alias Xpressbus.Admins
alias Xpressbus.Cities
alias Xpressbus.Banners
alias Xpressbus.DropPickPoints
alias Xpressbus.Facilities
alias Xpressbus.Facilities.Scraper, as: FacilitiesScraper
alias Xpressbus.BusOperators
alias Xpressbus.BusOperators.Scraper, as: BusOperatorsScraper
alias Xpressbus.Routes
alias Xpressbus.Bookings.{Hotel, HiddenGem, CarHire, Event, Bus}

# 1. Seed Admin
admin_email = "admin@xpressbus.com"

unless Admins.get_by_email(admin_email) do
  Admins.create_admin(%{
    email: admin_email,
    hashed_password: Admins.hash_password("admin123"),
    name: "Super Admin"
  })
end

# 2. Seed Cities
cities = [
  "Nairobi",
  "Mombasa",
  "Kisumu",
  "Eldoret",
  "Nakuru",
  "Malindi",
  "Diani",
  "Kampala",
  "Arusha"
]

for city_name <- cities do
  unless Repo.get_by(Xpressbus.Cities.City, name: city_name) do
    Cities.create_city(%{name: city_name, region: "East Africa", active: true})
  end
end

# 3. Seed Drop/Pick Points
drop_pick_points_data = [
  %{
    name: "Nairobi CBD - Bus Station",
    location: "Accra Road, Nairobi",
    city: "Nairobi",
    active: true
  },
  %{
    name: "Westlands - Safaricom Plaza",
    location: "Waiyaki Way, Westlands",
    city: "Nairobi",
    active: true
  },
  %{
    name: "Mombasa - Mombasa Bus Terminal",
    location: "Moi Avenue, Mombasa",
    city: "Mombasa",
    active: true
  },
  %{
    name: "Nyali - Nakumatt Junction",
    location: "Nyali Road, Mombasa",
    city: "Mombasa",
    active: true
  },
  %{
    name: "Kisumu - Kisumu Bus Station",
    location: "Oginga Odinga Street, Kisumu",
    city: "Kisumu",
    active: true
  },
  %{
    name: "Eldoret - Eldoret Town",
    location: "Uganda Road, Eldoret",
    city: "Eldoret",
    active: true
  },
  %{
    name: "Nakuru - Nakuru Matatu Stage",
    location: "Kenyatta Avenue, Nakuru",
    city: "Nakuru",
    active: true
  },
  %{
    name: "Malindi - Malindi Town",
    location: "Lamu Road, Malindi",
    city: "Malindi",
    active: true
  },
  %{name: "Diani - Diani Beach Road", location: "Diani Beach Road", city: "Diani", active: true},
  %{
    name: "Kampala - Kampala Bus Park",
    location: "Banda Street, Kampala",
    city: "Kampala",
    active: true
  },
  %{
    name: "Arusha - Arusha Central",
    location: "Sokoine Drive, Arusha",
    city: "Arusha",
    active: true
  }
]

for point_attrs <- drop_pick_points_data do
  unless Repo.get_by(Xpressbus.DropPickPoints.DropPickPoint, name: point_attrs.name) do
    DropPickPoints.create_drop_pick_point(point_attrs)
  end
end

# 4. Seed Banners
banners_data = [
  %{image: "room_1.jpg", status: "Publish", color: "bg-purple-500"},
  %{image: "room_2.jpg", status: "Publish", color: "bg-orange-500"},
  %{image: "room_3.jpg", status: "Publish", color: "bg-green-600"}
]

for banner_attrs <- banners_data do
  Banners.create_banner(banner_attrs)
end

# 5. Seed Hotels
hotels_data = [
  %{
    name: "The Sands Resort",
    price_per_night: 12500,
    rating: 4.9,
    location: "Diani",
    description: "Boutique beachfront resort.",
    amenities: ["Wi-Fi", "Pool", "Spa"]
  },
  %{
    name: "Sarova Stanley",
    price_per_night: 18000,
    rating: 4.8,
    location: "Nairobi",
    description: "Historic luxury hotel.",
    amenities: ["Business Center", "Gym", "Restaurant"]
  },
  %{
    name: "Hemingways Watamu",
    price_per_night: 25000,
    rating: 5.0,
    location: "Watamu",
    description: "Iconic tropical paradise.",
    amenities: ["Ocean View", "Bar", "Room Service"]
  }
]

for hotel_attrs <- hotels_data do
  # Idempotent: hotels have a unique name, re-running seeds must not duplicate cards.
  unless Repo.get_by(Hotel, name: hotel_attrs.name) do
    %Hotel{} |> Hotel.changeset(hotel_attrs) |> Repo.insert!()
  end
end

# 6. Seed Hidden Gems
gems_data = [
  %{
    title: "Chale Island Retreat",
    location: "Kwale",
    description: "East Africa's only individual island resort."
  },
  %{
    title: "Hell's Gate Gorges",
    location: "Naivasha",
    description: "Dramatic cliffs and geothermal activity."
  },
  %{
    title: "Lamu Archipelago",
    location: "Lamu",
    description: "A serene step back in time on the Swahili coast."
  }
]

for gem_attrs <- gems_data do
  # Idempotent: hidden gems have a unique title.
  unless Repo.get_by(HiddenGem, title: gem_attrs.title) do
    %HiddenGem{} |> HiddenGem.changeset(gem_attrs) |> Repo.insert!()
  end
end

# 7. Seed Car Hire
cars_data = [
  %{
    car_name: "Toyota Landcruiser",
    type: "4x4 Safari",
    price_per_day: 15000,
    location: "Nairobi"
  },
  %{car_name: "Range Rover Sport", type: "Luxury SUV", price_per_day: 35000, location: "Mombasa"},
  %{car_name: "Toyota Rav4", type: "Compact 4x4", price_per_day: 8500, location: "Kisumu"}
]

for car_attrs <- cars_data do
  # Idempotent: a car is unique per (car_name, location) pair.
  unless Repo.get_by(CarHire,
           car_name: car_attrs.car_name,
           location: car_attrs.location
         ) do
    %CarHire{} |> CarHire.changeset(car_attrs) |> Repo.insert!()
  end
end

# 8. Seed Events
events_data = [
  %{
    title: "Safari Rally Kenya",
    date: ~D[2026-06-24],
    location: "Naivasha",
    description: "WRC world championship event."
  },
  %{
    title: "Blankets & Wine",
    date: ~D[2026-12-15],
    location: "Nairobi",
    description: "Music and lifestyle festival."
  }
]

for event_attrs <- events_data do
  # Idempotent: an event is unique per (title, date) pair.
  unless Repo.get_by(Event, title: event_attrs.title, date: event_attrs.date) do
    %Event{} |> Event.changeset(event_attrs) |> Repo.insert!()
  end
end

# 8a. Seed the InSURE insurance catalogue (plans + FAQs powering /tour-packages/insurance)
IO.puts("Seeding InSURE insurance plans and FAQs...")
Xpressbus.Insurance.ensure_defaults()

# 8b. Seed Routes (from the BuuPass-inspired city-pair seeder)
Xpressbus.Routes.Seeder.run()

# 8c. Backfill foreign-key relations between transport tables
IO.puts("Linking drop-pick-points → cities...")
points = Xpressbus.Repo.all(Xpressbus.DropPickPoints.DropPickPoint)

for point <- points do
  city = Repo.get_by(Xpressbus.Cities.City, name: point.city)

  if city && is_nil(point.city_id) do
    point
    |> Ecto.Changeset.change(%{city_id: city.id})
    |> Repo.update()
  end
end

IO.puts("Linking routes → cities...")
routes = Xpressbus.Repo.all(Xpressbus.Routes.Route)

for route <- routes do
  origin_city = Repo.get_by(Xpressbus.Cities.City, name: route.origin)
  dest_city = Repo.get_by(Xpressbus.Cities.City, name: route.destination)
  changes = %{}

  changes =
    if origin_city && is_nil(route.origin_city_id),
      do: Map.put(changes, :origin_city_id, origin_city.id),
      else: changes

  changes =
    if dest_city && is_nil(route.destination_city_id),
      do: Map.put(changes, :destination_city_id, dest_city.id),
      else: changes

  if map_size(changes) > 0 do
    route
    |> Ecto.Changeset.change(changes)
    |> Repo.update()
  end
end

IO.puts("Linking buses → bus_operators...")
buses = Xpressbus.Repo.all(Xpressbus.Bookings.Bus)

for bus <- buses do
  operator = Repo.get_by(Xpressbus.BusOperators.BusOperator, name: bus.company)

  if operator && is_nil(bus.bus_operator_id) do
    bus
    |> Ecto.Changeset.change(%{bus_operator_id: operator.id})
    |> Repo.update()
  end
end

IO.puts("Relations linked.")

# 9. Seed Facilities (pulled from BuuPass scraper, with curated fallback)
IO.puts("Pulling facilities from BuuPass...")
facilities = FacilitiesScraper.sync()
IO.puts("Facilities in DB: #{length(facilities)}")

# 10. Seed Mock Buses (if scraper fails)
IO.puts("Seeding mock buses...")
unless Repo.aggregate(Bus, :count, :id) > 0 do
  buses_data = [
    %{
      company: "MashPoa",
      departure: "08:00 PM",
      arrival: "06:00 AM",
      from: "Nairobi",
      to: "Mombasa",
      travel_date: ~D[2026-09-03],
      price: "KSH 1,500",
      seats: "12 seats left",
      registration: "KCH 442Y",
      total_seats: 40,
      occupied_seats: ["1", "2", "3"]
    },
    %{
      company: "Chania Executive",
      departure: "09:00 AM",
      arrival: "05:00 PM",
      from: "Mombasa",
      to: "Nairobi",
      travel_date: ~D[2026-09-04],
      price: "KSH 1,200",
      seats: "24 seats left",
      registration: "KAA 123B",
      total_seats: 40,
      occupied_seats: ["10", "11"]
    }
  ]

  for bus_attrs <- buses_data do
    %Bus{} |> Bus.changeset(bus_attrs) |> Repo.insert!()
  end
end

# 11. Pull a small subset of BuuPass data
IO.puts("Pulling sample bus data from BuuPass...")
Xpressbus.Bookings.Scraper.search("Nairobi", "Mombasa", "2026-09-03")
Xpressbus.Bookings.Scraper.search("Mombasa", "Nairobi", "2026-09-03")

# 11. Seed Bus Operators (from scraped buses + BuuPass scraper + curated fallback)
IO.puts("Pulling bus operators from BuuPass...")
operators = BusOperatorsScraper.sync()
IO.puts("Bus operators in DB: #{length(operators)}")

# 12. Seed Recent Bookings (Tickets)
IO.puts("Seeding mock tickets...")
Xpressbus.Repo.delete_all(Xpressbus.Tickets.Ticket)
tickets_data = [
  %{
    ticket_id: "TKT-A1B2C3",
    from: "Nairobi",
    to: "Mombasa",
    travel_date: ~D[2026-09-03],
    departure: "08:00 PM",
    arrival: "06:00 AM",
    company: "MashPoa",
    price: "KSH 1,500",
    seats: ["4", "5"],
    passenger_name: "John Doe, Jane Doe",
    passenger_phone: "0722000000",
    payment_method: "mpesa",
    status: "confirmed"
  },
  %{
    ticket_id: "TKT-D4E5F6",
    from: "Mombasa",
    to: "Nairobi",
    travel_date: ~D[2026-09-04],
    departure: "09:00 AM",
    arrival: "05:00 PM",
    company: "Chania Executive",
    price: "KSH 1,200",
    seats: ["12"],
    passenger_name: "Alice Smith",
    passenger_phone: "0733111222",
    payment_method: "card",
    status: "completed"
  },
  %{
    ticket_id: "TKT-G7H8I9",
    from: "Kisumu",
    to: "Nairobi",
    travel_date: ~D[2026-09-05],
    departure: "10:00 PM",
    arrival: "06:00 AM",
    company: "Easy Coach",
    price: "KSH 1,800",
    seats: ["1"],
    passenger_name: "Bob Johnson",
    passenger_phone: "0711555666",
    payment_method: "mpesa",
    status: "cancelled"
  }
]

for ticket_attrs <- tickets_data do
  case Xpressbus.Tickets.create_ticket(ticket_attrs) do
    {:ok, _} -> :ok
    {:error, changeset} -> IO.inspect(changeset.errors, label: "❌ Failed to seed ticket #{ticket_attrs.ticket_id}")
  end
end

IO.puts("Seeding completed successfully! 🚀")
