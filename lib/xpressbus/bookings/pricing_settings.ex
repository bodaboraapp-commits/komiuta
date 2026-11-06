defmodule Xpressbus.Bookings.PricingSettings do
  @moduledoc """
  Admin-configurable checkout fees.

  Stored in the existing `integrations` table under the `pricing` provider so
  no schema migration is required. Values are cached in the database and read
  when a checkout LiveView mounts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Xpressbus.Integrations

  @primary_key false
  embedded_schema do
    field(:convenience_fee, :integer, default: 50)
    field(:tax_rate, :float, default: 0.0)
  end

  @default_convenience_fee 50
  @default_tax_rate 0.0

  @doc "Current checkout settings, with safe defaults when none are configured."
  def get do
    case Integrations.get_config_by_provider("pricing") do
      %{config: config} when is_map(config) ->
        %{
          convenience_fee: parse_integer(config["convenience_fee"], @default_convenience_fee),
          tax_rate: parse_float(config["tax_rate"], @default_tax_rate)
        }

      _ ->
        defaults()
    end
  end

  def defaults do
    %{convenience_fee: @default_convenience_fee, tax_rate: @default_tax_rate}
  end

  @doc "Changeset used by the admin pricing form and for validation."
  def changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:convenience_fee, :tax_rate])
    |> validate_required([:convenience_fee, :tax_rate])
    |> validate_number(:convenience_fee,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100_000
    )
    |> validate_number(:tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  @doc "Validates and saves the admin pricing settings."
  def update(attrs) do
    changeset = changeset(attrs)

    if changeset.valid? do
      settings = apply_changes(changeset)

      case Integrations.upsert_config_by_provider("pricing", %{
             active: true,
             config: %{
               "convenience_fee" => settings.convenience_fee,
               "tax_rate" => settings.tax_rate
             }
           }) do
        {:ok, _config} -> {:ok, settings}
        {:error, error} -> {:error, error}
      end
    else
      {:error, changeset}
    end
  end

  defp parse_integer(value, default) do
    case value do
      n when is_integer(n) -> n
      n when is_float(n) -> round(n)
      n when is_binary(n) -> parse_integer_string(n, default)
      _ -> default
    end
  end

  defp parse_integer_string(value, default) do
    case Integer.parse(String.trim(value)) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_float(value, default) do
    case value do
      n when is_integer(n) -> n * 1.0
      n when is_float(n) -> n
      n when is_binary(n) -> parse_float_string(n, default)
      _ -> default
    end
  end

  defp parse_float_string(value, default) do
    case Float.parse(String.trim(value)) do
      {n, _} -> n
      :error -> default
    end
  end
end
