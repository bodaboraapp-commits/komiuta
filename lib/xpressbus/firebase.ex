defmodule Xpressbus.Firebase do
  @moduledoc """
  Firebase Phone Authentication (SMS OTP) support.

  The browser sends the SMS, verifies the code with the Firebase JS SDK and
  hands us a Firebase ID token. We validate that token through Firebase's
  Identity Toolkit REST API (Google verifies the signature, issuer, audience and
  expiry), then map the verified phone number to an existing KOMIUTA account.

  The Firebase web config is public (it is shipped to the browser by design); it
  is configured in `config/config.exs` and can be overridden with
  `FIREBASE_*` environment variables in `config/runtime.exs`.
  """

  require Logger

  alias Xpressbus.Accounts

  @lookup_url "https://identitytoolkit.googleapis.com/v1/accounts:lookup"
  @required_keys [:api_key, :auth_domain, :project_id, :app_id]
  @client_keys [
    :api_key,
    :auth_domain,
    :project_id,
    :storage_bucket,
    :messaging_sender_id,
    :app_id,
    :measurement_id
  ]

  @doc """
  Public Firebase web config for the browser, or `nil` when SMS login is not set up.
  """
  def client_config do
    config = config()

    if configured?(config) do
      Map.take(config, @client_keys)
    end
  end

  @doc "Whether the Firebase web config is complete enough to start SMS login."
  def configured?, do: configured?(config())

  @doc """
  Verifies a Firebase ID token and returns the verified E.164 phone number.

  Returns `{:ok, phone_number}`, `{:error, :not_configured}`,
  `{:error, :invalid_token}` or `{:error, :unavailable}`.
  """
  def verify_id_token(token) when is_binary(token) and token != "" do
    config = config()
    lookup_fun = Application.get_env(:xpressbus, :firebase_lookup_fun)

    cond do
      not configured?(config) ->
        {:error, :not_configured}

      is_function(lookup_fun, 1) ->
        normalize_lookup_result(lookup_fun.(token))

      true ->
        lookup_account(token, config)
    end
  end

  def verify_id_token(_token), do: {:error, :invalid_token}

  @doc """
  Shared phone-verification step used by both traveller and agent sign-in.

  Verifies the Firebase token once, normalises the verified phone number and
  returns every stored representation that identity lookups should try. Keeping
  this in one place prevents the two sign-in surfaces from drifting apart in
  validation or error handling.
  """
  def verify_phone_token(token) when is_binary(token) do
    token = String.trim(token)

    if token == "" do
      {:error, :missing_token}
    else
      case verify_id_token(token) do
        {:ok, phone} ->
          {:ok,
           %{
             e164: phone,
             local: normalize_phone(phone) || phone,
             candidates: phone_candidates(phone)
           }}

        {:error, :not_configured} ->
          {:error, :not_configured}

        {:error, :no_phone} ->
          {:error, :no_phone}

        {:error, :invalid_token} ->
          {:error, :invalid_token}

        {:error, _reason} ->
          {:error, :unavailable}
      end
    end
  end

  def verify_phone_token(_token), do: {:error, :missing_token}

  @doc """
  Lightweight readiness check for the admin Integration screen.

  Firebase returns `CONFIGURATION_NOT_FOUND` until Authentication has been
  initialised for the project, so this distinguishes a valid project/API key
  from a project where Phone sign-in has not been enabled yet.
  """
  def check_configuration do
    config = config()

    if configured?(config) do
      url = @lookup_url <> "?key=" <> URI.encode_www_form(config.api_key)

      case Req.post(url, json: %{idToken: "invalid-test-token"}, receive_timeout: 10_000) do
        {:ok, %Req.Response{status: 400, body: body}} -> classify_check(body)
        {:ok, %Req.Response{status: 200}} -> {:ok, :reachable}
        {:ok, %Req.Response{status: status}} -> {:error, {:http_error, status}}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :not_configured}
    end
  end

  @doc """
  Finds an existing KOMIUTA user by the phone number returned by Firebase.

  Firebase returns E.164 (`+254712345678`) while KOMIUTA stores local numbers
  (`0712345678`), so several representations are tried.
  """
  def find_user_by_phone(phone) when is_binary(phone) do
    phone
    |> phone_candidates()
    |> Enum.find_value(&Accounts.get_user_by_phone/1)
  end

  def find_user_by_phone(_phone), do: nil

  @doc """
  Normalises a phone number to the local Kenyan representation used by KOMIUTA.

      iex> Xpressbus.Firebase.normalize_phone("+254712345678")
      "0712345678"

      iex> Xpressbus.Firebase.normalize_phone("0712 345 678")
      "0712345678"
  """
  def normalize_phone(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    cond do
      String.starts_with?(digits, "254") and byte_size(digits) == 12 ->
        "0" <> binary_part(digits, 3, 9)

      String.starts_with?(digits, "0") and byte_size(digits) == 10 ->
        digits

      byte_size(digits) == 9 ->
        "0" <> digits

      digits == "" ->
        nil

      true ->
        "+" <> digits
    end
  end

  def normalize_phone(_phone), do: nil

  @doc "All plausible stored representations for a verified phone number."
  def phone_candidates(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    [
      phone,
      normalize_phone(phone),
      digits,
      "+" <> digits
    ]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.uniq()
  end

  defp config do
    Application.get_env(:xpressbus, :firebase, %{})
  end

  defp configured?(config) do
    Enum.all?(@required_keys, fn key ->
      value = Map.get(config, key)
      is_binary(value) and String.trim(value) != ""
    end)
  end

  defp lookup_account(token, config) do
    url = @lookup_url <> "?key=" <> URI.encode_www_form(config.api_key)

    case Req.post(url, json: %{idToken: token}, receive_timeout: 10_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        extract_phone(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Firebase ID token lookup failed",
          status: status,
          reason: inspect(body)
        )

        {:error, :invalid_token}

      {:error, reason} ->
        Logger.error("Firebase ID token lookup unavailable", reason: inspect(reason))
        {:error, :unavailable}
    end
  end

  defp extract_phone(body) when is_map(body) do
    with [user | _] <- Map.get(body, "users", []),
         phone when is_binary(phone) <- user["phoneNumber"] || phone_from_provider(user) do
      {:ok, phone}
    else
      _ -> {:error, :no_phone}
    end
  end

  defp extract_phone(_body), do: {:error, :no_phone}

  defp phone_from_provider(user) do
    case user["providerUserInfo"] do
      [%{"phoneNumber" => phone} | _] -> phone
      _ -> nil
    end
  end

  defp normalize_lookup_result({:ok, phone}) when is_binary(phone), do: {:ok, phone}
  defp normalize_lookup_result({:error, reason}), do: {:error, reason}
  defp normalize_lookup_result(phone) when is_binary(phone), do: {:ok, phone}
  defp normalize_lookup_result(_), do: {:error, :invalid_token}

  defp classify_check(body) when is_map(body) do
    message =
      get_in(body, ["error", "message"]) ||
        get_in(body, ["error", "errors", Access.at(0), "message"]) ||
        ""

    cond do
      String.contains?(message, "CONFIGURATION_NOT_FOUND") ->
        {:error, :authentication_not_initialized}

      String.contains?(message, "API_KEY_INVALID") or
          String.contains?(message, "API_KEY_EXPIRED") ->
        {:error, :invalid_api_key}

      String.contains?(message, "INVALID_ID_TOKEN") or
          String.contains?(message, "INVALID_IDP_RESPONSE") ->
        {:ok, :reachable}

      true ->
        {:error, :unknown}
    end
  end

  defp classify_check(_body), do: {:error, :unknown}
end
