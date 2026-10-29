defmodule Xpressbus.Payments do
  @moduledoc """
  The Payments context.
  """
  import Ecto.Query, warn: false
  require Logger
  alias Xpressbus.Repo
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Integrations
  alias Xpressbus.Accounts
  alias Xpressbus.Tickets

  @doc """
  Initiates a payment for the given provider.
  """
  def initiate_payment(provider, attrs) do
    config = Integrations.get_config_by_provider(provider)

    Logger.info("Initiating payment", %{
      provider: provider,
      config_active: config && config.active
    })

    if config && config.active do
      payment = %Payment{
        provider: provider,
        amount: attrs[:amount],
        currency: attrs[:currency] || "KES",
        status: "pending",
        reference: attrs[:reference],
        phone_number: attrs[:phone_number] || "",
        ticket_id: attrs[:ticket_id],
        raw_response:
          Map.put(attrs[:raw_response] || %{}, "booking_context", attrs[:booking_context] || %{})
      }

      case Repo.insert(payment) do
        {:ok, inserted_payment} ->
          case call_provider(provider, config, attrs) do
            {:ok, provider_response} ->
              Logger.info("PAYMENT_JOURNEY_INTERNAL: Provider call succeeded", %{
                provider: provider,
                reference: attrs[:reference],
                payment_id: inserted_payment.id
              })

              {:ok, provider_response}

            {:error, reason} ->
              Logger.error("Payment initiation failed at provider call", %{
                provider: provider,
                reason: inspect(reason),
                reference: attrs[:reference]
              })

              # Log the error to the DB record
              update_payment_status(attrs[:reference], "failed", %{
                "error" => to_string(reason),
                "step" => "provider_call"
              })

              {:error, reason}
          end

        {:error, changeset} ->
          Logger.error("Failed to insert initial payment record", %{
            errors: inspect(changeset.errors)
          })

          {:error, "Database error"}
      end
    else
      {:error, "Payment provider is not active"}
    end
  end

  @doc """
  Updates payment status from callback/webhook.
  """
  def update_payment_status(reference, status, raw_response \\ %{})

  def update_payment_status(reference, status, raw_response) when not is_nil(reference) do
    Logger.info("Updating payment status", %{reference: reference, status: status})

    # INDUSTRIAL LOOKUP: Try reference or ticket_id
    payment =
      Repo.get_by(Payment, reference: reference) ||
        Repo.get_by(Payment, ticket_id: reference)

    cond do
      is_nil(payment) ->
        Logger.error("Could not find payment record to update", %{reference: reference})
        {:error, :not_found}

      # Never let a later webhook/callback downgrade a payment that the
      # provider already confirmed as paid.
      payment.status == "success" and status != "success" ->
        Logger.warning("Ignoring payment status regression", %{
          reference: reference,
          current_status: payment.status,
          attempted_status: status
        })

        {:ok, payment}

      true ->
        Logger.info("Payment record found for update", %{
          id: payment.id,
          current_status: payment.status
        })

        # Preserve existing raw_response (like booking_context) when updating
        current_raw = payment.raw_response || %{}
        # Merge string-keyed maps
        merged_raw = Map.merge(current_raw, raw_response)

        result =
          payment
          |> Payment.changeset(%{status: status, raw_response: merged_raw})
          |> Repo.update()

        case result do
          {:ok, updated} ->
            Logger.info("Payment status successfully updated in DB", %{id: updated.id})
            {:ok, updated}

          {:error, changeset} ->
            Logger.error("Failed to update payment status in DB", %{
              errors: inspect(changeset.errors)
            })

            {:error, changeset}
        end
    end
  end

  def update_payment_status(_reference, _status, _raw_response) do
    {:error, :invalid_reference}
  end

  @doc """
  Gets a payment by any relevant identifier (reference, checkout_id, or ticket_id).
  """
  def get_payment_by_reference(id) when is_binary(id) do
    # Search for any record where reference or ticket_id matches
    from(p in Payment,
      where: p.reference == ^id or p.ticket_id == ^id,
      order_by: [desc: p.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_payment_by_reference(_), do: nil

  @doc """
  Completes the payment lifecycle: updates status and, if successful, creates the ticket.
  """
  def complete_payment_lifecycle(reference, status, raw_response \\ %{}) do
    Logger.info("PAYMENT_JOURNEY_FINALIZE: Completing payment lifecycle", %{
      reference: reference,
      status: status
    })

    case update_payment_status(reference, status, raw_response) do
      {:ok, payment} ->
        if status == "success" do
          case create_ticket_from_payment(payment) do
            {:ok, ticket} ->
              maybe_create_user_transaction(payment)
              {:ok, ticket}

            {:error, reason} ->
              Logger.error("Failed to create ticket in lifecycle", %{
                reference: reference,
                error: inspect(reason)
              })

              {:error, reason}
          end
        else
          {:ok, payment}
        end

      error ->
        error
    end
  end

  @doc """
  Verifies a Paystack transaction via the Paystack verify endpoint and, on a
  successful payment, creates the ticket from the booking context that was
  stored at initiation time.

  Returns `{:ok, ticket}` on success or `{:error, reason}` otherwise.
  """
  def complete_paystack_payment(reference) do
    Logger.info("PAYMENT_JOURNEY_FINALIZE: Completing Paystack payment", %{reference: reference})
    payment = get_payment_by_reference(reference)

    if payment do
      case verify_paystack(reference) do
        {:ok, data} ->
          Logger.info("PAYMENT_JOURNEY_FINALIZE: Paystack verification successful", %{
            status: data["status"]
          })

          status = if data["status"] == "success", do: "success", else: "failed"
          complete_payment_lifecycle(reference, status, data)

        {:error, reason} ->
          Logger.error("PAYMENT_JOURNEY_FINALIZE: Paystack verification failed", %{reason: reason})

          update_payment_status(reference, "failed", %{"error" => to_string(reason)})
          {:error, reason}
      end
    else
      Logger.error("PAYMENT_JOURNEY_FINALIZE: Payment record NOT FOUND for reference", %{
        reference: reference
      })

      {:error, :not_found}
    end
  end

  @doc """
  Verifies a Paystack transaction by calling the Paystack verify endpoint.
  """
  def verify_paystack(reference) do
    config = Integrations.get_config_by_provider("paystack")
    secret_key = get_in(config && config.config, ["secret_key"])

    cond do
      is_nil(secret_key) or secret_key == "" ->
        {:error, "Missing Paystack secret key"}

      true ->
        headers = %{"Authorization" => "Bearer #{secret_key}"}

        case Req.get("https://api.paystack.co/transaction/verify/#{reference}", headers: headers) do
          {:ok, %Req.Response{status: 200, body: %{"status" => true, "data" => data}}} ->
            {:ok, data}

          {:ok, %Req.Response{status: status, body: body}} ->
            Logger.error("Paystack verify failed",
              status: status,
              reference: reference,
              body: body
            )

            {:error, "Paystack verify (#{status}): #{body["message"] || "verification failed"}"}

          {:error, reason} ->
            Logger.error("Paystack verify request error",
              reference: reference,
              reason: inspect(reason)
            )

            {:error, "Paystack connection error: #{inspect(reason)}"}
        end
    end
  end

  # --- Webhook authenticity & callback validation ---------------------------

  @doc """
  Verifies the `x-paystack-signature` header of a Paystack webhook request.

  Paystack signs the exact raw request body with HMAC-SHA512 using the
  integration secret key, then hex-encodes the digest.
  """
  def verify_paystack_signature(raw_body, signature) do
    secret_key = provider_config("paystack")["secret_key"]
    signature = to_string(signature || "")

    cond do
      is_nil(secret_key) or secret_key == "" ->
        Logger.error("Paystack webhook received but no secret key is configured")
        {:error, :not_configured}

      signature == "" ->
        {:error, :missing_signature}

      not is_binary(raw_body) or raw_body == "" ->
        {:error, :missing_body}

      true ->
        expected =
          :crypto.mac(:hmac, :sha512, secret_key, raw_body)
          |> Base.encode16(case: :lower)

        if Plug.Crypto.secure_compare(expected, String.downcase(signature)) do
          :ok
        else
          {:error, :invalid_signature}
        end
    end
  end

  @doc """
  Verifies the `verif-hash` header Flutterwave sends with webhook requests.

  The expected value is the secret hash configured in the Flutterwave
  dashboard. A missing configuration is treated as a failure: silently
  accepting unsigned webhooks would let anyone mark a payment as paid.
  """
  def verify_flutterwave_signature(signature) do
    config = provider_config("flutterwave")
    secret_hash = config["webhook_hash"] || config["secret_hash"]
    signature = to_string(signature || "")

    cond do
      is_nil(secret_hash) or secret_hash == "" ->
        Logger.error("Flutterwave webhook received but no webhook hash is configured")
        {:error, :not_configured}

      signature == "" ->
        {:error, :missing_signature}

      Plug.Crypto.secure_compare(to_string(secret_hash), signature) ->
        :ok

      true ->
        {:error, :invalid_signature}
    end
  end

  @doc """
  Verifies a Flutterwave transaction with the provider API before treating it
  as paid. This is the authoritative check used from callbacks/webhooks.
  """
  def verify_flutterwave(transaction_id) do
    secret_key = provider_config("flutterwave")["secret_key"]
    transaction_id = to_string(transaction_id || "")

    cond do
      is_nil(secret_key) or secret_key == "" ->
        {:error, "Missing Flutterwave secret key"}

      transaction_id == "" ->
        {:error, "Missing Flutterwave transaction id"}

      true ->
        url = "https://api.flutterwave.com/v3/transactions/#{transaction_id}/verify"
        headers = %{"Authorization" => "Bearer #{secret_key}"}

        case Req.get(url, headers: headers, receive_timeout: 20_000) do
          {:ok, %Req.Response{status: 200, body: %{"status" => "success", "data" => data}}}
          when is_map(data) ->
            {:ok, data}

          {:ok, %Req.Response{status: status, body: body}} ->
            Logger.error("Flutterwave verify failed", %{
              status: status,
              transaction_id: transaction_id,
              body: body
            })

            {:error, "Flutterwave verify (#{status}): #{provider_message(body)}"}

          {:error, reason} ->
            Logger.error("Flutterwave verify request error", %{
              transaction_id: transaction_id,
              reason: inspect(reason)
            })

            {:error, "Flutterwave connection error: #{inspect(reason)}"}
        end
    end
  end

  @doc """
  Verifies a Flutterwave transaction and, when the provider confirms a
  successful payment of the expected amount, completes the payment lifecycle
  (marking the payment and confirming the ticket).
  """
  def complete_flutterwave_payment(reference, transaction_id) do
    payment = get_payment_by_reference(reference)

    cond do
      is_nil(payment) ->
        Logger.error("Flutterwave finalize: payment record NOT FOUND", %{reference: reference})
        {:error, :not_found}

      is_nil(transaction_id) or to_string(transaction_id) == "" ->
        {:error, "Missing Flutterwave transaction id"}

      true ->
        case verify_flutterwave(transaction_id) do
          {:ok, data} ->
            status = if data["status"] == "successful", do: "success", else: "failed"

            if status == "success" and not amount_matches?(payment.amount, data["amount"]) do
              Logger.error("Flutterwave amount mismatch; refusing to complete payment", %{
                reference: reference,
                expected: payment.amount,
                received: data["amount"]
              })

              update_payment_status(reference, "failed", %{
                "error" => "amount_mismatch",
                "provider_data" => data
              })

              {:error, :amount_mismatch}
            else
              complete_payment_lifecycle(reference, status, data)
            end

          {:error, reason} ->
            Logger.error("Flutterwave verification failed", %{
              reference: reference,
              reason: inspect(reason)
            })

            {:error, reason}
        end
    end
  end

  @doc """
  Validates an M-PESA STK callback against the payment record it claims to
  finish. Successful callbacks must reference a known payment and report the
  same amount that was requested; otherwise the callback is rejected instead
  of minting a ticket from an unverified payload.
  """
  def validate_mpesa_callback(checkout_request_id, status, metadata \\ %{}) do
    case get_payment_by_reference(checkout_request_id) do
      nil ->
        Logger.error("M-PESA callback for unknown CheckoutRequestID", %{
          checkout_request_id: checkout_request_id
        })

        {:error, :not_found}

      %Payment{} = payment ->
        cond do
          payment.status == "success" ->
            {:ok, payment}

          status == "success" ->
            if amount_matches?(payment.amount, Map.get(metadata, "Amount")) do
              {:ok, payment}
            else
              Logger.error("M-PESA amount mismatch; refusing to complete payment", %{
                checkout_request_id: checkout_request_id,
                expected: payment.amount,
                received: Map.get(metadata, "Amount")
              })

              {:error, {:amount_mismatch, payment.amount, Map.get(metadata, "Amount")}}
            end

          true ->
            {:ok, payment}
        end
    end
  end

  defp provider_config(provider) do
    case Integrations.get_config_by_provider(provider) do
      %{config: config} when is_map(config) -> config
      _ -> %{}
    end
  end

  defp provider_message(%{"message" => message}) when is_binary(message), do: message
  defp provider_message(body) when is_binary(body), do: body
  defp provider_message(_body), do: "verification failed"

  defp amount_matches?(expected, actual) when is_integer(expected) do
    case to_amount(actual) do
      nil -> false
      amount -> round(amount) == expected
    end
  end

  defp amount_matches?(_expected, _actual), do: true

  defp to_amount(value) when is_integer(value), do: value * 1.0
  defp to_amount(value) when is_float(value), do: value

  defp to_amount(value) when is_binary(value) do
    case Float.parse(String.replace(value, ",", "")) do
      {amount, _rest} -> amount
      :error -> nil
    end
  end

  defp to_amount(_value), do: nil

  defp maybe_create_user_transaction(%{raw_response: %{"booking_context" => context}}) do
    user_id = Map.get(context, "user_id") || Map.get(context, :user_id)
    amount = Map.get(context, "amount") || Map.get(context, :amount)
    ticket_id = Map.get(context, "ticket_id") || Map.get(context, :ticket_id)

    if user_id && amount do
      Accounts.create_user_transaction(%{
        user_id: user_id,
        amount: amount,
        type: "debit",
        description: "Bus Ticket Booking: #{ticket_id}",
        status: "completed",
        reference_id: ticket_id
      })
    end
  end

  defp maybe_create_user_transaction(_payment), do: nil

  defp create_ticket_from_payment(%{raw_response: raw}) do
    booking = get_in(raw, ["booking_context"]) || %{}

    # Handle string or atom keys for ticket_id
    ticket_id = Map.get(booking, "ticket_id") || Map.get(booking, :ticket_id)

    if ticket_id && Tickets.get_ticket(ticket_id) do
      # If ticket exists, ensure it's confirmed
      ticket = Tickets.get_ticket(ticket_id)
      Tickets.update_ticket(ticket, %{status: "confirmed"})
      {:ok, ticket}
    else
      # ... logic to create ...
      booking_attrs =
        for {k, v} <- booking, into: %{} do
          {to_string(k), v}
        end

      booking_attrs
      |> Map.put_new("seats", [])
      |> Map.put("ticket_id", ticket_id)
      # INDUSTRIAL SUCCESS MARK
      |> Map.put("status", "confirmed")
      |> Tickets.create_ticket()
    end
  end

  defp call_provider("mpesa", config, attrs) do
    mode = get_in(config.config, ["mode"]) || "sandbox"
    type = get_in(config.config, ["type"]) || "paybill"
    short_code = get_in(config.config, ["business_shortcode"])
    consumer_key = get_in(config.config, ["consumer_key"]) |> to_string() |> String.trim()
    consumer_secret = get_in(config.config, ["consumer_secret"]) |> to_string() |> String.trim()
    pass_key = get_in(config.config, ["passkey"]) |> to_string() |> String.trim()
    callback_url = get_in(config.config, ["callback_url"])

    base_url =
      if mode == "production",
        do: "https://api.safaricom.co.ke",
        else: "https://sandbox.safaricom.co.ke"

    if consumer_key != "" and consumer_secret != "" and not is_nil(short_code) do
      Logger.info("M-PESA: Initiating flow for phone: #{attrs[:phone_number]}")
      auth = Base.encode64("#{consumer_key}:#{consumer_secret}")

      # Step 1: Get OAuth Token (Daraja requires GET for token generation)
      case Req.get("#{base_url}/oauth/v1/generate",
             params: [grant_type: "client_credentials"],
             headers: %{
               "Authorization" => "Basic #{auth}",
               "User-Agent" => "Mozilla/5.0",
               "Accept" => "application/json"
             },
             receive_timeout: 20_000
           ) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          decoded_body =
            cond do
              is_map(body) ->
                body

              is_binary(body) and body != "" ->
                case Jason.decode(body) do
                  {:ok, d} -> d
                  _ -> %{}
                end

              true ->
                %{}
            end

          case decoded_body["access_token"] do
            nil ->
              Logger.error("M-PESA OAuth succeeded (200) but no access_token found in body", %{
                body: body
              })

              {:error, "M-PESA Auth failed: Invalid token response"}

            token ->
              # Step 2: Trigger STK Push
              timestamp =
                Calendar.strftime(DateTime.utc_now() |> DateTime.add(3, :hour), "%Y%m%d%H%M%S")

              password = Base.encode64("#{short_code}#{pass_key}#{timestamp}")

              phone = attrs[:phone_number] |> String.replace(~r/[^0-9]/, "")

              phone =
                cond do
                  String.starts_with?(phone, "0") ->
                    "254" <> String.slice(phone, 1..-1//1)

                  String.starts_with?(phone, "254") ->
                    phone

                  String.starts_with?(phone, "7") or String.starts_with?(phone, "1") ->
                    "254" <> phone

                  true ->
                    phone
                end

              Logger.info("M-PESA: Normalized phone for STK push: #{phone}")

              body = %{
                "BusinessShortCode" => short_code,
                "Password" => password,
                "Timestamp" => timestamp,
                "TransactionType" =>
                  if(type == "till", do: "CustomerBuyGoodsOnline", else: "CustomerPayBillOnline"),
                "Amount" => round(attrs[:amount]),
                "PartyA" => phone,
                "PartyB" => short_code,
                "PhoneNumber" => phone,
                "CallBackURL" => callback_url,
                "AccountReference" => attrs[:ticket_id] || attrs[:reference],
                "TransactionDesc" => "Ticket Payment"
              }

              Logger.info("Triggering M-PESA STK Push", %{phone: phone, short_code: short_code})

              case Req.post("#{base_url}/mpesa/stkpush/v1/processrequest",
                     json: body,
                     headers: %{
                       "Authorization" => "Bearer #{token}",
                       "User-Agent" => "Mozilla/5.0 (Komiuta)",
                       "Accept" => "application/json"
                     },
                     receive_timeout: 30_000
                   ) do
                {:ok, %Req.Response{status: 200, body: %{"ResponseCode" => "0"} = mpesa_response}} ->
                  checkout_id = mpesa_response["CheckoutRequestID"]
                  # Update payment record reference for tracking
                  update_payment_status(attrs[:reference], "pending", mpesa_response)

                  # We need to swap the reference to CheckoutRequestID
                  payment = Repo.get_by(Payment, reference: attrs[:reference])

                  if payment,
                    do: Repo.update(Payment.changeset(payment, %{reference: checkout_id}))

                  Logger.info("M-PESA STK Push accepted", %{checkout_id: checkout_id})

                  {:ok,
                   %{
                     status: "success",
                     reference: checkout_id,
                     provider_response: mpesa_response,
                     message: "STK Push sent"
                   }}

                {:ok, %Req.Response{status: status, body: body}} ->
                  Logger.error("M-PESA STK Push rejected", %{
                    status: status,
                    body: body,
                    phone: phone
                  })

                  {:error,
                   "M-PESA Error: #{if is_map(body), do: body["errorMessage"] || body["ResponseDescription"], else: "HTTP #{status}"}"}

                {:error, reason} ->
                  Logger.error("M-PESA STK Request failed", %{reason: inspect(reason)})
                  {:error, "M-PESA connection error"}
              end
          end

        {:ok, %Req.Response{status: status, body: body, headers: headers}} ->
          Logger.error("M-PESA OAuth failed", %{status: status, body: body, headers: headers})

          error_msg =
            case body do
              %{"errorMessage" => msg} ->
                msg

              _ when is_binary(body) ->
                if String.starts_with?(body, "<"),
                  do: "Security Filter (403)",
                  else: String.slice(body, 0..100)

              _ ->
                "HTTP #{status}"
            end

          {:ok, _} =
            update_payment_status(attrs[:reference], "failed", %{
              "error" => error_msg,
              "status" => status
            })

          {:error, "M-PESA Auth failed: #{error_msg}"}

        {:error, reason} ->
          Logger.error("M-PESA Auth connection error", %{reason: inspect(reason)})
          {:error, "M-PESA connection error"}
      end
    else
      {:error, "Missing M-PESA configuration credentials"}
    end
  end

  defp call_provider("flutterwave", config, attrs) do
    secret_key = get_in(config.config, ["secret_key"])

    unless secret_key do
      {:error, "Missing Flutterwave secret key"}
    else
      reference =
        attrs[:reference] ||
          "FLW_" <>
            (:crypto.strong_rand_bytes(8)
             |> Base.url_encode64(padding: false)
             |> String.replace("_", "-"))

      callback_url =
        get_in(config.config, ["callback_url"]) ||
          "https://api.komiuta.com/v1/payments/flutterwave/callback"

      body = %{
        tx_ref: reference,
        amount: attrs[:amount],
        currency: attrs[:currency] || "KES",
        redirect_url: callback_url,
        customer: %{
          email: "#{attrs[:phone_number] || "user"}@xpressbus.com",
          phonenumber: attrs[:phone_number],
          name: attrs[:passenger_name] || "Traveler"
        },
        customizations: %{
          title: "Komiuta Tickets",
          logo: "https://api.komiuta.com/images/logo_brand.png"
        }
      }

      headers = %{
        "Authorization" => "Bearer #{secret_key}",
        "Content-Type" => "application/json"
      }

      case Req.post("https://api.flutterwave.com/v3/payments", json: body, headers: headers) do
        {:ok,
         %Req.Response{status: 200, body: %{"status" => "success", "data" => %{"link" => link}}}} ->
          {:ok,
           %{
             status: "success",
             reference: reference,
             provider_response: body,
             message: "Payment initiated",
             authorization_url: link
           }}

        {:ok, %Req.Response{body: body}} ->
          Logger.error("Flutterwave failed", %{body: body})
          {:error, "Flutterwave Error: #{body["message"] || "Failed"}"}

        {:error, reason} ->
          {:error, "Flutterwave connection error: #{inspect(reason)}"}
      end
    end
  end

  defp call_provider("paystack", config, attrs) do
    secret_key = config.config["secret_key"] |> to_string() |> String.trim()
    config_callback = get_in(config.config, ["callback_url"])

    Logger.info(
      "Paystack config check: has_secret_key=#{not is_nil(secret_key)} callback_url=#{config_callback}"
    )

    unless secret_key do
      {:error, "Missing Paystack secret key"}
    else
      amount_kobo = (attrs[:amount] || 0) * 100
      # Extract email from booking context if available
      raw_email =
        get_in(attrs, [:booking_context, :payment_email]) ||
          get_in(attrs, [:booking_context, "payment_email"])

      raw_phone = attrs[:phone_number]

      email =
        case raw_email |> to_string() |> String.trim() do
          "" ->
            phone = raw_phone |> to_string() |> String.replace(~r/[^0-9]/, "")

            if phone == "" do
              "guest@komiuta.com"
            else
              # Normalize phone number: remove leading 0 and add 254 prefix if needed
              normalized_phone =
                if String.starts_with?(phone, "0") do
                  "254" <> String.slice(phone, 1..-1//1)
                else
                  phone
                end

              "#{normalized_phone}@komiuta.com"
            end

          _ ->
            # Override payment_email from booking context - always use phone@komiuta.com
            phone = raw_phone |> to_string() |> String.replace(~r/[^0-9]/, "")

            if phone == "" do
              "guest@komiuta.com"
            else
              normalized_phone =
                if String.starts_with?(phone, "0") do
                  "254" <> String.slice(phone, 1..-1//1)
                else
                  phone
                end

              "#{normalized_phone}@komiuta.com"
            end
        end

      reference =
        attrs[:reference] ||
          "PSK_" <>
            (:crypto.strong_rand_bytes(8)
             |> Base.url_encode64(padding: false)
             |> String.replace("_", "-"))

      callback_url = config_callback || "https://xpressbus.com/payments/paystack/callback"

      body = %{
        amount: amount_kobo,
        email: email,
        reference: reference,
        callback_url: callback_url,
        currency: attrs[:currency] || "KES"
      }

      Logger.info("Calling Paystack API with body: #{inspect(body)}")

      headers = %{
        "Authorization" => "Bearer #{secret_key}",
        "Content-Type" => "application/json"
      }

      case Req.post("https://api.paystack.co/transaction/initialize",
             json: body,
             headers: headers
           ) do
        {:ok, %Req.Response{status: 200, body: %{"status" => true, "data" => data}}} ->
          authorization_url = Map.get(data, "authorization_url")

          Logger.info("Paystack API success", %{
            status: 200,
            authorization_url: authorization_url,
            data: data
          })

          response = %{
            "status" => true,
            "message" => "Payment initiated",
            "data" => %{
              "reference" => reference,
              "authorization_url" => authorization_url,
              "amount" => attrs[:amount],
              "currency" => attrs[:currency] || "KES"
            }
          }

          {:ok,
           %{
             status: "success",
             reference: reference,
             provider_response: response,
             message: "Payment initiated successfully",
             authorization_url: authorization_url
           }}

        {:ok, %Req.Response{status: 200, body: %{"status" => false, "message" => message}}} ->
          Logger.error("Paystack API returned error", %{message: message, body: body})
          {:error, "Paystack Error: #{message}"}

        {:ok, %Req.Response{status: status, body: body}} ->
          msg = body["message"] || "Initialization failed"
          Logger.error("Paystack initialization failed: status=#{status} body=#{inspect(body)}")
          {:error, "Paystack Error (#{status}): #{msg}"}

        {:error, reason} ->
          Logger.error("Paystack request error", %{reason: reason})
          {:error, "Paystack Connection Error: #{inspect(reason)}"}
      end
    end
  end

  defp call_provider(_provider, _config, _attrs) do
    {:error, "Unsupported payment provider"}
  end
end
