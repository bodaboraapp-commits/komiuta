defmodule Xpressbus.IntegrationsTest do
  use Xpressbus.DataCase

  alias Xpressbus.Integrations

  describe "integrations" do
    alias Xpressbus.Integrations.PaymentConfig

    import Xpressbus.IntegrationsFixtures

    @invalid_attrs %{active: nil, config: nil, provider: nil}

    test "list_integrations/0 returns all integrations" do
      payment_config = payment_config_fixture()
      assert Integrations.list_integrations() == [payment_config]
    end

    test "get_payment_config!/1 returns the payment_config with given id" do
      payment_config = payment_config_fixture()
      assert Integrations.get_payment_config!(payment_config.id) == payment_config
    end

    test "create_payment_config/1 with valid data creates a payment_config" do
      valid_attrs = %{active: true, config: %{}, provider: "some provider"}

      assert {:ok, %PaymentConfig{} = payment_config} =
               Integrations.create_payment_config(valid_attrs)

      assert payment_config.active == true
      assert payment_config.config == %{}
      assert payment_config.provider == "some provider"
    end

    test "create_payment_config/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Integrations.create_payment_config(@invalid_attrs)
    end

    test "update_payment_config/2 with valid data updates the payment_config" do
      payment_config = payment_config_fixture()
      update_attrs = %{active: false, config: %{}, provider: "some updated provider"}

      assert {:ok, %PaymentConfig{} = payment_config} =
               Integrations.update_payment_config(payment_config, update_attrs)

      assert payment_config.active == false
      assert payment_config.config == %{}
      assert payment_config.provider == "some updated provider"
    end

    test "update_payment_config/2 with invalid data returns error changeset" do
      payment_config = payment_config_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Integrations.update_payment_config(payment_config, @invalid_attrs)

      assert payment_config == Integrations.get_payment_config!(payment_config.id)
    end

    test "delete_payment_config/1 deletes the payment_config" do
      payment_config = payment_config_fixture()
      assert {:ok, %PaymentConfig{}} = Integrations.delete_payment_config(payment_config)

      assert_raise Ecto.NoResultsError, fn ->
        Integrations.get_payment_config!(payment_config.id)
      end
    end

    test "change_payment_config/1 returns a payment_config changeset" do
      payment_config = payment_config_fixture()
      assert %Ecto.Changeset{} = Integrations.change_payment_config(payment_config)
    end
  end

  describe "user login method" do
    test "defaults to email when nothing is configured" do
      assert Integrations.login_method() == "email"
    end

    test "returns the saved email, sms or both method" do
      for method <- ["email", "sms", "both"] do
        {:ok, _} =
          Integrations.upsert_config_by_provider("user_login", %{
            active: true,
            config: %{"method" => method}
          })

        assert Integrations.login_method() == method
      end
    end

    test "falls back to email for an unknown method" do
      {:ok, _} =
        Integrations.upsert_config_by_provider("user_login", %{
          active: true,
          config: %{"method" => "magic-link"}
        })

      assert Integrations.login_method() == "email"
    end
  end

  describe "Chyllz AI integration" do
    test "returns nil when nothing is configured" do
      assert Integrations.ai_integration() == nil
    end

    test "normalises an active provider and its defaults" do
      {:ok, _} =
        Integrations.upsert_config_by_provider("ai", %{
          active: true,
          config: %{
            "api_key" => "  sk-db-key  ",
            "base_url" => " https://api.test/v1 ",
            "timeout" => "12000"
          }
        })

      integration = Integrations.ai_integration()

      assert integration.source == :integration
      assert integration.active
      assert integration.api_key == "sk-db-key"
      assert integration.base_url == "https://api.test/v1"
      assert integration.model == "gpt-4o-mini"
      assert integration.vision_model == "gpt-4o-mini"
      assert integration.timeout == 12_000
    end

    test "reports a missing key without exposing a secret" do
      {:ok, _} =
        Integrations.upsert_config_by_provider("ai", %{active: true, config: %{}})

      integration = Integrations.ai_integration()

      assert integration.source == :missing_key
      refute Map.has_key?(integration, :api_key)
    end

    test "reports a disabled integration" do
      {:ok, _} =
        Integrations.upsert_config_by_provider("ai", %{
          active: false,
          config: %{"api_key" => "sk-db-key"}
        })

      assert Integrations.ai_integration() == %{source: :disabled, active: false}
    end
  end
end
