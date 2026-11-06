defmodule Xpressbus.SMSTest do
  use ExUnit.Case, async: false

  alias Xpressbus.SMS

  test "normalises Kenyan phone numbers to E.164" do
    assert SMS.to_e164("0765112633") == "+254765112633"
    assert SMS.to_e164("+254765112633") == "+254765112633"
    assert SMS.to_e164("765112633") == "+254765112633"
    assert SMS.to_e164("") == nil
    assert SMS.to_e164(nil) == nil
  end

  test "uses an injected sender in tests" do
    Application.put_env(:xpressbus, :sms_send_fun, fn to, message ->
      send(self(), {:sms, to, message})
      {:ok, %{provider: :test}}
    end)

    on_exit(fn -> Application.delete_env(:xpressbus, :sms_send_fun) end)

    assert {:ok, %{provider: :test}} = SMS.send("0765112633", "Hello")

    assert_receive {:sms, "+254765112633", "Hello"}
  end

  test "returns an error for an invalid phone number" do
    assert {:error, :invalid_phone} = SMS.send("", "Hello")
  end
end
