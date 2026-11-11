defmodule Xpressbus.Agents do
  @moduledoc """
  Agent onboarding applications submitted from the KOMIUTA Agent PWA.
  """

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.Agents.AgentApplication
  alias Xpressbus.Agents.AgentLoginCode
  alias Xpressbus.AgentLoginEmail
  alias Xpressbus.SMS

  @page_size 20

  @login_code_ttl_seconds 10 * 60
  @login_code_resend_seconds 60
  @login_code_max_attempts 5
  @login_code_max_per_hour 5

  def create_application(attrs) do
    reference = "AGT-" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper))

    %AgentApplication{}
    |> AgentApplication.changeset(Map.put(attrs, "reference", reference))
    |> Repo.insert()
  end

  @doc "Looks up an agent application by UUID."
  def find_by_email(email) when is_binary(email) do
    Repo.get_by(AgentApplication, email: email |> String.trim() |> String.downcase())
  end

  def find_by_email(_email), do: nil

  def get_application(id), do: Repo.get(AgentApplication, id)

  @doc """
  Finds an application by email address or phone number, using the same
  normalisation as the sign-up form.
  """
  def find_by_identifier(identifier) do
    identifier = to_string(identifier || "") |> String.trim()

    cond do
      identifier == "" ->
        nil

      String.contains?(identifier, "@") ->
        Repo.get_by(AgentApplication, email: String.downcase(identifier))

      true ->
        phone = normalise_phone(identifier)

        if phone do
          Repo.get_by(AgentApplication, phone: phone) ||
            Repo.get_by(AgentApplication, phone: String.trim_leading(phone, "+"))
        end
    end
  end

  @doc "How long an agent login code stays valid, in minutes."
  def login_code_ttl_minutes, do: div(@login_code_ttl_seconds, 60)

  @doc "Minimum number of seconds between agent login-code emails."
  def login_code_resend_seconds, do: @login_code_resend_seconds

  @doc "Whether the agent has proven ownership of the email on their application."
  def email_verified?(%AgentApplication{email_verified_at: %DateTime{}}), do: true
  def email_verified?(_application), do: false

  @doc """
  Starts a phone-first login for an agent.

  Returns `{:ok, application, :sms}` when the code was texted to the agent's
  phone, `{:ok, application, :email}` when SMS is unavailable/failed and the code
  was emailed instead, or one of the usual `{:error, reason}` values.
  """
  def request_phone_login_code(phone) when is_binary(phone) do
    case find_by_phone(phone) do
      %AgentApplication{} = application -> send_phone_login_code(application)
      nil -> {:error, :not_found}
    end
  end

  def request_phone_login_code(_phone), do: {:error, :not_found}

  @doc """
  Sends a verification code to `email` (which may be a corrected email entered
  by the agent) so the agent can prove ownership before reaching the dashboard.

  Returns `{:ok, email}` when the email was handed to the mailer.
  """
  def request_email_verification(%AgentApplication{} = application, email) do
    email = normalise_email_input(email)

    cond do
      not valid_email?(email) ->
        {:error, :invalid_email}

      email_taken_by_another_application?(application, email) ->
        {:error, :email_taken}

      true ->
        with {:ok, code} <- issue_login_code(application) do
          case AgentLoginEmail.deliver_verification(
                 application,
                 email,
                 code,
                 login_code_ttl_minutes()
               ) do
            :ok -> {:ok, email}
            {:error, _reason} -> {:error, :delivery_failed}
          end
        end
    end
  end

  @doc "Verifies the email verification code sent to an agent."
  def verify_email_code(%AgentApplication{} = application, code) do
    verify_login_code(application.id, code)
  end

  @doc "Stores the verified email on the application and marks it verified."
  def mark_email_verified(%AgentApplication{} = application, email) do
    application
    |> AgentApplication.changeset(%{
      email: normalise_email_input(email),
      email_verified_at: now()
    })
    |> Repo.update()
  end

  defp normalise_email_input(nil), do: nil

  defp normalise_email_input(email) do
    email |> to_string() |> String.trim() |> String.downcase()
  end

  defp email_taken_by_another_application?(%AgentApplication{} = application, email) do
    case find_by_email(email) do
      nil -> false
      %AgentApplication{id: id} -> id != application.id
    end
  end

  @doc """
  Starts an email-OTP login for an agent application identified by email or phone.

  Returns `{:ok, application}` when the email was handed to the mailer, or one of
  `{:error, :not_found}`, `{:error, :missing_email}`, `{:error, :delivery_failed}`,
  `{:error, {:cooldown, application}}` and `{:error, {:rate_limited, application}}`.
  """
  def find_by_phone(phone) when is_binary(phone) do
    candidates = Xpressbus.Firebase.phone_candidates(phone)

    Repo.one(
      from(application in AgentApplication,
        where: application.phone in ^candidates,
        limit: 1
      )
    ) || find_by_phone_digits(phone)
  end

  def find_by_phone(_phone), do: nil

  # Legacy applications may store a phone number with spaces, dashes or a
  # country-code prefix. Match on the last nine digits so the same verified
  # Firebase number resolves regardless of how it was originally entered.
  defp find_by_phone_digits(phone) do
    digits = phone |> to_string() |> String.replace(~r/\D/, "")

    if byte_size(digits) >= 9 do
      last_nine = String.slice(digits, -9, 9)

      Repo.one(
        from(application in AgentApplication,
          where:
            fragment(
              "RIGHT(REPLACE(REPLACE(REPLACE(REPLACE(?, ' ', ''), '-', ''), '+', ''), '(', ''), 9) = ?",
              application.phone,
              ^last_nine
            ),
          limit: 1
        )
      )
    end
  end

  def request_login_code(identifier) when is_binary(identifier) do
    case find_by_identifier(identifier) do
      nil ->
        {:error, :not_found}

      %AgentApplication{} = application ->
        if valid_email?(application.email) do
          send_agent_login_code(application)
        else
          {:error, :missing_email}
        end
    end
  end

  @doc "Re-sends an agent login code for an application that already started the flow."
  def resend_login_code(application_id) do
    case get_application(application_id) do
      nil -> {:error, :not_found}
      %AgentApplication{} = application -> send_agent_login_code(application)
    end
  end

  @doc "Re-sends a phone-first login code, falling back to email when SMS fails."
  def resend_phone_login_code(application_id) do
    case get_application(application_id) do
      nil -> {:error, :not_found}
      %AgentApplication{} = application -> send_phone_login_code(application)
    end
  end

  @doc """
  Verifies a 6-digit login code for an agent application. On success the code is
  consumed and the application is returned.
  """
  def verify_login_code(application_id, code)
      when is_binary(application_id) and is_binary(code) do
    code = String.trim(code)
    now = now()

    query =
      from(c in AgentLoginCode,
        where: c.agent_application_id == ^application_id and is_nil(c.consumed_at),
        order_by: [desc: c.inserted_at],
        limit: 1
      )

    case Repo.one(query) do
      nil ->
        {:error, :no_code}

      %AgentLoginCode{} = login_code ->
        cond do
          DateTime.compare(login_code.expires_at, now) != :gt ->
            {:error, :expired}

          login_code.attempts >= @login_code_max_attempts ->
            {:error, :too_many_attempts}

          secure_compare(digest_login_code(application_id, code), login_code.code_digest) ->
            consume_agent_login_code(login_code, application_id, now)

          true ->
            login_code
            |> AgentLoginCode.changeset(%{attempts: login_code.attempts + 1})
            |> Repo.update()

            {:error, :invalid}
        end
    end
  end

  def verify_login_code(_application_id, _code), do: {:error, :invalid}

  defp normalise_phone(phone) do
    phone
    |> to_string()
    |> String.replace(~r/[^0-9+]/, "")
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp secure_compare(a, b) when is_binary(a) and is_binary(b) do
    Plug.Crypto.secure_compare(a, b)
  end

  defp send_agent_login_code(%AgentApplication{} = application) do
    with {:ok, code} <- issue_login_code(application) do
      case AgentLoginEmail.deliver(application, code, login_code_ttl_minutes()) do
        :ok -> {:ok, application}
        {:error, _reason} -> {:error, :delivery_failed}
      end
    end
  end

  defp send_phone_login_code(%AgentApplication{} = application) do
    with {:ok, code} <- issue_login_code(application) do
      message =
        "Your KOMIUTA Agent sign-in code is #{code}. " <>
          "It expires in #{login_code_ttl_minutes()} minutes. Do not share it."

      sms_result = SMS.send(application.phone, message)

      email_result =
        if valid_email?(application.email) do
          AgentLoginEmail.deliver(application, code, login_code_ttl_minutes())
        else
          {:error, :missing_email}
        end

      case {sms_result, email_result} do
        {{:ok, _details}, :ok} -> {:ok, application, :sms_and_email}
        {{:ok, _details}, {:error, _reason}} -> {:ok, application, :sms}
        {{:error, _reason}, :ok} -> {:ok, application, :email}
        _ -> {:error, :delivery_failed}
      end
    end
  end

  defp issue_login_code(%AgentApplication{} = application) do
    now = now()
    cooldown_cutoff = DateTime.add(now, -@login_code_resend_seconds, :second)
    hour_cutoff = DateTime.add(now, -3_600, :second)

    latest =
      Repo.one(
        from(c in AgentLoginCode,
          where: c.agent_application_id == ^application.id,
          order_by: [desc: c.inserted_at],
          limit: 1
        )
      )

    recent_count =
      Repo.aggregate(
        from(c in AgentLoginCode,
          where:
            c.agent_application_id == ^application.id and
              c.inserted_at >= ^hour_cutoff
        ),
        :count,
        :id
      )

    cooldown_active? =
      latest && is_nil(latest.consumed_at) &&
        DateTime.compare(latest.inserted_at, cooldown_cutoff) == :gt

    cond do
      cooldown_active? ->
        {:error, {:cooldown, application}}

      recent_count >= @login_code_max_per_hour ->
        {:error, {:rate_limited, application}}

      true ->
        code = generate_login_code()

        case store_login_code(application, code, now) do
          {:ok, _login_code} -> {:ok, code}
          {:error, _changeset} -> {:error, :delivery_failed}
        end
    end
  end

  defp store_login_code(%AgentApplication{} = application, code, now) do
    Repo.transaction(fn ->
      # Invalidate any previous unconsumed codes for this application.
      Repo.update_all(
        from(c in AgentLoginCode,
          where: c.agent_application_id == ^application.id and is_nil(c.consumed_at)
        ),
        set: [consumed_at: now]
      )

      # Housekeeping: drop codes older than a day.
      Repo.delete_all(
        from(c in AgentLoginCode,
          where:
            c.agent_application_id == ^application.id and
              c.inserted_at < ^DateTime.add(now, -86_400, :second)
        )
      )

      %AgentLoginCode{}
      |> AgentLoginCode.changeset(%{
        agent_application_id: application.id,
        code_digest: digest_login_code(application.id, code),
        expires_at: DateTime.add(now, @login_code_ttl_seconds, :second)
      })
      |> Repo.insert()
    end)
  end

  defp consume_agent_login_code(%AgentLoginCode{} = login_code, application_id, now) do
    case login_code
         |> AgentLoginCode.changeset(%{consumed_at: now})
         |> Repo.update() do
      {:ok, _login_code} ->
        {:ok, get_application(application_id)}

      {:error, _changeset} ->
        {:error, :invalid}
    end
  end

  defp generate_login_code do
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp digest_login_code(application_id, code) do
    :crypto.mac(
      :hmac,
      :sha256,
      login_code_secret(),
      "agent-login:#{application_id}:#{code}"
    )
    |> Base.encode16(case: :lower)
  end

  defp login_code_secret do
    endpoint_config = Application.get_env(:xpressbus, XpressbusWeb.Endpoint, [])

    Keyword.get(endpoint_config, :secret_key_base) ||
      Application.get_env(:xpressbus, :login_code_secret) ||
      "komiuta-login-code-dev-secret"
  end

  defp valid_email?(email) when is_binary(email) do
    String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  end

  defp valid_email?(_email), do: false

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  def list_applications do
    Repo.all(
      from(a in AgentApplication, order_by: [desc: a.inserted_at], preload: [:bus_operator])
    )
  end

  def paginate_applications(page, page_size \\ @page_size, search \\ "") do
    search = String.trim(to_string(search || ""))
    pattern = "%#{search}%"

    query = from(a in AgentApplication, order_by: [desc: a.inserted_at])

    query =
      if search == "" do
        query
      else
        where(
          query,
          [a],
          fragment("LOWER(?) LIKE LOWER(?)", a.full_name, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", a.business_name, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", a.email, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", a.phone, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", a.reference, ^pattern)
        )
      end

    total = Repo.aggregate(query, :count, :id)

    applications =
      query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> preload(:bus_operator)
      |> Repo.all()

    {applications, total}
  end

  @doc "Loads an application with its assigned bus operator (partner) preloaded."
  def get_application_with_bus_operator(id) do
    AgentApplication
    |> Repo.get(id)
    |> case do
      nil -> nil
      application -> Repo.preload(application, :bus_operator)
    end
  end

  @doc "Attaches or detaches an agent application from a bus operator."
  def assign_bus_operator(%AgentApplication{} = application, bus_operator_id) do
    bus_operator_id =
      case bus_operator_id do
        nil ->
          nil

        "" ->
          nil

        id when is_integer(id) ->
          id

        id when is_binary(id) ->
          case Integer.parse(id) do
            {value, ""} -> value
            _ -> nil
          end
      end

    application
    |> Ecto.Changeset.change(bus_operator_id: bus_operator_id)
    |> Repo.update()
  end

  def get_application!(id), do: Repo.get!(AgentApplication, id)

  @doc "Sets which partner bookings an agent can see: all, or one from/to route."
  def assign_booking_scope(%AgentApplication{} = application, scope, from, to) do
    scope = if scope in ["all", "route"], do: scope, else: "all"

    attrs = %{
      booking_scope: scope,
      booking_from: if(scope == "route", do: blank_to_nil(from), else: nil),
      booking_to: if(scope == "route", do: blank_to_nil(to), else: nil)
    }

    application
    |> AgentApplication.changeset(attrs)
    |> Repo.update()
  end

  defp blank_to_nil(value) do
    case to_string(value || "") |> String.trim() do
      "" -> nil
      trimmed -> trimmed
    end
  end

  @doc "Short admin-facing description of an agent's booking visibility."
  def scope_description(%AgentApplication{booking_scope: "route"} = application) do
    case {application.booking_from, application.booking_to} do
      {from, to} when is_binary(from) and is_binary(to) and from != "" and to != "" ->
        "specific route #{from} → #{to}"

      _ ->
        "all partner bookings"
    end
  end

  def scope_description(%AgentApplication{}), do: "all partner bookings"

  def update_status(%AgentApplication{} = application, status, admin_notes \\ nil)
      when status in ["pending", "approved", "rejected"] do
    application
    |> AgentApplication.changeset(%{
      status: status,
      admin_notes: admin_notes || application.admin_notes,
      reviewed_at:
        if(status == "pending", do: nil, else: DateTime.utc_now() |> DateTime.truncate(:second))
    })
    |> Repo.update()
  end

  def count_pending do
    Repo.aggregate(from(a in AgentApplication, where: a.status == "pending"), :count, :id)
  end
end
