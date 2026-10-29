# Keeps a Render Free web service from spinning down (idle timeout: 15 minutes).
#
# Render spins a Free instance down after 15 minutes without inbound traffic.
# A request every ~10 minutes counts as inbound traffic and keeps it running,
# provided this script runs on a machine that is always on (this PC must stay
# powered on; otherwise use an external monitor - see DEPLOY_RENDER.md).
#
# The default path is "/" - the homepage reads cities/routes/operators from the
# database, so the ping also keeps a free managed MySQL (Aiven) from going idle.
# Use -Path /robots.txt for a cheaper ping that does not touch the database.
#
# CAVEATS
#   * Render designs Free instances for testing/previews, not production.
#   * An always-on Free service consumes ~744 of your 750 monthly free hours.
#   * Ping cannot prevent cold starts caused by deploys or restarts.
#   * For real customers, upgrade the Render web service to an always-on plan.
#
# USAGE
#   .\keepalive.ps1 -Url https://komiuta-xxxx.onrender.com
#   .\keepalive.ps1 -Url https://komiuta-xxxx.onrender.com -IntervalMinutes 10
#   .\keepalive.ps1 -Url https://komiuta-xxxx.onrender.com -Path /robots.txt -Once
#
# To run automatically, create a Scheduled Task (At logon) whose action is:
#   powershell -NoProfile -ExecutionPolicy Bypass -File C:\path\keepalive.ps1 -Url https://...

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [string]$Path = '/',

    [int]$IntervalMinutes = 10,

    [int]$TimeoutSeconds = 120,

    [switch]$Once
)

$ErrorActionPreference = 'Continue'
$base = $Url.TrimEnd('/')
$pingPath = '/' + $Path.TrimStart('/')

Write-Host "Komiuta keepalive -> $base$pingPath every $IntervalMinutes min" -ForegroundColor Cyan

while ($true) {
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $pingUrl = "$base$pingPath`?ts=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $pingUrl -UseBasicParsing -TimeoutSec $TimeoutSeconds
        $sw.Stop()
        Write-Host ("[{0}] HTTP {1} in {2:N1}s" -f $stamp, $response.StatusCode, $sw.Elapsed.TotalSeconds) -ForegroundColor Green
    } catch {
        Write-Host ("[{0}] ping failed: {1}" -f $stamp, $_.Exception.Message) -ForegroundColor Yellow
    }

    if ($Once) { break }
    Start-Sleep -Seconds ($IntervalMinutes * 60)
}
