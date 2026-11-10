defmodule Xpressbus.AITest do
  use Xpressbus.DataCase, async: false

  import Plug.Conn

  alias Xpressbus.AI
  alias Xpressbus.Integrations

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

  describe "configured?/1" do
    test "is false without an API key" do
      assert AI.configured?(%{api_key: nil, enabled: true}) == false
      assert AI.configured?(%{api_key: "", enabled: true}) == false
      assert AI.configured?(%{api_key: "test", enabled: false}) == false
    end

    test "is true with an enabled key and base URL" do
      assert AI.configured?(%{api_key: "test", enabled: true, base_url: "https://api.test/v1"})
    end
  end

  describe "admin integration configuration" do
    test "an active integration overrides the environment key and models" do
      configure(api_key: "env-key", model: "env-model", base_url: "https://env.test/v1")

      {:ok, _} =
        Integrations.upsert_config_by_provider("ai", %{
          active: true,
          config: %{
            "api_key" => "db-key",
            "base_url" => "https://db.test/v1",
            "model" => "db-model",
            "vision_model" => "db-vision-model",
            "timeout" => "12000"
          }
        })

      config = AI.config()

      assert config.api_key == "db-key"
      assert config.base_url == "https://db.test/v1"
      assert config.model == "db-model"
      assert config.vision_model == "db-vision-model"
      assert config.timeout == 12_000
      assert config.enabled == true
      assert AI.configured?()
    end

    test "a disabled integration forces local mode even with an environment key" do
      configure(api_key: "env-key")

      {:ok, _} =
        Integrations.upsert_config_by_provider("ai", %{active: false, config: %{}})

      assert AI.config().enabled == false
      refute AI.configured?()
      assert AI.provider_status().source == :disabled
    end

    test "an active integration without a key falls back to the environment" do
      configure(api_key: "env-key", model: "env-model")

      {:ok, _} =
        Integrations.upsert_config_by_provider("ai", %{active: true, config: %{}})

      config = AI.config()
      assert config.api_key == "env-key"
      assert config.model == "env-model"
      assert AI.configured?()
      assert AI.provider_status().source == :environment
    end

    test "provider_status reports the source without exposing the key" do
      assert AI.provider_status().source == :none
      refute AI.configured?()

      configure(api_key: "env-key")
      status = AI.provider_status()
      assert status.source == :environment
      assert status.has_env_key == true
      refute Map.has_key?(status, :api_key)

      {:ok, _} =
        Integrations.upsert_config_by_provider("ai", %{
          active: true,
          config: %{"api_key" => "db-key", "model" => "db-model"}
        })

      status = AI.provider_status()
      assert status.source == :integration
      assert status.has_integration_key == true
      assert status.model == "db-model"
      refute Map.has_key?(status, :api_key)
    end

    test "requests use the saved integration key and model" do
      configure(req_options: [plug: {Req.Test, __MODULE__}])

      {:ok, _} =
        Integrations.upsert_config_by_provider("ai", %{
          active: true,
          config: %{
            "api_key" => "db-key",
            "base_url" => "https://db.test/v1",
            "model" => "db-model"
          }
        })

      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = read_body(conn)
        send(self(), {:integration_request, conn, Jason.decode!(body)})
        Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => "OK"}}]})
      end)

      assert {:ok, "OK"} = AI.chat([%{"role" => "user", "content" => "hi"}])

      assert_receive {:integration_request, conn, body}
      assert conn.request_path == "/v1/chat/completions"
      assert conn.host == "db.test"
      assert get_req_header(conn, "authorization") == ["Bearer db-key"]
      assert body["model"] == "db-model"
    end
  end

  describe "chat/2" do
    test "returns not_configured without contacting the network" do
      assert {:error, :not_configured} = AI.chat([%{"role" => "user", "content" => "hi"}])
    end

    test "posts an OpenAI-compatible request and reads the reply" do
      configure(
        api_key: "test-key",
        model: "test-model",
        req_options: [plug: {Req.Test, __MODULE__}]
      )

      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = read_body(conn)
        send(self(), {:ai_request, conn, Jason.decode!(body)})

        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"content" => "Karibu! Try Diani."}}]
        })
      end)

      assert {:ok, "Karibu! Try Diani."} =
               AI.chat([%{"role" => "user", "content" => "Where should I go?"}])

      assert_receive {:ai_request, conn, body}
      assert conn.request_path == "/v1/chat/completions"
      assert get_req_header(conn, "authorization") == ["Bearer test-key"]
      assert body["model"] == "test-model"
      assert [%{"role" => "user", "content" => "Where should I go?"}] = body["messages"]
    end

    test "supports multimodal image content parts" do
      configure(
        api_key: "test-key",
        model: "vision-test",
        req_options: [plug: {Req.Test, __MODULE__}]
      )

      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = read_body(conn)
        send(self(), {:ai_request, Jason.decode!(body)})
        Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => "A beach."}}]})
      end)

      data_url = "data:image/png;base64," <> Base.encode64(<<137, 80, 78, 71>>)
      messages = [AI.image_message("What is this?", data_url)]

      assert {:ok, "A beach."} = AI.chat(messages)

      assert_receive {:ai_request, body}
      assert [%{"content" => parts}] = body["messages"]
      assert Enum.any?(parts, &(&1["type"] == "image_url"))
      assert body["model"] == "vision-test"
    end

    test "returns an error tuple on provider failure" do
      configure(
        api_key: "test-key",
        req_options: [plug: {Req.Test, __MODULE__}]
      )

      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> put_status(500)
        |> Req.Test.json(%{"error" => "upstream unavailable"})
      end)

      assert {:error, {:http_status, 500, _body}} =
               AI.chat([%{"role" => "user", "content" => "hi"}])
    end

    test "ignores empty provider content" do
      configure(
        api_key: "test-key",
        req_options: [plug: {Req.Test, __MODULE__}]
      )

      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => "  "}}]})
      end)

      assert {:error, :empty_response} = AI.chat([%{"role" => "user", "content" => "hi"}])
    end
  end

  defp configure(overrides) do
    config =
      Application.get_env(:xpressbus, :ai, %{})
      |> Map.merge(%{enabled: true, base_url: "https://api.test/v1"})
      |> Map.merge(Map.new(overrides))

    Application.put_env(:xpressbus, :ai, config)
  end
end
