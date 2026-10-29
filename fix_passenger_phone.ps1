# Fix passenger_phone extraction in booking_live.ex
$file = ".\xpressbus\lib\xpressbus_web\live\booking_live.ex"
$lines = Get-Content $file

# Find the line numbers for the passenger_phone extraction
# It's around line 689-700
# We need to replace the extraction logic to also check payer_is_passenger

# First, let's find the exact lines
$start_line = 689
$end_line = 700

# Get the current block
$block = $lines[$start_line-1..$block_end-1]  # 0-indexed

# Create the new block with proper logic
$new_block = @"
    passenger_phone =
      if socket.assigns.payment_method == "mpesa" && socket.assigns.payer_is_passenger do
        passenger_phone =
          Map.get(socket.assigns.passenger_form.params, "passengers")
          |> Map.get(0)
          |> Map.get("phone")
      end
      passenger_phone =
        Map.get(passenger_form_params, "payment_phone") ||
        Map.get(passenger_form_params, :payment_phone) ||
        ""
"@

# Replace the block in the lines array
# Remove old block
$lines = $lines[0..$start_line-2] + $lines[$block_end..$lines.Count-1]

# Insert new block at the right position
$new_lines = @()
$lines_new = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    $lines_new += $lines[$i]
    if ($i -eq $block_start-2) {
        # Insert after this line
        $lines_new += $new_block -split "`n"
    }
}

Set-Content -Path $file -Value ($lines_new -join "`n")
Write-Host "Fix applied successfully"