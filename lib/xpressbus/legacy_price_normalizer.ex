defmodule Xpressbus.LegacyPriceNormalizer do
  @moduledoc """
  Normalises historical price copy that still uses the old `KSH`/`Ksh`
  currency labels.

  Price values are stored as human-readable strings in several legacy tables
  (`buses`, `tickets`, saved itineraries and the bus `seat_types` JSON). They
  are displayed directly to travellers, so they must use the same `KES` label as
  the rest of the product.
  """

  @legacy_currency ~r/(?<![A-Za-z])(?:kshs?|ksh)(?![A-Za-z])/i

  @doc """
  Replaces legacy currency labels in a single string with `KES`.

  Non-binary values are returned unchanged, which makes it safe to map over
  nullable database values.
  """
  def normalise(value) when is_binary(value) do
    Regex.replace(@legacy_currency, value, "KES")
  end

  def normalise(value), do: value

  @doc """
  Recursively normalises currency labels in JSON-shaped data (maps and lists).
  """
  def deep_normalise(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {key, deep_normalise(nested)} end)
  end

  def deep_normalise(value) when is_list(value) do
    Enum.map(value, &deep_normalise/1)
  end

  def deep_normalise(value), do: normalise(value)
end
