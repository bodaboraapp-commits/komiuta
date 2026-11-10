defmodule XpressbusWeb.TravellerSignupFlowTest do
  use XpressbusWeb.ConnCase

  test "signup starts on the verification step", %{conn: conn} do
    html = conn |> get(~p"/user/signup") |> html_response(200)

    assert html =~ "Step 1 of 2"
    assert html =~ "Verify your account"
    assert html =~ "Sign up with Gmail"
    assert html =~ "Verify Phone with SMS"
    assert html =~ "Sign up with email instead"
    refute html =~ "Full Name"
  end

  test "email fallback opens the account details step", %{conn: conn} do
    html = conn |> get(~p"/user/signup?method=email") |> html_response(200)

    assert html =~ "Step 2 of 2"
    assert html =~ "Complete your account"
    assert html =~ "Full Name"
    refute html =~ "Sign up with Gmail"
    refute html =~ "firebase-sms-auth"
  end

  test "a verified SMS phone is carried into the details step", %{conn: conn} do
    conn =
      Plug.Test.init_test_session(conn, %{verified_signup_phone: "254756112633"})

    html = conn |> get(~p"/user/signup") |> html_response(200)

    assert html =~ "Step 2 of 2"
    assert html =~ "254756112633"
    assert html =~ "is verified"
    assert html =~ "readonly"
  end
end
