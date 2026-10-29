defmodule Xpressbus.QR do
  @moduledoc """
  A small, dependency-free QR Code encoder.

  Supports byte mode with error correction level M and versions 1–10, which
  covers ticket identifiers and verification URLs. The output is an SVG string,
  so boarding passes no longer depend on a third-party QR image service.

  The implementation follows ISO/IEC 18004: data encoding, Reed–Solomon error
  correction over GF(256), interleaving, function patterns, data placement,
  mask evaluation and format/version information.
  """

  import Bitwise

  # Data codewords per version for error correction level M.
  @data_codewords %{
    1 => 16,
    2 => 28,
    3 => 44,
    4 => 64,
    5 => 86,
    6 => 108,
    7 => 124,
    8 => 154,
    9 => 182,
    10 => 216
  }

  # {block count, data codewords per block, EC codewords per block} for level M.
  @ec_blocks %{
    1 => [{1, 16, 10}],
    2 => [{1, 28, 16}],
    3 => [{1, 44, 26}],
    4 => [{2, 32, 18}],
    5 => [{2, 43, 24}],
    6 => [{4, 27, 16}],
    7 => [{4, 31, 18}],
    8 => [{2, 38, 22}, {2, 39, 22}],
    9 => [{3, 36, 22}, {2, 37, 22}],
    10 => [{4, 43, 26}, {1, 44, 26}]
  }

  # Alignment pattern centre coordinates per version.
  @alignment %{
    1 => [],
    2 => [6, 18],
    3 => [6, 22],
    4 => [6, 26],
    5 => [6, 30],
    6 => [6, 34],
    7 => [6, 22, 38],
    8 => [6, 24, 42],
    9 => [6, 26, 46],
    10 => [6, 28, 50]
  }

  @max_version 10
  @ec_level_bits 0b00
  @format_mask 0x5412
  @format_poly 0x537
  @version_poly 0x1F25
  @dark_module_row_offset 8

  @doc """
  Encodes `payload` and returns `{:ok, qr}` where `qr` contains `:version`,
  `:size`, `:mask` and the `:modules` matrix (rows of booleans, `true` = dark).
  Returns `{:error, :too_long}` when the payload does not fit version 10.

  Options:

    * `:mask` - force a mask number (0–7) instead of automatic selection. Only
      intended for tests/diagnostics.
  """
  @spec encode(binary(), keyword()) :: {:ok, map()} | {:error, :too_long}
  def encode(payload, opts \\ []) when is_binary(payload) do
    with {:ok, version} <- pick_version(byte_size(payload)) do
      data = build_data_codewords(payload, version)
      ec = build_ec_codewords(data, version)
      codewords = interleave(data, ec, version)
      {:ok, build_matrix(codewords, version, Keyword.get(opts, :mask))}
    end
  end

  @doc """
  Encodes `payload` and returns `{:ok, svg}`. Options:

    * `:size` - pixel size of the rendered SVG (default: 100% responsive)
    * `:aria_label` - accessible label for the image
  """
  @spec svg(binary(), keyword()) :: {:ok, binary()} | {:error, :too_long}
  def svg(payload, opts \\ []) do
    case encode(payload) do
      {:ok, qr} -> {:ok, to_svg(qr, opts)}
      error -> error
    end
  end

  # --- Encoding -------------------------------------------------------------

  defp pick_version(byte_count) do
    Enum.find_value(1..@max_version, {:error, :too_long}, fn version ->
      data = Map.fetch!(@data_codewords, version)
      count_bits = if version <= 9, do: 8, else: 16

      if byte_count <= div(data * 8 - 4 - count_bits, 8), do: {:ok, version}
    end)
  end

  defp build_data_codewords(payload, version) do
    count_bits = if version <= 9, do: 8, else: 16
    total_bits = Map.fetch!(@data_codewords, version) * 8

    bits = <<0b0100::4, byte_size(payload)::size(count_bits), payload::binary>>

    bits =
      case total_bits - bit_size(bits) do
        remaining when remaining >= 4 -> <<bits::bitstring, 0::4>>
        remaining -> <<bits::bitstring, 0::size(remaining)>>
      end

    bits =
      case rem(bit_size(bits), 8) do
        0 -> bits
        padding -> <<bits::bitstring, 0::size(8 - padding)>>
      end

    codewords = for <<byte::8 <- bits>>, do: byte
    pad_to(codewords, Map.fetch!(@data_codewords, version))
  end

  defp pad_to(codewords, target) when length(codewords) >= target, do: codewords

  defp pad_to(codewords, target) do
    pad_bytes = Stream.cycle([0xEC, 0x11]) |> Enum.take(target - length(codewords))
    codewords ++ pad_bytes
  end

  defp build_ec_codewords(data, version) do
    blocks = expand_blocks(version)

    {data_blocks, _rest} =
      Enum.map_reduce(blocks, data, fn {_count, data_len, ec_len}, remaining ->
        {block, rest} = Enum.split(remaining, data_len)
        {{block, ec_len}, rest}
      end)

    Enum.map(data_blocks, fn {block, ec_len} ->
      rs_encode(block, ec_len)
    end)
  end

  defp expand_blocks(version) do
    Enum.flat_map(Map.fetch!(@ec_blocks, version), fn {count, data_len, ec_len} ->
      List.duplicate({count, data_len, ec_len}, count)
    end)
  end

  defp interleave(data, ec, version) do
    blocks = data_blocks(data, version)

    interleaved_data =
      for index <- 0..(blocks |> Enum.map(&length/1) |> Enum.max() |> Kernel.-(1)),
          block <- blocks,
          index < length(block),
          do: Enum.at(block, index)

    max_ec = ec |> Enum.map(&length/1) |> Enum.max()

    interleaved_ec =
      for index <- 0..(max_ec - 1),
          block <- ec,
          index < length(block),
          do: Enum.at(block, index)

    interleaved_data ++ interleaved_ec
  end

  defp data_blocks(data, version) do
    {blocks, _} =
      Enum.map_reduce(expand_blocks(version), data, fn {_count, data_len, _ec_len}, remaining ->
        {block, rest} = Enum.split(remaining, data_len)
        {block, rest}
      end)

    blocks
  end

  # --- Reed-Solomon ---------------------------------------------------------

  defp rs_encode(data, ec_len) do
    generator = rs_generator(ec_len)
    {exp, log} = gf_tables()

    result =
      (data ++ List.duplicate(0, ec_len))
      |> Enum.with_index()
      |> Map.new(fn {byte, index} -> {index, byte} end)

    result =
      Enum.reduce(0..(length(data) - 1), result, fn index, acc ->
        coefficient = Map.fetch!(acc, index)

        if coefficient == 0 do
          acc
        else
          generator
          |> Enum.with_index()
          |> Enum.reduce(acc, fn {gen_coefficient, offset}, inner ->
            value = gf_mul(gen_coefficient, coefficient, exp, log)
            Map.update!(inner, index + offset, &bxor(&1, value))
          end)
        end
      end)

    for index <- length(data)..(length(data) + ec_len - 1)//1, do: Map.fetch!(result, index)
  end

  defp rs_generator(ec_len) do
    {exp, log} = gf_tables()

    Enum.reduce(0..(ec_len - 1), [1], fn power, polynomial ->
      alpha = elem(exp, power)
      polynomial_mul(polynomial, [1, alpha], exp, log)
    end)
  end

  defp polynomial_mul(left, right, exp, log) do
    result = List.duplicate(0, length(left) + length(right) - 1)

    left
    |> Enum.with_index()
    |> Enum.reduce(result, fn {left_coefficient, i}, acc ->
      right
      |> Enum.with_index()
      |> Enum.reduce(acc, fn {right_coefficient, j}, inner ->
        value = gf_mul(left_coefficient, right_coefficient, exp, log)
        List.update_at(inner, i + j, &bxor(&1, value))
      end)
    end)
  end

  defp gf_tables do
    # exp[i] = 2^i in GF(256) with primitive polynomial x^8+x^4+x^3+x^2+1.
    {reversed, _} =
      Enum.reduce(1..255, {[1], 1}, fn _, {acc, value} ->
        next = if value < 128, do: value * 2, else: bxor(value * 2, 0x11D)
        {[next | acc], next}
      end)

    exp = reversed |> Enum.reverse() |> List.to_tuple()
    log = exp |> Tuple.to_list() |> Enum.with_index() |> Map.new()
    {exp, log}
  end

  defp gf_mul(0, _b, _exp, _log), do: 0
  defp gf_mul(_a, 0, _exp, _log), do: 0

  defp gf_mul(a, b, exp, log) do
    elem(exp, rem(Map.fetch!(log, a) + Map.fetch!(log, b), 255))
  end

  # --- Matrix construction --------------------------------------------------

  defp build_matrix(codewords, version, forced_mask) do
    size = version * 4 + 17
    {modules, reserved} = base_matrix(version)
    {modules, _index} = place_data(modules, reserved, codewords, size)

    {best_mask, best_matrix} =
      if is_integer(forced_mask) and forced_mask in 0..7 do
        candidate =
          modules
          |> apply_mask(forced_mask, reserved, size)
          |> place_format_info(forced_mask, size)

        {forced_mask, candidate}
      else
        Enum.reduce(0..7, {nil, nil}, fn mask, {best_mask, best_matrix} ->
          candidate =
            modules
            |> apply_mask(mask, reserved, size)
            |> place_format_info(mask, size)

          if best_mask == nil or penalty(candidate, size) < penalty(best_matrix, size) do
            {mask, candidate}
          else
            {best_mask, best_matrix}
          end
        end)
      end

    %{version: version, size: size, modules: best_matrix, mask: best_mask}
  end

  defp base_matrix(version) do
    size = version * 4 + 17
    empty = for(_ <- 1..size, do: for(_ <- 1..size, do: nil))
    reserved = for(_ <- 1..size, do: for(_ <- 1..size, do: false))

    {modules, reserved} =
      {empty, reserved}
      |> put_finder(0, 0)
      |> put_finder(size - 7, 0)
      |> put_finder(0, size - 7)
      |> put_timing(size)
      |> put_alignment(version, size)
      |> put_dark_module(size)
      |> reserve_format(size)
      |> put_version_info(version, size)

    {modules, reserved}
  end

  defp put_finder({modules, reserved}, x, y) do
    Enum.reduce(0..6, {modules, reserved}, fn dy, {mods, res} ->
      Enum.reduce(0..6, {mods, res}, fn dx, {mods, res} ->
        dark? = dx == 0 or dx == 6 or dy == 0 or dy == 6 or (dx in 2..4 and dy in 2..4)
        {put_module(mods, x + dx, y + dy, dark?), put_reserved(res, x + dx, y + dy)}
      end)
    end)
    |> put_separators(x, y)
  end

  defp put_separators({modules, reserved}, x, y) do
    size = length(modules)

    Enum.reduce(-1..7, {modules, reserved}, fn dy, {mods, res} ->
      Enum.reduce(-1..7, {mods, res}, fn dx, {mods, res} ->
        px = x + dx
        py = y + dy

        if (dx in [-1, 7] or dy in [-1, 7]) and px in 0..(size - 1) and py in 0..(size - 1) do
          {put_module(mods, px, py, false), put_reserved(res, px, py)}
        else
          {mods, res}
        end
      end)
    end)
  end

  defp put_timing({modules, reserved}, size) do
    Enum.reduce(8..(size - 9)//1, {modules, reserved}, fn index, {mods, res} ->
      dark? = rem(index, 2) == 0

      {mods, res} =
        if is_nil(module_at(mods, index, 6)) do
          {put_module(mods, index, 6, dark?), put_reserved(res, index, 6)}
        else
          {mods, res}
        end

      if is_nil(module_at(mods, 6, index)) do
        {put_module(mods, 6, index, dark?), put_reserved(res, 6, index)}
      else
        {mods, res}
      end
    end)
  end

  defp put_alignment({modules, reserved}, version, size) do
    centres = Map.fetch!(@alignment, version)

    centres
    |> Enum.flat_map(fn x -> Enum.map(centres, fn y -> {x, y} end) end)
    |> Enum.reduce({modules, reserved}, fn {cx, cy}, {mods, res} ->
      overlaps_finder? =
        (cx <= 8 and cy <= 8) or (cx >= size - 9 and cy <= 8) or (cx <= 8 and cy >= size - 9)

      if overlaps_finder? do
        {mods, res}
      else
        Enum.reduce(-2..2, {mods, res}, fn dy, {mods, res} ->
          Enum.reduce(-2..2, {mods, res}, fn dx, {mods, res} ->
            dark? = abs(dx) == 2 or abs(dy) == 2 or (dx == 0 and dy == 0)
            x = cx + dx
            y = cy + dy

            {put_module(mods, x, y, dark?), put_reserved(res, x, y)}
          end)
        end)
      end
    end)
  end

  defp put_dark_module({modules, reserved}, size) do
    {put_module(modules, 8, size - @dark_module_row_offset, true),
     put_reserved(reserved, 8, size - @dark_module_row_offset)}
  end

  defp reserve_format({modules, reserved}, size) do
    # Reserve exactly the format-information modules. The timing modules at
    # (row 6, col 8) and (row 8, col 6) are NOT format modules and must stay.
    coords =
      Enum.map(0..5, fn i -> {8, i} end) ++
        [{8, 7}, {8, 8}, {7, 8}] ++
        Enum.map(9..14, fn i -> {14 - i, 8} end) ++
        Enum.map(0..7, fn i -> {size - 1 - i, 8} end) ++
        Enum.map(8..14, fn i -> {8, size - 15 + i} end) ++
        [{8, size - 8}]

    Enum.reduce(coords, {modules, reserved}, fn {x, y}, {mods, res} ->
      {put_module(mods, x, y, false), put_reserved(res, x, y)}
    end)
  end

  defp put_version_info({modules, reserved}, version, _size) when version < 7,
    do: {modules, reserved}

  defp put_version_info({modules, reserved}, version, size) do
    bits = version_info_bits(version)

    Enum.reduce(0..17, {modules, reserved}, fn i, {mods, res} ->
      bit = (bits >>> i &&& 1) == 1
      a = size - 11 + rem(i, 3)
      b = div(i, 3)

      {put_module(mods, a, b, bit), put_reserved(res, a, b)}
      |> then(fn {mods, res} ->
        {put_module(mods, b, a, bit), put_reserved(res, b, a)}
      end)
    end)
  end

  defp place_data(modules, reserved, codewords, size) do
    bits =
      for byte <- codewords, bit <- 7..0//-1, do: (byte >>> bit &&& 1) == 1

    columns =
      0..(size - 1)
      |> Enum.reject(&(&1 == 6))
      |> Enum.reverse()
      |> Enum.chunk_every(2)

    Enum.reduce(Enum.with_index(columns), {modules, 0}, fn {[right, left], pair_index},
                                                           {mods, index} ->
      rows =
        if rem(pair_index, 2) == 0,
          do: Enum.to_list((size - 1)..0//-1),
          else: Enum.to_list(0..(size - 1))

      Enum.reduce(rows, {mods, index}, fn row, {mods, index} ->
        Enum.reduce([right, left], {mods, index}, fn column, {mods, index} ->
          if reserved_at(reserved, row, column) do
            {mods, index}
          else
            bit = Enum.at(bits, index, false)
            {put_module(mods, column, row, bit), index + 1}
          end
        end)
      end)
    end)
  end

  defp apply_mask(modules, mask, reserved, size) do
    Enum.reduce(0..(size - 1), modules, fn row, mods ->
      Enum.reduce(0..(size - 1), mods, fn column, mods ->
        if reserved_at(reserved, row, column) do
          mods
        else
          dark? = module_at(mods, column, row)

          if mask_bit?(mask, row, column) do
            put_module(mods, column, row, not dark?)
          else
            mods
          end
        end
      end)
    end)
  end

  defp mask_bit?(0, row, column), do: rem(row + column, 2) == 0
  defp mask_bit?(1, row, _column), do: rem(row, 2) == 0
  defp mask_bit?(2, _row, column), do: rem(column, 3) == 0
  defp mask_bit?(3, row, column), do: rem(row + column, 3) == 0
  defp mask_bit?(4, row, column), do: rem(div(row, 2) + div(column, 3), 2) == 0
  defp mask_bit?(5, row, column), do: rem(row * column, 2) + rem(row * column, 3) == 0
  defp mask_bit?(6, row, column), do: rem(rem(row * column, 2) + rem(row * column, 3), 2) == 0
  defp mask_bit?(7, row, column), do: rem(rem(row + column, 2) + rem(row * column, 3), 2) == 0

  defp place_format_info(modules, mask, size) do
    bits = format_info_bits(mask)

    modules =
      Enum.reduce(0..5, modules, fn i, mods -> put_module(mods, 8, i, bit?(bits, i)) end)

    modules =
      modules
      |> put_module(8, 7, bit?(bits, 6))
      |> put_module(8, 8, bit?(bits, 7))
      |> put_module(7, 8, bit?(bits, 8))

    modules =
      Enum.reduce(9..14, modules, fn i, mods -> put_module(mods, 14 - i, 8, bit?(bits, i)) end)

    modules =
      Enum.reduce(0..7, modules, fn i, mods ->
        put_module(mods, size - 1 - i, 8, bit?(bits, i))
      end)

    modules =
      Enum.reduce(8..14, modules, fn i, mods ->
        put_module(mods, 8, size - 15 + i, bit?(bits, i))
      end)

    put_module(modules, 8, size - 8, true)
  end

  defp format_info_bits(mask) do
    data = bxor(@ec_level_bits <<< 3, mask)
    remainder = bch_remainder(data <<< 10, @format_poly)
    bxor(bxor(data <<< 10, remainder), @format_mask)
  end

  defp version_info_bits(version) do
    remainder = bch_remainder(version <<< 12, @version_poly)
    bxor(version <<< 12, remainder)
  end

  defp bch_remainder(value, generator) do
    reduction(value, generator)
  end

  defp reduction(value, generator) when value < generator, do: value

  defp reduction(value, generator) do
    shift = bit_length(value) - bit_length(generator)
    reduction(bxor(value, generator <<< shift), generator)
  end

  defp bit_length(0), do: 0
  defp bit_length(value), do: value |> Integer.digits(2) |> length()

  defp bit?(bits, index), do: (bits >>> index &&& 1) == 1

  # --- Module helpers -------------------------------------------------------

  defp put_module(modules, x, y, value) when x >= 0 and y >= 0 do
    if y < length(modules) and x < length(Enum.at(modules, 0)) do
      List.update_at(modules, y, fn row -> List.replace_at(row, x, value) end)
    else
      modules
    end
  end

  defp put_reserved(reserved, x, y) when x >= 0 and y >= 0 do
    if y < length(reserved) and x < length(Enum.at(reserved, 0)) do
      List.update_at(reserved, y, fn row -> List.replace_at(row, x, true) end)
    else
      reserved
    end
  end

  defp module_at(modules, x, y), do: modules |> Enum.at(y) |> Enum.at(x)
  defp reserved_at(reserved, y, x), do: reserved |> Enum.at(y) |> Enum.at(x)

  # --- Penalty scoring ------------------------------------------------------

  defp penalty(modules, size) do
    rows = modules
    columns = transpose(modules, size)

    rule1(rows) + rule2(modules, size) + rule3(rows) + rule1(columns) + rule3(columns) +
      rule4(modules, size)
  end

  defp rule1(lines) do
    Enum.reduce(lines, 0, fn line, total ->
      line
      |> Enum.chunk_by(& &1)
      |> Enum.reduce(total, fn run, acc ->
        if length(run) >= 5, do: acc + 3 + (length(run) - 5), else: acc
      end)
    end)
  end

  defp rule2(modules, size) do
    for row <- 0..(size - 2), column <- 0..(size - 2), reduce: 0 do
      acc ->
        block = [
          module_at(modules, column, row),
          module_at(modules, column + 1, row),
          module_at(modules, column, row + 1),
          module_at(modules, column + 1, row + 1)
        ]

        if length(Enum.uniq(block)) == 1, do: acc + 3, else: acc
    end
  end

  defp rule3(lines) do
    patterns = [
      [true, false, true, true, true, false, true, false, false, false, false],
      [false, false, false, false, true, false, true, true, true, false, true]
    ]

    Enum.reduce(lines, 0, fn line, total ->
      windows =
        line
        |> Enum.chunk_every(11, 1, :discard)
        |> Enum.count(&(&1 in patterns))

      total + windows * 40
    end)
  end

  defp rule4(modules, size) do
    dark = Enum.count(List.flatten(modules), &(&1 == true))
    percentage = dark * 100 / (size * size)
    trunc(abs(percentage - 50) / 5) * 10
  end

  defp transpose(modules, size) do
    for column <- 0..(size - 1) do
      for row <- 0..(size - 1), do: module_at(modules, column, row)
    end
  end

  # --- SVG ------------------------------------------------------------------

  defp to_svg(%{modules: modules, size: size}, opts) do
    quiet = 4
    total = size + quiet * 2
    aria_label = Keyword.get(opts, :aria_label, "QR code")
    size_attr = Keyword.get(opts, :size)

    dimensions =
      case size_attr do
        nil -> ~s(width="100%" height="100%")
        pixels -> ~s(width="#{pixels}" height="#{pixels}")
      end

    paths =
      modules
      |> Enum.with_index()
      |> Enum.map_join(fn {row, y} ->
        row
        |> runs()
        |> Enum.map_join(fn {start, length} ->
          ~s(M #{start + quiet},#{y + quiet} h #{length} v 1 h -#{length} z )
        end)
      end)

    """
    <svg xmlns="http://www.w3.org/2000/svg" #{dimensions} viewBox="0 0 #{total} #{total}" role="img" aria-label="#{aria_label}" shape-rendering="crispEdges">
      <rect width="#{total}" height="#{total}" fill="#ffffff"/>
      <path d="#{String.trim(paths)}" fill="#000000"/>
    </svg>
    """
  end

  defp runs(row) do
    row
    |> Enum.with_index()
    |> Enum.reduce({[], nil, 0}, fn {dark?, index}, {runs, start, length} ->
      cond do
        dark? and start == nil ->
          {runs, index, 1}

        dark? ->
          {runs, start, length + 1}

        start != nil ->
          {[{start, length} | runs], nil, 0}

        true ->
          {runs, nil, 0}
      end
    end)
    |> then(fn {runs, start, length} ->
      if start == nil, do: Enum.reverse(runs), else: Enum.reverse([{start, length} | runs])
    end)
  end
end
