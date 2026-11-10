defmodule XpressbusWeb.AdminIntegrationAITest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.AI
  alias Xpressbus.Integrations

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  defp open_ai_tab(conn) do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/integration")
    view |> element("button", "Chyllz AI") |> render_click()
    {view, nil}
  end

  defp save_ai(view, config) do
    view
    |> form("#ai-integration-form", %{"provider" => "ai", "config" => config})
    |> render_submit()
  end

  test "the Chyllz AI tab saves an OpenAI-compatible provider", %{conn: conn} do
    {view, _} = open_ai_tab(conn)

    assert has_element?(view, "#ai-integration-form")

    assert has_element?(
             view,
             "#ai-integration-form input[name='config[api_key]'][type='password']"
           )

    assert has_element?(view, "#ai-integration-form input[name='config[base_url]']")
    assert has_element?(view, "#ai-integration-form input[name='config[model]']")
    assert has_element?(view, "#ai-integration-form input[name='config[vision_model]']")

    save_ai(view, %{
      "api_key" => "sk-live-secret-123",
      "base_url" => "https://api.test/v1",
      "model" => "test-chat-model",
      "vision_model" => "test-vision-model",
      "timeout" => "15000"
    })

    assert render(view) =~ "Chyllz AI settings saved"
    assert render(view) =~ "Connected via admin"

    saved = Integrations.get_config_by_provider("ai")
    assert saved.active
    assert saved.config["api_key"] == "sk-live-secret-123"
    assert saved.config["base_url"] == "https://api.test/v1"
    assert saved.config["model"] == "test-chat-model"
    assert saved.config["vision_model"] == "test-vision-model"
    assert saved.config["timeout"] == "15000"

    assert AI.config().api_key == "sk-live-secret-123"
    assert AI.config().model == "test-chat-model"
    assert AI.configured?()

    # The secret is never rendered back to the admin browser.
    refute render(view) =~ "sk-live-secret-123"
  end

  test "saving models without a new key preserves the saved key", %{conn: conn} do
    {view, _} = open_ai_tab(conn)

    save_ai(view, %{"api_key" => "sk-keep-me", "model" => "first-model"})
    assert Integrations.get_config_by_provider("ai").config["api_key"] == "sk-keep-me"

    save_ai(view, %{"api_key" => "", "model" => "second-model"})

    saved = Integrations.get_config_by_provider("ai")
    assert saved.config["api_key"] == "sk-keep-me"
    assert saved.config["model"] == "second-model"
    assert render(view) =~ "Connected via admin"
  end

  test "removing the saved key returns Chyllz to the local guide", %{conn: conn} do
    {view, _} = open_ai_tab(conn)

    save_ai(view, %{"api_key" => "sk-remove-me"})
    assert AI.configured?()

    view |> element("button", "Remove saved key") |> render_click()

    saved = Integrations.get_config_by_provider("ai")
    assert saved.config["api_key"] == ""
    refute AI.configured?()
    assert render(view) =~ "Enabled — add an API key"
  end

  test "disabling the integration forces local mode", %{conn: conn} do
    {view, _} = open_ai_tab(conn)

    save_ai(view, %{"api_key" => "sk-disable-me"})
    assert AI.configured?()

    view
    |> element("#ai-integration-form input[phx-value-provider='ai']")
    |> render_click()

    assert Integrations.get_config_by_provider("ai").active == false
    refute AI.configured?()
    assert render(view) =~ "Disabled by admin"
  end

  test "invalid settings are rejected before persisting", %{conn: conn} do
    {view, _} = open_ai_tab(conn)

    save_ai(view, %{"api_key" => "sk-invalid-url", "base_url" => "not-a-url"})

    assert render(view) =~ "Base URL must start with http:// or https://"
    assert Integrations.get_config_by_provider("ai") == nil
  end

  test "test connection explains when no key is configured", %{conn: conn} do
    {view, _} = open_ai_tab(conn)

    view |> element("button", "Test Connection") |> render_click()

    assert render(view) =~ "No AI key is configured"
  end

  test "test connection calls the configured provider", %{conn: conn} do
    previous = Application.get_env(:xpressbus, :ai)

    on_exit(fn ->
      if previous == nil do
        Application.delete_env(:xpressbus, :ai)
      else
        Application.put_env(:xpressbus, :ai, previous)
      end
    end)

    Application.put_env(
      :xpressbus,
      :ai,
      Map.merge(previous || %{}, %{req_options: [plug: {Req.Test, __MODULE__}]})
    )

    {:ok, _} =
      Integrations.upsert_config_by_provider("ai", %{
        active: true,
        config: %{
          "api_key" => "sk-test-key",
          "base_url" => "https://api.test/v1",
          "model" => "test-model"
        }
      })

    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, {:ai_test_request, conn.request_path})
      Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => "OK"}}]})
    end)

    {view, _} = open_ai_tab(conn)
    view |> element("button", "Test Connection") |> render_click()

    assert_receive {:ai_test_request, "/v1/chat/completions"}
    assert render(view) =~ "Chyllz AI is reachable"
  end
end
