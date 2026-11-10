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
    for {table, columns} <- @text_columns do
      normalise_text_columns(table, columns)
    end

    normalise_bus_seat_types()
  end

  def down do
    # Legacy currency spellings are not restored on rollback.
    :ok
  end

  # Set-based updates keep this migration fast on large ticket tables. The old
  # row-by-row version could hold a migration transaction open for a long time.
  defp normalise_text_columns(table, columns) do
    assignments =
      Enum.map_join(columns, ", ", fn column ->
        "#{column} = " <> replace_currency(column)
      end)

    where =
      Enum.map_join(columns, " OR ", fn column ->
        "#{column} LIKE '%KSH%' OR #{column} LIKE '%Ksh%' OR #{column} LIKE '%ksh%'"
      end)

    execute("UPDATE #{table} SET #{assignments} WHERE #{where}")
  end

  defp replace_currency(column) do
    Enum.reduce(["Kshs", "kshs", "KSH", "KSh", "Ksh", "ksh"], column, fn label, expr ->
      "REPLACE(#{expr}, '#{label}', 'KES')"
    end)
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
