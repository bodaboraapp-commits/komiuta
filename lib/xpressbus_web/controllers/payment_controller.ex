defmodule XpressbusWeb.PaymentController do
  @moduledoc """
  Handles payment provider callbacks and webhooks.

  Every endpoint in this module authenticates the request before it can change
  a payment or issue a ticket:

    * Paystack webhooks are authenticated with the `x-paystack-signature` HMAC
      computed over the raw request body.
    * Flutterwave webhooks are authenticated with the `verif-hash` header.
    * M-PESA STK callbacks are matched against the stored payment record and
      the requested amount before the lifecycle is completed.
    * Browser redirects are finalised through the provider verification API,
      so a forged redirect cannot mark a payment as paid.
  """

  use XpressbusWeb, :controller
  require Logger

  alias Xpressbus.Payments
  alias XpressbusWeb.RawBodyReader

  @doc """
  M-PESA STK callback endpoint.
  """
  def mpesa_callback(conn, params) do
    stk_callback = mpesa_stk_callback(params)
    checkout_request_id = Map.get(stk_callback, "CheckoutRequestID")
    result_code = Map.get(stk_callback, "ResultCode")
    metadata = mpesa_metadata(stk_callback)
    status = if result_code in [0, "0"], do: "success", else: "failed"

    Logger.info("M-PESA callback received", %{
      checkout_request_id: checkout_request_id,
      status: status,
      result_code: result_code,
      result_desc: Map.get(stk_callback, "ResultDesc")
    })

    if checkout_request_id do
      case Payments.validate_mpesa_callback(checkout_request_id, status, metadata) do
        {:ok, payment} when payment.status in ["success", "failed", "cancelled"] ->
          Logger.info("M-PESA callback already applied; ignoring duplicate", %{
            checkout_request_id: checkout_request_id,
            status: payment.status
          })

        {:ok, _payment} ->
          case Payments.complete_payment_lifecycle(checkout_request_id, status, stk_callback) do
            {:ok, _} ->
              Logger.info("M-PESA lifecycle completed", %{
                checkout_request_id: checkout_request_id,
                status: status
              })

            {:error, reason} ->
              Logger.error("M-PESA lifecycle failed", %{
                checkout_request_id: checkout_request_id,
                reason: inspect(reason)
              })
          end

        {:error, reason} ->
          Logger.error("Rejected M-PESA callback", %{
            checkout_request_id: checkout_request_id,
            reason: inspect(reason)
          })
      end

      mpesa_ack(conn)
    else
      Logger.warning("M-PESA callback arrived with missing identifiers", %{
        result_code: result_code
      })

      conn |> put_status(400) |> json(%{error: "Invalid payload"})
    end
  end

  @doc """
  Flutterwave browser redirect endpoint.

  The redirect parameters are not trusted directly: the transaction is
  verified with the Flutterwave API before the payment is finalised.
  """
  def flutterwave_callback(conn, params) do
    tx_ref = Map.get(params, "tx_ref")
    transaction_id = Map.get(params, "transaction_id") || Map.get(params, "id")

    if tx_ref do
      case Payments.complete_flutterwave_payment(tx_ref, transaction_id) do
        {:ok, _result} ->
          Logger.info("Flutterwave callback finalised", %{reference: tx_ref})

        {:error, reason} ->
          Logger.error("Flutterwave callback finalisation failed", %{
            reference: tx_ref,
            reason: inspect(reason)
          })
      end

      redirect(conn, to: "/payment-processing/#{tx_ref}?method=flutterwave")
    else
      redirect(conn, to: ~p"/")
    end
  end

  @doc """
  Flutterwave webhook endpoint.
  """
  def flutterwave_webhook(conn, params) do
    signature = conn |> get_req_header("verif-hash") |> List.first()

    case Payments.verify_flutterwave_signature(signature) do
      :ok ->
        data = Map.get(params, "data") || params
        tx_ref = Map.get(data, "tx_ref")
        transaction_id = Map.get(data, "id") || Map.get(data, "transaction_id")
        event = Map.get(params, "event") || Map.get(data, "event")

        Logger.info("Flutterwave webhook received", %{
          event: event,
          reference: tx_ref,
          transaction_id: transaction_id
        })

        case Payments.complete_flutterwave_payment(tx_ref, transaction_id) do
          {:ok, _result} ->
            json(conn, %{status: "ok"})

          {:error, :not_found} ->
            Logger.error("Flutterwave webhook for unknown reference", reference: tx_ref)
            json(conn, %{status: "ok"})

          {:error, reason} ->
            Logger.error("Flutterwave webhook finalisation failed", %{
              reference: tx_ref,
              reason: inspect(reason)
            })

            conn |> put_status(500) |> json(%{status: "error"})
        end

      {:error, reason} ->
        Logger.error("Rejected Flutterwave webhook", %{reason: inspect(reason)})
        conn |> put_status(401) |> json(%{error: "invalid signature"})
    end
  end

  @doc """
  Paystack browser redirect endpoint.

  The reference is always verified against the Paystack API before the payment
  is finalised.
  """
  def paystack_callback(conn, params) do
    reference = paystack_reference(conn, params)

    if reference do
      case Payments.complete_paystack_payment(reference) do
        {:ok, _result} ->
          Logger.info("Paystack payment verified and finalised", reference: reference)

        {:error, reason} ->
          Logger.error("Paystack payment finalisation failed", %{
            reference: reference,
            reason: inspect(reason)
          })
      end

      redirect(conn, to: "/payment-processing/#{reference}?method=paystack")
    else
      Logger.error("Paystack callback missing reference")

      redirect(conn, to: "/payment-processing/unknown?method=paystack")
    end
  end

  @doc """
  Paystack webhook endpoint.

  The webhook signature authenticates the delivery; the charge itself is then
  re-verified with Paystack before it can mark a payment as paid.
  """
  def paystack_webhook(conn, params) do
    raw_body = RawBodyReader.raw_body(conn)
    signature = conn |> get_req_header("x-paystack-signature") |> List.first()

    case Payments.verify_paystack_signature(raw_body, signature) do
      :ok ->
        event = Map.get(params, "event")
        data = Map.get(params, "data", %{})
        reference = Map.get(data, "reference")

        handle_paystack_event(event, reference)
        json(conn, %{status: "ok"})

      {:error, reason} ->
        Logger.error("Rejected Paystack webhook", %{reason: inspect(reason)})
        conn |> put_status(401) |> json(%{error: "invalid signature"})
    end
  end

  defp handle_paystack_event("charge.success", reference) when is_binary(reference) do
    case Payments.complete_paystack_payment(reference) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        Logger.error("Paystack webhook could not finalise payment", %{
          reference: reference,
          reason: inspect(reason)
        })
    end
  end

  defp handle_paystack_event("charge.failed", reference) when is_binary(reference) do
    Payments.update_payment_status(reference, "failed", %{"event" => "charge.failed"})
    :ok
  end

  defp handle_paystack_event(event, _reference) do
    # Never let unrelated events rewrite the status of a payment.
    Logger.info("Ignoring Paystack webhook event", %{event: event})
    :ok
  end

  defp paystack_reference(conn, params) do
    params["reference"] ||
      get_in(params, ["data", "reference"]) ||
      conn.query_params["reference"] ||
      conn.body_params["reference"] ||
      get_in(conn.body_params, ["data", "reference"])
  end

  defp mpesa_stk_callback(params) do
    body = Map.get(params, "Body", %{})
    Map.get(body, "stkCallback", %{}) || Map.get(body, "STKCallback", %{})
  end

  defp mpesa_metadata(stk_callback) do
    stk_callback
    |> Map.get("CallbackMetadata", %{})
    |> Map.get("Item", [])
    |> Enum.reduce(%{}, fn
      %{"Name" => name, "Value" => value}, acc when is_binary(name) ->
        Map.put(acc, name, value)

      _other, acc ->
        acc
    end)
  end

  # Safaricom expects this exact acknowledgement for accepted callbacks.
  defp mpesa_ack(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      200,
      Jason.encode!(%{
        "ResponseCode" => "00000000",
        "ResponseDesc" => "Success"
      })
    )
  end
end
