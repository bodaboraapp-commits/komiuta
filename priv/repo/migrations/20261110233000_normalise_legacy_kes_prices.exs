defmodule Xpressbus.Repo.Migrations.NormaliseLegacyKesPrices do
  use Ecto.Migration

  alias Xpressbus.LegacyPriceNormalizer
  alias Xpressbus.Repo

  @text_columns [
    {"buses", ["price", "vip_price", "business_price", "first_class_price"]},
    {"tickets", ["price"]},
    {"saved_itineraries", ["budget"]}
  ]

  def up do
    for {table, columns} <- @text_columns,
        column <- columns do
      normalise_text_column(table, column)
    end

    normalise_bus_seat_types()
  end

  def down do
    # Legacy currency spellings are not restored on rollback.
    :ok
  end

  defp normalise_text_column(table, column) do
    %{rows: rows} =
      Repo.query!(
        "SELECT id, #{column} FROM #{table} WHERE #{column} IS NOT NULL AND #{column} <> ''"
      )

    for [id, value] <- rows, is_binary(value) do
      normalised = LegacyPriceNormalizer.normalise(value)

      if normalised != value do
        Repo.query!("UPDATE #{table} SET #{column} = ? WHERE id = ?", [normalised, id])
      end
    end
  end

  defp normalise_bus_seat_types do
    %{rows: rows} =
      Repo.query!("SELECT id, seat_types FROM buses WHERE seat_types IS NOT NULL")

    for [id, value] <- rows do
      raw =
        case value do
          value when is_binary(value) ->
            case Jason.decode(value) do
              {:ok, decoded} -> decoded
              {:error, _reason} -> nil
            end

          value ->
            value
        end

      if is_map(raw) or is_list(raw) do
        normalised = LegacyPriceNormalizer.deep_normalise(raw)

        if normalised != raw do
          Repo.query!("UPDATE buses SET seat_types = ? WHERE id = ?", [
            Jason.encode!(normalised),
            id
          ])
        end
      end
    end
  end
end
