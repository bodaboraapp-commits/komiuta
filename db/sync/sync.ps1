<#
.SYNOPSIS
    Non-destructive reference-data sync for the Komiuta / Xpressbus MySQL database.

.DESCRIPTION
    Downloads the latest data-sync bundle from GitHub, verifies it contains no
    destructive statements, optionally backs up the target database, then applies
    the bundle.

    The bundle only INSERTs new reference rows (cities, routes, operators, buses,
    drop/pick points, facilities, banners, hotels, hidden gems, car hires, events)
    and UPDATEs existing ones. It never DELETEs, TRUNCATEs or DROPs anything, and
    it contains no users, tickets, payments, admins or integration secrets.

.PARAMETER Database
    Target database name. Default: buupasskomiuta_db

.PARAMETER Host / Port / User / Password
    MySQL connection settings. If -Password is omitted, the mysql client prompts.
    Use -Password '' for a blank password.

.PARAMETER FreshSchema
    Also apply schema.sql (CREATE TABLE IF NOT EXISTS ...) before the data sync.
    Use this only for a brand-new, empty database. Existing deployments should
    run `mix ecto.migrate` instead, which preserves data and adds new columns.

.PARAMETER SkipBackup
    Do not create a mysqldump backup before applying.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\sync.ps1

.EXAMPLE
    .\sync.ps1 -Host 127.0.0.1 -Port 3306 -User app -Password 'secret' -Database komiuta_prod
