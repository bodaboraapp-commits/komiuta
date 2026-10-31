defmodule Xpressbus.Barcode do
  @moduledoc """
  Dependency-free **Code 128B** barcode renderer (ISO/IEC 15417).

  Used on boarding passes so gate staff can scan a standard linear barcode as
  well as the QR code. Code 128B covers ASCII 32–126 (digits, letters, `-`, etc.),
  which is exactly what ticket IDs need.

  The encoder emits the mandatory start symbol, data symbols, the mod-103
  checksum symbol and the stop pattern, with a 10-module quiet zone on each side
  as required by the specification.
  """

  @start_code_b 104
  @stop 106
  @quiet_modules 10

  # ISO/IEC 15417 symbol patterns (values 0..106), each 11 modules wide except
  # the 13-module stop pattern.
  @patterns [
    "11011001100",
    "11001101100",
    "11001100110",
    "10010011000",
    "10010001100",
    "10001001100",
    "10011001000",
    "10011000100",
    "10001100100",
    "11001001000",
    "11001000100",
    "11000100100",
    "10110011100",
    "10011011100",
    "10011001110",
    "10111001100",
    "10011101100",
    "10011100110",
    "11001110010",
    "11001011100",
    "11001001110",
    "11011100100",
    "11001110100",
    "11101101110",
    "11101001100",
    "11100101100",
    "11100100110",
    "11101100100",
    "11100110100",
    "11100110010",
    "11011011000",
    "11011000110",
    "11000110110",
    "10100011000",
    "10001011000",
    "10001000110",
    "10110001000",
    "10001101000",
    "10001100010",
    "11010001000",
    "11000101000",
    "11000100010",
    "10110111000",
    "10110001110",
    "10001101110",
    "10111011000",
    "10111000110",
    "10001110110",
    "11101110110",
    "11010001110",
    "11000101110",
    "11011101000",
    "11011100010",
    "11011101110",
    "11101011000",
    "11101000110",
    "11100010110",
    "11101101000",
    "11101100010",
    "11100011010",
    "11101111010",
    "11001000010",
    "11110001010",
    "10100110000",
    "10100001100",
    "10010110000",
    "10010000110",
    "10000101100",
    "10000100110",
    "10110010000",
    "10110000100",
    "10011010000",
    "10011000010",
    "10000110100",
    "10000110010",
    "11000010010",
    "11001010000",
    "11110111010",
    "11000010100",
    "10001111010",
    "10100111100",
    "10010111100",
    "10010011110",
    "10111100100",
    "10011110100",
    "10011110010",
    "11110100100",
    "11110010100",
    "11110010010",
    "11011011110",
    "11011110110",
    "11110110110",
    "10101111000",
    "10100011110",
    "10001011110",
    "10111101000",
    "10111100010",
    "11110101000",
    "11110100010",
    "10111011110",
    "10111101110",
    "11101011110",
    "11110101110",
    "11010000100",
    "11010010000",
    "11010011100",
    "1100011101011"
  ]

  @doc """
  Encodes `payload` as Code 128B and returns the module bit-string.

  Returns `{:ok, bits}` or `{:error, :unsupported_character}` when the payload
  contains characters outside ASCII 32–126.
  """
  @spec encode(String.t()) :: {:ok, String.t()} | {:error, :unsupported_character | :empty}
  def encode(payload) when is_binary(payload) do
    with :ok <- validate(payload) do
      data_values =
        payload
        |> String.to_charlist()
        |> Enum.map(&(&1 - 32))

      checksum =
        data_values
        |> Enum.with_index(1)
        |> Enum.reduce(@start_code_b, fn {value, weight}, sum -> sum + value * weight end)
        |> rem(103)

      bits =
        ([@start_code_b | data_values] ++ [checksum, @stop])
        |> Enum.map_join(&Enum.at(@patterns, &1))

      {:ok, bits}
    end
  end

  @doc """
  Renders `payload` as an inline SVG Code 128 barcode.

  Options: `:module_width` (px, default 2), `:height` (px, default 64),
  `:responsive` (when true the SVG fills its container width while keeping the
  bars proportional, default false) and `:aria_label`.
  """
  @spec svg(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def svg(payload, opts \\ []) do
    with {:ok, bits} <- encode(payload) do
      module_width = Keyword.get(opts, :module_width, 2)
      height = Keyword.get(opts, :height, 64)
      aria_label = Keyword.get(opts, :aria_label, "Barcode")
      responsive = Keyword.get(opts, :responsive, false)

      total_modules = byte_size(bits) + @quiet_modules * 2
      width = total_modules * module_width
      width_attr = if responsive, do: ~s(width="100%"), else: ~s(width="#{width}")

      bars =
        bits
        |> String.graphemes()
        |> Enum.with_index(@quiet_modules)
        |> Enum.flat_map(fn
          {"1", index} ->
            [
              ~s(<rect x="#{index * module_width}" y="0" width="#{module_width}" height="#{height}"/>)
            ]

          {"0", _index} ->
            []
        end)
        |> Enum.join()

      svg = """
      <svg xmlns="http://www.w3.org/2000/svg" #{width_attr} height="#{height}" viewBox="0 0 #{width} #{height}" role="img" aria-label="#{aria_label}" shape-rendering="crispEdges" preserveAspectRatio="xMidYMid meet">
        <rect width="#{width}" height="#{height}" fill="#ffffff"/>
        <g fill="#000000">#{bars}</g>
      </svg>
      """

      {:ok, svg}
    end
  end

  defp validate(""), do: {:error, :empty}

  defp validate(payload) do
    if payload |> String.to_charlist() |> Enum.all?(&(&1 >= 32 and &1 <= 126)) do
      :ok
    else
      {:error, :unsupported_character}
    end
  end
end
