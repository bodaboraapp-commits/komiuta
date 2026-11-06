defmodule Xpressbus.Agents do
  @moduledoc """
  Agent onboarding applications submitted from the Komiuta Agent PWA.
  """

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.Agents.AgentApplication
  alias Xpressbus.Agents.AgentLoginCode
  alias Xpressbus.AgentLoginEmail

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

  @doc """
  Starts an email-OTP login for an agent application identified by email or phone.

  Returns `{:ok, application}` when the email was handed to the mailer, or one of
  `{:error, :not_found}`, `{:error, :missing_email}`, `{:error, :delivery_failed}`,
  `{:error, {:cooldown, application}}` and `{:error, {:rate_limited, application}}`.
  """
  def find_by_phone(phone) when is_binary(phone) do
    Xpressbus.Firebase.phone_candidates(phone)
    |> Enum.find_value(fn candidate -> Repo.get_by(AgentApplication, phone: candidate) end)
  end

  def find_by_phone(_phone), do: nil

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

    cond do
      latest && DateTime.compare(latest.inserted_at, cooldown_cutoff) == :gt ->
        {:error, {:cooldown, application}}

      recent_count >= @login_code_max_per_hour ->
        {:error, {:rate_limited, application}}

      true ->
        code = generate_login_code()
        now = now()

        case store_login_code(application, code, now) do
          {:ok, _login_code} ->
            case AgentLoginEmail.deliver(application, code, login_code_ttl_minutes()) do
              :ok -> {:ok, application}
              {:error, _reason} -> {:error, :delivery_failed}
            end

          {:error, _changeset} ->
            {:error, :delivery_failed}
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
