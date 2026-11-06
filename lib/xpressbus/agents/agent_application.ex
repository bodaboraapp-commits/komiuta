defmodule Xpressbus.Agents.AgentApplication do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "agent_applications" do
    field(:password_hash, :string)

    field(:reference, :string)
    field(:full_name, :string)
    field(:email, :string)
    field(:phone, :string)
    field(:business_name, :string)
    field(:city, :string)
    field(:routes, :string)
    field(:payout_method, :string, default: "mpesa")
    field(:notes, :string)
    field(:status, :string, default: "pending")
    field(:admin_notes, :string)
    field(:reviewed_at, :utc_datetime)
    field(:email_verified_at, :utc_datetime)

    belongs_to(:bus_operator, Xpressbus.BusOperators.BusOperator)

    timestamps(type: :utc_datetime)
  end

  def changeset(application, attrs) do
    application
    |> cast(attrs, [
      :reference,
      :full_name,
      :email,
      :phone,
      :business_name,
      :city,
      :routes,
      :payout_method,
      :notes,
      :status,
      :admin_notes,
      :reviewed_at,
      :email_verified_at,
      :bus_operator_id
    ])
    |> update_change(:email, &normalise_email/1)
    |> update_change(:phone, &normalise_phone/1)
    |> validate_required([:full_name, :email, :phone, :business_name, :city])
    |> validate_length(:full_name, min: 3, max: 120)
    |> validate_length(:business_name, min: 2, max: 160)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_length(:phone, min: 9, max: 18)
    |> validate_inclusion(:payout_method, ["mpesa", "bank", "card"])
    |> validate_inclusion(:status, ["pending", "approved", "rejected"])
    |> foreign_key_constraint(:bus_operator_id)
    |> unique_constraint(:email, name: :agent_applications_email_index)
  end

  defp normalise_email(nil), do: nil

  defp normalise_email(email) do
    email |> to_string() |> String.trim() |> String.downcase()
  end

  defp normalise_phone(nil), do: nil

  defp normalise_phone(phone) do
    phone
    |> to_string()
    |> String.replace(~r/[^0-9+]/, "")
    |> case do
      "" -> nil
      value -> value
    end
  end
end
