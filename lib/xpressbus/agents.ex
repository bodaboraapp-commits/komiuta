defmodule Xpressbus.Agents do
  @moduledoc """
  Agent onboarding applications submitted from the Komiuta Agent PWA.
  """

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.Agents.AgentApplication

  @page_size 20

  def create_application(attrs) do
    reference = "AGT-" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper))

    %AgentApplication{}
    |> AgentApplication.registration_changeset(Map.put(attrs, "reference", reference))
    |> Repo.insert()
  end

  @doc "Looks up an agent application by UUID."
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

  @doc "Authenticates an agent with email/phone and password."
  def authenticate(identifier, password) when is_binary(password) do
    with %AgentApplication{} = application <- find_by_identifier(identifier),
         true <- verify_password(password, application.password_hash) do
      {:ok, application}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  def authenticate(_identifier, _password), do: {:error, :invalid_credentials}

  @doc """
  Sets a password for an application. The activation form proves ownership with
  the application reference (emailed at sign-up) plus email/phone.
  """
  def activate(identifier, reference, attrs) do
    with %AgentApplication{} = application <- find_by_identifier(identifier),
         true <- reference_matches?(application, reference) do
      application
      |> AgentApplication.password_changeset(attrs)
      |> Repo.update()
    else
      _ -> {:error, :not_found}
    end
  end

  @doc "Hashes a password using PBKDF2, matching the admin password format."
  def hash_password(password) when is_binary(password) do
    salt = :crypto.strong_rand_bytes(16)
    dk = :crypto.pbkdf2_hmac(:sha256, password, salt, 100_000, 32)
    Base.encode64(salt <> dk)
  end

  @doc "Verifies a password against a stored PBKDF2 hash."
  def verify_password(_password, nil), do: false

  def verify_password(password, stored_hash) when is_binary(password) do
    decoded = Base.decode64!(stored_hash)
    salt = binary_part(decoded, 0, 16)
    dk = binary_part(decoded, 16, 32)
    test_dk = :crypto.pbkdf2_hmac(:sha256, password, salt, 100_000, 32)
    secure_compare(dk, test_dk)
  rescue
    _ -> false
  end

  def verify_password(_password, _hash), do: false

  defp reference_matches?(application, reference) do
    reference = to_string(reference || "") |> String.trim() |> String.upcase()
    reference != "" and application.reference == reference
  end

  defp normalise_phone(phone) do
    phone
    |> to_string()
    |> String.replace(~r/[^0-9+]/, "")
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp secure_compare(a, b) when byte_size(a) != byte_size(b), do: false
  defp secure_compare(a, b), do: :crypto.hash(:sha256, a) == :crypto.hash(:sha256, b)

  def list_applications do
    Repo.all(from(a in AgentApplication, order_by: [desc: a.inserted_at]))
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
      |> Repo.all()

    {applications, total}
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
