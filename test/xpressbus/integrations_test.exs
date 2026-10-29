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
end
