defmodule Xpressbus.TravelAssistantTest do
  use Xpressbus.DataCase, async: false

  import Xpressbus.CatalogueFixtures
  import Plug.Conn

  alias Xpressbus.TravelAssistant

  setup do
    previous = Application.get_env(:xpressbus, :ai)

    on_exit(fn ->
      if previous == nil do
        Application.delete_env(:xpressbus, :ai)
      else
        Application.put_env(:xpressbus, :ai, previous)
      end
    end)

    :ok
  end

  describe "context/0" do
    test "returns only active catalogue entries with counts" do
      active = hotel_fixture(%{name: "Active Context Hotel"})
      hotel_fixture(%{name: "Inactive Context Hotel", active: false})

      context = TravelAssistant.context()

      assert Enum.any?(context.hotels, &(&1.id == active.id))
      refute Enum.any?(context.hotels, &(&1.name == "Inactive Context Hotel"))
      assert context.counts.hotels >= 1
      assert %DateTime{} = context.generated_at
    end
  end

  describe "respond/5 in local mode" do
    test "finds stays under a budget in a town" do
      budget =
        hotel_fixture(%{
          name: "Budget Nairobi Stay",
          location: "Nairobi",
          price_per_night: "6500",
          rating: "4.4"
        })

      hotel_fixture(%{
        name: "Luxury Nairobi Stay",
        location: "Nairobi",
        price_per_night: "25000",
        rating: "4.9"
      })

      reply =
        TravelAssistant.respond(
          "chat",
          "Best hotels under KES 8,000 in Nairobi",
          [],
          TravelAssistant.context(),
          use_ai: false
        )

      assert reply.source == :local
      assert reply.text =~ "Budget Nairobi Stay"
      refute reply.text =~ "Luxury Nairobi Stay"
      assert Enum.any?(reply.cards, &(&1.title == budget.name))
      assert Enum.any?(reply.cards, &(&1.href == "/tour-packages/hotels?q=Budget+Nairobi+Stay"))
    end

    test "answers a greeting without a destination" do
      reply =
        TravelAssistant.respond("chat", "hello", [], TravelAssistant.context(), use_ai: false)

      assert reply.source == :local
      assert reply.text =~ "Chyllz"
      assert reply.cards == []
    end

    test "builds a three-day itinerary from real catalogue rows" do
      hotel =
        hotel_fixture(%{
          name: "Diani Plan Stay",
          location: "Diani",
          price_per_night: "9000",
          rating: "4.7"
        })

      gem = hidden_gem_fixture(%{title: "Diani Plan Gem", location: "Diani"})
      event = event_fixture(%{title: "Diani Plan Festival", location: "Diani"})
      car = car_hire_fixture(%{car_name: "Diani Plan Car", location: "Diani"})

      reply =
        TravelAssistant.respond(
          "chat",
          "Plan a 3-day trip to Diani",
          [],
          TravelAssistant.context(),
          use_ai: false
        )

      assert reply.text =~ hotel.name
      assert reply.text =~ gem.title
      assert reply.text =~ event.title
      assert reply.text =~ car.car_name
      assert reply.action.href == "/?to=Diani"
    end

    test "recommends local dishes and respects a vegetarian preference" do
      reply =
        TravelAssistant.respond(
          "food",
          "vegetarian food in Mombasa",
          [],
          TravelAssistant.context(),
          use_ai: false
        )

      assert reply.text =~ "Mombasa"
      assert reply.text =~ "Mahamri" or reply.text =~ "Viazi"
      refute reply.text =~ "Nyama choma"
      assert reply.action.href == "/our-packages/hidden-gems"
    end

    test "lists upcoming events and hides past ones" do
      upcoming = event_fixture(%{title: "Assistant Upcoming Event", location: "Naivasha"})
      past = event_fixture(%{title: "Assistant Past Event", date: Date.add(Date.utc_today(), -5)})

      reply =
        TravelAssistant.respond(
          "chat",
          "what's on in Naivasha?",
          [],
          TravelAssistant.context(),
          use_ai: false
        )

      assert reply.text =~ upcoming.title
      refute reply.text =~ past.title
    end

    test "answers receipt questions and points to the Receipt tab" do
      reply =
        TravelAssistant.respond(
          "chat",
          "how do I track a receipt?",
          [],
          TravelAssistant.context(),
          use_ai: false
        )

      assert reply.text =~ "Receipt"
      assert reply.action.tab == "receipt"
    end

    test "falls back to a helpful capability message" do
      reply =
        TravelAssistant.respond(
          "chat",
          "do you know any good bookshops?",
          [],
          TravelAssistant.context(),
          use_ai: false
        )

      assert reply.text =~ "Stays"
      assert is_list(reply.cards)
    end

    test "photo fallback matches a caption to catalogue picks" do
      gem =
        hidden_gem_fixture(%{
          title: "Sunset Dhow Sail",
          location: "Lamu",
          description: "A quiet beach sunset boat trip"
        })

      reply =
        TravelAssistant.photo_reply(
          "lens",
          nil,
          "beach sunset dhow",
          TravelAssistant.context(),
          use_ai: false
        )

      assert reply.source == :local
      assert reply.text =~ gem.title or reply.text =~ "catalogue"
    end
  end

  describe "respond/5 with a configured AI provider" do
    test "returns the model reply and tags it as AI" do
      configure_ai()

      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = read_body(conn)
        send(self(), {:assistant_request, Jason.decode!(body)})

        Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => "AI plan for Diani."}}]})
      end)

      reply =
        TravelAssistant.respond(
          "chat",
          "Plan a weekend in Diani",
          [],
          TravelAssistant.context()
        )

      assert reply.source == :ai
      assert reply.text == "AI plan for Diani."
      assert_receive {:assistant_request, body}
      assert [%{"role" => "system"} | _rest] = body["messages"]

      assert Enum.any?(
               body["messages"],
               &(&1["role"] == "user" and &1["content"] == "Plan a weekend in Diani")
             )
    end

    test "falls back to the local guide when the provider fails" do
      configure_ai()

      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> put_status(502)
        |> Req.Test.json(%{"error" => "bad gateway"})
      end)

      reply =
        TravelAssistant.respond(
          "chat",
          "Best hotels in Nairobi",
          [],
          TravelAssistant.context()
        )

      assert reply.source == :local
      assert reply.degraded == true
      assert reply.text != ""
    end

    test "parses a receipt photo through the vision model" do
      configure_ai()

      json =
        Jason.encode!(%{
          "merchant" => "KOMIUTA CAFE",
          "date" => "12/11/2026",
          "currency" => "KES",
          "total" => 970,
          "items" => [
            %{"label" => "Chapati", "amount" => 120, "category" => "Food"},
            %{"label" => "Tilapia", "amount" => 850, "category" => "Food"}
          ]
        })

      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => json}}]})
      end)

      reply =
        TravelAssistant.photo_reply(
          "receipt",
          image_data_url(),
          "",
          TravelAssistant.context()
        )

      assert reply.source == :ai
      assert reply.receipt.merchant == "KOMIUTA CAFE"
      assert Decimal.equal?(reply.receipt.total, Decimal.new(970))
      assert reply.text =~ "KES 970"
    end

    test "explains an unreadable receipt photo" do
      configure_ai()

      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"content" => ~s({"error":"not_a_receipt"})}}]
        })
      end)

      reply =
        TravelAssistant.photo_reply(
          "receipt",
          image_data_url(),
          "",
          TravelAssistant.context()
        )

      assert reply.source == :local
      assert reply.text =~ "paste the lines"
    end

    test "answers a Lens photo with the vision model" do
      configure_ai()

      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"content" => "This looks like Diani beach."}}]
        })
      end)

      reply =
        TravelAssistant.photo_reply(
          "lens",
          image_data_url(),
          "beach",
          TravelAssistant.context()
        )

      assert reply.source == :ai
      assert reply.text == "This looks like Diani beach."
    end
  end

  describe "receipt helpers" do
    test "parses pasted receipt text and totals expenses" do
      result = TravelAssistant.parse_receipt_text("Chapati 120\nTilapia 850\nTotal 970")

      assert result.ok
      assert result.text =~ "Total: KES 970"

      entry = TravelAssistant.expense_entry(result.receipt)
      assert TravelAssistant.expense_total_label([entry]) == "KES 970"
    end

    test "explains how to format a receipt it cannot read" do
      result = TravelAssistant.parse_receipt_text("no amounts here")

      refute result.ok
      assert result.text =~ "receipt lines"
    end
  end

  describe "copy helpers" do
    test "greetings and suggestions exist for every tab" do
      for tab <- ~w(chat lens receipt food) do
        assert %{text: text, cards: []} = TravelAssistant.greeting(tab)
        assert text != ""
        assert TravelAssistant.suggestions(tab) != []
      end
    end

    test "engine label reflects the configured provider" do
      assert TravelAssistant.engine_label() == "Chyllz Guide"

      configure_ai()
      assert TravelAssistant.engine_label() == "Chyllz AI"
    end
  end

  defp image_data_url do
    bytes = <<137, 80, 78, 71, 13, 10, 26, 10>> <> :binary.copy(<<0>>, 64)
    "data:image/png;base64," <> Base.encode64(bytes)
  end

  defp configure_ai do
    Application.put_env(
      :xpressbus,
      :ai,
      Application.get_env(:xpressbus, :ai, %{})
      |> Map.merge(%{
        enabled: true,
        api_key: "test-key",
        base_url: "https://api.test/v1",
        model: "test-model",
        req_options: [plug: {Req.Test, __MODULE__}]
      })
    )
  end
end
