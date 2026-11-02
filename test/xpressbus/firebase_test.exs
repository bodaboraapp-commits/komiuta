defmodule Xpressbus.FirebaseTest do
  use Xpressbus.DataCase

  alias Xpressbus.{Accounts, Firebase}

  defp user_fixture do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        "name" => "SMS Tester",
        "phone" => "07" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0")),
        "email" => "sms#{unique}@example.com"
      })

    user
  end

  describe "normalize_phone/1" do
    test "normalises E.164 Kenyan numbers to local format" do
      assert Firebase.normalize_phone("+254712345678") == "0712345678"
      assert Firebase.normalize_phone("254712345678") == "0712345678"
      assert Firebase.normalize_phone("0712 345 678") == "0712345678"
      assert Firebase.normalize_phone("712345678") == "0712345678"
    end

    test "returns nil for blank input" do
      assert Firebase.normalize_phone("") == nil
      assert Firebase.normalize_phone(nil) == nil
    end
  end

  describe "phone_candidates/1" do
    test "includes local, digits-only and E.164 representations" do
      candidates = Firebase.phone_candidates("+254712345678")

      assert "0712345678" in candidates
      assert "254712345678" in candidates
      assert "+254712345678" in candidates
    end
  end

  describe "client_config/0" do
    test "exposes the public web config" do
      config = Firebase.client_config()

      assert config.api_key =~ "AIza"
      assert config.auth_domain == "komiuta.firebaseapp.com"
      assert config.project_id == "komiuta"
      assert config.app_id =~ "99186909972"
      refute Map.has_key?(config, :private_key)
    end
  end

  describe "verify_id_token/1" do
    test "returns the verified phone number from the Firebase lookup" do
      Application.put_env(:xpressbus, :firebase_lookup_fun, fn token ->
        assert token == "valid-token"
        {:ok, "+254712345678"}
      end)

      on_exit(fn -> Application.delete_env(:xpressbus, :firebase_lookup_fun) end)

      assert {:ok, "+254712345678"} = Firebase.verify_id_token("valid-token")
    end

    test "passes Firebase lookup failures through" do
      Application.put_env(:xpressbus, :firebase_lookup_fun, fn _token ->
        {:error, :invalid_token}
      end)

      on_exit(fn -> Application.delete_env(:xpressbus, :firebase_lookup_fun) end)

      assert {:error, :invalid_token} = Firebase.verify_id_token("bad-token")
    end

    test "rejects empty tokens without calling Firebase" do
      assert {:error, :invalid_token} = Firebase.verify_id_token("")
      assert {:error, :invalid_token} = Firebase.verify_id_token(nil)
    end
  end

  describe "find_user_by_phone/1" do
    test "finds an existing account from an E.164 phone number" do
      user = user_fixture()
      e164 = "+254" <> String.trim_leading(user.phone, "0")

      assert %{id: id} = Firebase.find_user_by_phone(e164)
      assert id == user.id
    end

    test "returns nil for an unknown phone number" do
      assert Firebase.find_user_by_phone("+254700000000") == nil
    end
  end

  describe "admin integration" do
    test "lists Firebase Phone Authentication" do
      root = Path.expand("../..", __DIR__)

      live = File.read!(Path.join(root, "lib/xpressbus_web/live/admin_integration_live.ex"))

      template =
        File.read!(Path.join(root, "lib/xpressbus_web/live/admin_integration_live.html.heex"))

      assert live =~ ~s("firebase" =>)
      assert live =~ "Firebase Phone Authentication"
      assert template =~ "Firebase Phone Authentication"
      assert template =~ "Open Firebase Console"
    end
  end
end
