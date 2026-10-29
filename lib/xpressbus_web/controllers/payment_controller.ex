defmodule XpressbusWeb.PaymentController do
  @moduledoc """
  Handles payment callbacks from providers.
  """

  use XpressbusWeb, :controller
  require Logger

  alias Xpressbus.Payments

  @doc """
  MPESA callback endpoint.
  """
  def mpesa_callback(conn, params) do
    # INDUSTRIAL LOGGING: Capture the raw payload for audit
    Logger.info("M-PESA Callback Received", %{
      params: params,
      checkout_id: get_in(params, ["Body", "stkCallback", "CheckoutRequestID"])
    })

    body = Map.get(params, "Body", %{})
    stk_callback = Map.get(body, "stkCallback", %{}) || Map.get(body, "STKCallback", %{})

    checkout_request_id = Map.get(stk_callback, "CheckoutRequestID")
    result_code = Map.get(stk_callback, "ResultCode")

    # Industrial Result Code Check: Handle both integer and string "0"
    status =
      case result_code do
        0 -> "success"
        "0" -> "success"
        _ -> "failed"
      end

    if checkout_request_id do
      Logger.info("M-PESA: Executing lifecycle for #{checkout_request_id}", %{status: status})

      # Complete the lifecycle (Update Payment + Create/Confirm Ticket)
      # We pass the entire stk_callback as the raw response update
      case Payments.complete_payment_lifecycle(checkout_request_id, status, stk_callback) do
        {:ok, _} ->
          Logger.info("M-PESA: Lifecycle SUCCESS for #{checkout_request_id}")

        {:error, reason} ->
          Logger.error("M-PESA: Lifecycle FAILED", %{
            id: checkout_request_id,
            reason: inspect(reason)
          })
      end

      # Safaricom strictly requires this specific JSON acknowledgment
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        200,
        Jason.encode!(%{
          "ResponseCode" => "00000000",
          "ResponseDesc" => "Success"
        })
      )
    else
      Logger.warning("M-PESA: Callback arrived with missing identifiers", %{params: params})
      conn |> put_status(400) |> json(%{error: "Invalid payload"})
    end
  end

  @doc """
  Flutterwave callback endpoint.
  """
  def flutterwave_callback(conn, params) do
    status = if Map.get(params, "status") == "successful", do: "success", else: "failed"
    tx_ref = Map.get(params, "tx_ref")

    if tx_ref do
      response = %{
        "status" => Map.get(params, "status"),
        "tx_ref" => tx_ref,
        "transaction_id" => Map.get(params, "transaction_id"),
        "amount" => Map.get(params, "amount")
      }

      Payments.update_payment_status(tx_ref, status, response)
      redirect(conn, to: "/payment-processing/#{tx_ref}?method=flutterwave")
    else
      redirect(conn, to: ~p"/")
    end
  end

  @doc """
  Flutterwave webhook endpoint.
  """
  def flutterwave_webhook(conn, params) do
    status = if Map.get(params, "status") == "successful", do: "success", else: "failed"
    tx_ref = Map.get(params, "tx_ref")

    response = %{
      "event" => Map.get(params, "event"),
      "status" => Map.get(params, "status"),
      "tx_ref" => tx_ref,
      "transaction_id" => Map.get(params, "transaction_id")
    }

    {:ok, _} = Payments.update_payment_status(tx_ref, status, response)

    json(conn, %{status: "ok"})
  end

  @doc """
  Paystack callback endpoint.
  """
  def paystack_callback(conn, params) do
    Logger.info("Paystack callback hit", %{
      params: params,
      query_params: conn.query_params,
      body_params: conn.body_params,
      method: conn.method
    })

    reference =
      params["reference"] ||
        params["data"]["reference"] ||
        conn.query_params["reference"] ||
        conn.body_params["reference"] ||
        conn.body_params["data"]["reference"]

    if reference do
      case Payments.complete_paystack_payment(reference) do
        {:ok, _ticket} ->
          Logger.info("Paystack payment verified and ticket created",
            reference: reference,
            status: "success"
          )

        {:error, reason} ->
          Logger.error("Paystack payment finalization failed",
            reference: reference,
            reason: inspect(reason)
          )
      end

      Phoenix.Controller.redirect(conn, to: "/payment-processing/#{reference}?method=paystack")
    else
      Logger.error("Paystack callback missing reference", %{
        params: params,
        query_params: conn.query_params,
        body_params: conn.body_params
      })

      Phoenix.Controller.redirect(conn, to: "/payment-processing/unknown?method=paystack")
    end
  end

  @doc """
  Paystack webhook endpoint.
  """
  def paystack_webhook(conn, params) do
    event = Map.get(params, "event")
    data = Map.get(params, "data", %{})
    reference = Map.get(data, "reference")

    response = %{
      "event" => event,
      "reference" => reference,
      "status" => Map.get(data, "status"),
      "gateway_response" => Map.get(data, "gateway_response")
    }

    if reference do
      case event do
        "charge.success" ->
          Payments.complete_paystack_payment(reference)
          Payments.update_payment_status(reference, "success", response)

        "charge.failed" ->
          Payments.update_payment_status(reference, "failed", response)

        _ ->
          Payments.update_payment_status(reference, "pending", response)
      end
    else
      Logger.error("Paystack webhook missing reference", params: params)
    end

    json(conn, %{status: "ok"})
  end
end
