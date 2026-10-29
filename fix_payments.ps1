# Fix STK push headers in payments.ex
$filePath = ".\xpressbus\lib\xpressbus\payments.ex"
$content = Get-Content $filePath -Raw

# Find the corrupted line and replace it
$lines = $content -split "`n"
$inStkPost = $false
$headersEnd = -1

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'case Req.post.*stkpush' -or $lines[$i] -match 'case Req.post.*processrequest') {
        $inStkPost = $true
    }
    if ($inStkPost -and $lines[$i] -match '^\s*\}\s*$') {
        # Check if this is the headers closing brace
        if ($i -gt 330 -and $lines[$i-1] -match 'Accept-Language') {
            $headersEnd = $i
            break
        }
    }
}

if ($headersEnd -ge 0) {
    # Check if receive_timeout line is missing or incorrect
    $nextLine = $lines[$headersEnd + 1]
    if ($nextLine -notmatch 'receive_timeout') {
        # Insert receive_timeout line
        $lines = $lines[0..$headersEnd] + @(
            '                   receive_timeout: 30_000',
            '                 ) do'
        ) + $lines[($headersEnd + 1)..($lines.Count - 1)]
    }
}

Set-Content -Path $filePath -Value ($lines -join "`n")
Write-Host "Fix applied successfully"