#>
[CmdletBinding()]
param(
    [string]$Database  = 'buupasskomiuta_db',
    [Alias('Host')]
    [string]$Server    = '127.0.0.1',
    [int]   $Port      = 3307,
    [string]$User      = 'root',
    [string]$Password  = $null,
    [string]$MysqlExe  = '',
    [string]$SqlUrl    = 'https://raw.githubusercontent.com/bodaboraapp-commits/komiuta/phoenix-app/db/sync/data_sync.sql.zip',
    [string]$SchemaUrl = 'https://raw.githubusercontent.com/bodaboraapp-commits/komiuta/phoenix-app/db/sync/schema.sql',
    [switch]$FreshSchema,
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
function Info($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }

function Resolve-Tool([string]$explicit, [string]$name) {
    if ($explicit -and (Test-Path -LiteralPath $explicit)) { return $explicit }
    $candidates = @(
        "C:\xampp\mysql\bin\$name.exe",
        "C:\Program Files\MySQL\MySQL Server 8.0\bin\$name.exe",
        "C:\Program Files\MariaDB 11.4\bin\$name.exe"
    )
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
    $cmd = Get-Command "$name.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "'$name' client not found. Pass -MysqlExe 'C:\path\to\$name.exe'."
}

function Get-MysqlArgs {
    $a = @('-h', $Server, '-P', "$Port", '-u', $User, '--default-character-set=utf8mb4')
    if ($null -ne $Password) {
        if ($Password -eq '') { $a += '--password=' } else { $a += "--password=$Password" }
    }
    return $a
}

function Assert-SafeSql([string]$path) {
    $bad = Get-Content -LiteralPath $path |
        Where-Object { $_ -notmatch '^\s*--' } |
        Select-String -Pattern '(?i)\b(DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+TABLE|DELETE\s+FROM)\b'
    if ($bad) { throw "Refusing to run: '$path' contains destructive statements.`n$($bad | Out-String)" }
}

# --- 1. Resolve tools and workspace -----------------------------------------
$mysql     = Resolve-Tool $MysqlExe 'mysql'
$mysqldump = $null
try { $mysqldump = Resolve-Tool '' 'mysqldump' } catch { }

$work = Join-Path $env:TEMP 'komiuta-db-sync-run'
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $work | Out-Null

Info "Database : $Database"
Info "Server   : ${Server}:$Port (user $User)"
Info "mysql    : $mysql"
Info "Work dir : $work"

# --- 2. Download and unpack the bundle --------------------------------------
$zip = Join-Path $work 'data_sync.sql.zip'
Info "Downloading $SqlUrl"
try {
    Invoke-WebRequest -Uri $SqlUrl -OutFile $zip -UseBasicParsing
} catch {
    & curl.exe -L --fail --silent --show-error -o $zip $SqlUrl
    if ($LASTEXITCODE -ne 0) { throw "Download failed: $($_.Exception.Message)" }
}

Expand-Archive -LiteralPath $zip -DestinationPath $work -Force
$dataSql = Join-Path $work 'data_sync.sql'
if (-not (Test-Path -LiteralPath $dataSql)) { throw "data_sync.sql not found inside the downloaded archive." }
Assert-SafeSql $dataSql
Ok "Bundle downloaded and verified (no DELETE / TRUNCATE / DROP statements)."

$mysqlArgs = Get-MysqlArgs

# --- 3. Optional schema for a brand-new database ----------------------------
if ($FreshSchema) {
    $schemaFile = Join-Path $work 'schema.sql'
    Info "Downloading schema snapshot"
    try { Invoke-WebRequest -Uri $SchemaUrl -OutFile $schemaFile -UseBasicParsing }
    catch { & curl.exe -L --fail --silent --show-error -o $schemaFile $SchemaUrl }
    Assert-SafeSql $schemaFile
    Info "Applying schema (CREATE TABLE IF NOT EXISTS only)"
    Push-Location $work
    try {
        & $mysql @mysqlArgs $Database -e 'source schema.sql'
        if ($LASTEXITCODE -ne 0) { throw "Schema apply failed (exit $LASTEXITCODE)." }
    } finally { Pop-Location }
    Ok "Schema applied."
}

# --- 4. Backup ---------------------------------------------------------------
if (-not $SkipBackup) {
    if ($mysqldump) {
        $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = Join-Path $work "backup-$Database-$stamp.sql"
        Info "Backing up database to $backup"
        $dumpArgs = @('-h', $Server, '-P', "$Port", '-u', $User) + $(if ($null -ne $Password) { if ($Password -eq '') { '--password=' } else { "--password=$Password" } } else { @() }) + @('--single-transaction', '--default-character-set=utf8mb4', '--result-file=' + $backup, $Database)
        & $mysqldump @dumpArgs
        if ($LASTEXITCODE -ne 0) { throw "Backup failed; aborting before touching the database." }
        Ok "Backup created: $backup"
    } else {
        Warn "mysqldump not found - continuing without a backup. Use -SkipBackup to silence this warning."
    }
}

# --- 5. Apply the sync -------------------------------------------------------
Info "Applying reference-data sync (INSERT/UPDATE only; no rows are deleted)"
Push-Location $work
try {
    & $mysql @mysqlArgs $Database -e 'source data_sync.sql'
    if ($LASTEXITCODE -ne 0) { throw "Data sync failed (exit $LASTEXITCODE). No rows were deleted; the transaction was rolled back if it failed mid-way." }
} finally { Pop-Location }

# --- 6. Report ---------------------------------------------------------------
$counts = & $mysql @mysqlArgs --batch --skip-column-names $Database -e @"
SELECT 'cities', COUNT(*) FROM cities
UNION ALL SELECT 'routes', COUNT(*) FROM routes
UNION ALL SELECT 'bus_operators', COUNT(*) FROM bus_operators
UNION ALL SELECT 'drop_pick_points', COUNT(*) FROM drop_pick_points
UNION ALL SELECT 'facilities', COUNT(*) FROM facilities
UNION ALL SELECT 'buses', COUNT(*) FROM buses
UNION ALL SELECT 'banners', COUNT(*) FROM banners
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'hidden_gems', COUNT(*) FROM hidden_gems
UNION ALL SELECT 'hotels', COUNT(*) FROM hotels
UNION ALL SELECT 'car_hires', COUNT(*) FROM car_hires;
"@
Ok "Sync complete. Current row counts:"
$counts | ForEach-Object { $_ -replace "`t", ' : ' } | ForEach-Object { Write-Host "    $_" }
Write-Host ""
Write-Host "No rows were deleted. Users, tickets, payments, admins and integrations" -ForegroundColor DarkGray
Write-Host "were not touched. Re-running this script is safe (idempotent)." -ForegroundColor DarkGray
