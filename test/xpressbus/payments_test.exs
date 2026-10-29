defmodule Xpressbus.PaymentsTest do
  use Xpressbus.DataCase

  alias Xpressbus.{Integrations, Payments}
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Repo

  defp configure(provider, config) do
    {:ok, _} =
      Integrations.upsert_config_by_provider(provider, %{
        active: true,
        config: config
      })

    :ok
  end

  defp payment_fixture(attrs) do
    base = %{
      provider: "mpesa",
      amount: 1500,
      currency: "KES",
      status: "pending",
      reference: "REF-#{System.unique_integer([:positive])}",
      phone_number: "0700000000",
      raw_response: %{}
    }

    Repo.insert!(struct(Payment, Map.merge(base, attrs)))
  end

  describe "verify_paystack_signature/2" do
    test "accepts a valid HMAC-SHA512 signature" do
      configure("paystack", %{"secret_key" => "sk_test_secret"})
      body = ~s({"event":"charge.success","data":{"reference":"TKT-1"}})

      signature =
        :crypto.mac(:hmac, :sha512, "sk_test_secret", body) |> Base.encode16(case: :lower)

      assert :ok = Payments.verify_paystack_signature(body, signature)
    end

    test "rejects a forged signature" do
      configure("paystack", %{"secret_key" => "sk_test_secret"})
      body = ~s({"event":"charge.success"})

      assert {:error, :invalid_signature} =
               Payments.verify_paystack_signature(body, "deadbeef")
    end

    test "rejects a missing signature" do
      configure("paystack", %{"secret_key" => "sk_test_secret"})

      assert {:error, :missing_signature} =
               Payments.verify_paystack_signature("{}", nil)
    end

    test "fails closed when the provider is not configured" do
      assert {:error, :not_configured} =
               Payments.verify_paystack_signature("{}", "anything")
    end
  end

  describe "verify_flutterwave_signature/1" do
    test "accepts the configured webhook hash" do
      configure("flutterwave", %{"webhook_hash" => "hash123"})

      assert :ok = Payments.verify_flutterwave_signature("hash123")
    end

    test "rejects anything else" do
      configure("flutterwave", %{"webhook_hash" => "hash123"})

      assert {:error, :invalid_signature} =
               Payments.verify_flutterwave_signature("not-the-hash")
    end

    test "fails closed when no webhook hash is configured" do
      assert {:error, :not_configured} = Payments.verify_flutterwave_signature("hash123")
    end
  end

  describe "validate_mpesa_callback/3" do
    test "accepts a successful callback whose amount matches the request" do
      payment =
        payment_fixture(%{reference: "CHECKOUT-1", amount: 1500, status: "pending"})

      assert {:ok, accepted} =
               Payments.validate_mpesa_callback("CHECKOUT-1", "success", %{"Amount" => 1500})

      assert accepted.id == payment.id
    end

    test "accepts a string amount from the provider payload" do
      payment_fixture(%{reference: "CHECKOUT-2", amount: 1500, status: "pending"})

      assert {:ok, _} =
               Payments.validate_mpesa_callback("CHECKOUT-2", "success", %{"Amount" => "1500"})
    end

    test "rejects a successful callback with a mismatched amount" do
      payment_fixture(%{reference: "CHECKOUT-3", amount: 1500, status: "pending"})

      assert {:error, {:amount_mismatch, 1500, 100}} =
               Payments.validate_mpesa_callback("CHECKOUT-3", "success", %{"Amount" => 100})
    end

    test "rejects callbacks for unknown checkouts" do
      assert {:error, :not_found} =
               Payments.validate_mpesa_callback("DOES-NOT-EXIST", "success", %{"Amount" => 1500})
    end

    test "treats callbacks for already-successful payments as duplicates" do
      payment_fixture(%{reference: "CHECKOUT-4", amount: 1500, status: "success"})

      assert {:ok, %Payment{status: "success"}} =
               Payments.validate_mpesa_callback("CHECKOUT-4", "success", %{"Amount" => 999})
    end
  end

  describe "update_payment_status/3" do
    test "never downgrades a successful payment" do
      payment =
        payment_fixture(%{reference: "TKT-PAID", amount: 1500, status: "success"})

      assert {:ok, updated} = Payments.update_payment_status("TKT-PAID", "failed")
      assert updated.status == "success"
      assert updated.id == payment.id
    end

    test "updates pending payments" do
      payment_fixture(%{reference: "TKT-PENDING", amount: 1500, status: "pending"})

      assert {:ok, updated} = Payments.update_payment_status("TKT-PENDING", "failed")
      assert updated.status == "failed"
    end

    test "returns not_found for unknown references" do
      assert {:error, :not_found} = Payments.update_payment_status("NOPE", "failed")
    end
  end
end
