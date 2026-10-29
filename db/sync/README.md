# Komiuta / Xpressbus database sync

Non-destructive **reference-data** sync for the MySQL/MariaDB database used by the
Komiuta (Xpressbus) Phoenix app.

It applies the latest catalogue data (buses, routes, operators, cities, pickup
points, facilities and travel-content tables) **without deleting any existing
records**. Running it repeatedly is safe and idempotent.

---

## Quick start (admin)

Run this in PowerShell on the machine that hosts the database:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr 'https://raw.githubusercontent.com/bodaboraapp-commits/komiuta/phoenix-app/db/sync/sync.ps1' -UseBasicParsing -OutFile $env:TEMP\komiuta-sync.ps1; & $env:TEMP\komiuta-sync.ps1 -Database buupasskomiuta_db -Host 127.0.0.1 -Port 3307 -User root"
```

The script will:

1. download the signed-off bundle from this repository,
2. verify it contains **no** `DELETE`, `TRUNCATE` or `DROP` statements,
3. take a full `mysqldump` backup (unless `-SkipBackup`),
4. apply the upserts in one transaction,
5. print the resulting row counts.

If the mysql client is not on `PATH`, pass its full path with
`-MysqlExe 'C:\xampp\mysql\bin\mysql.exe'`.
If `-Password` is omitted, the mysql client prompts for it; use `-Password ''`
for a blank password.

### Useful flags

| Flag | Meaning |
|---|---|
| `-Database` | Target schema (default `buupasskomiuta_db`) |
| `-Host` / `-Port` / `-User` / `-Password` | Connection settings |
| `-MysqlExe` | Full path to `mysql.exe` |
| `-FreshSchema` | Also apply `schema.sql` (`CREATE TABLE IF NOT EXISTS`) — **only for an empty database** |
| `-SkipBackup` | Skip the automatic `mysqldump` backup |
| `-SqlUrl` / `-SchemaUrl` | Override download locations (e.g. a local copy) |

---

## What is synced

| Table | Key used for matching | Behaviour |
|---|---|---|
| `cities` | `name` (unique) | insert or update |
| `routes` | `origin` + `destination` (unique) | insert or update |
| `bus_operators` | `name` (unique) | insert or update (name/logo/active only) |
| `drop_pick_points` | `name` (unique) | insert or update |
| `facilities` | `name` (unique) | insert or update |
| `buses` | `company`+`departure`+`from`+`to`+`travel_date` (unique) | insert or update |
| `banners` | `image` | insert if missing, update |
| `events` | `title` + `date` | insert if missing, update |
| `hidden_gems` | `title` | insert if missing, update |
| `hotels` | `name` | insert if missing, update |
| `car_hires` | `car_name` | insert if missing, update |

### Deliberately **excluded** (personal / secret / transactional data)

`users`, `tickets`, `payments`, `transactions`, `subscribers`, `admins`,
`integrations`, `coupons`.

Bus-operator `contact_person`, `phone` and `email` are not synced either — the
script never publishes or overwrites personal contact details.

> Because of these exclusions this bundle is safe to keep in the public
> repository. Do **not** replace it with a raw `mysqldump` of the full database:
> that would expose customer PII and payment/OAuth secrets.

### Foreign keys

`buses.bus_operator_id` and the `*_city_id` columns are intentionally not
overwritten, so a sync cannot point rows at the wrong operator/city when the
target database has different surrogate IDs. Existing relationships in the
target database are left exactly as they are.

---

## Safety guarantees

* The generated SQL contains only `INSERT … ON DUPLICATE KEY UPDATE` and
  `INSERT … SELECT … WHERE NOT EXISTS` + `UPDATE` statements.
* A safety scan in `sync.ps1` aborts if the bundle contains `DELETE FROM`,
  `TRUNCATE TABLE`, `DROP TABLE` or `DROP DATABASE` (ignoring comments).
* All statements run inside `START TRANSACTION` / `COMMIT`.
* A full backup is taken before applying unless `-SkipBackup` is used.
* Re-running the same bundle produces identical row counts (tested in CI-style
  scratch databases).

Restore a backup if ever needed:

```powershell
& 'C:\xampp\mysql\bin\mysql.exe' -h 127.0.0.1 -P 3307 -u root -p buupasskomiuta_db -e "source C:/path/to/backup-....sql"
```

---

## Schema changes are separate

Data sync does **not** alter existing tables. Schema upgrades come from the
application's Ecto migrations (additive, non-destructive):

```powershell
mix ecto.migrate
```

`schema.sql` in this folder is a structure-only snapshot (`CREATE TABLE IF NOT
EXISTS`, no data) for bootstrapping a brand-new database. Do not apply it to an
existing installation — use migrations there.

---

## Bundle contents

| File | Purpose |
|---|---|
| `sync.ps1` | Admin runner (download → verify → backup → apply → report) |
| `data_sync.sql.zip` | Compressed, non-destructive upsert bundle |
| `schema.sql` | `CREATE TABLE IF NOT EXISTS` snapshot for empty databases only |

The bundle is generated from the local `buupasskomiuta_db` database. Its
`buses` rows are a point-in-time snapshot — if schedules look stale, refresh the
source data in the app (`mix buupass.pull` or let
`Xpressbus.Bookings.SyncServer` run) and regenerate the bundle.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ERROR 1045 (28000): Access denied` | Pass the correct `-User` / `-Password` |
| `'mysql' client not found` | Pass `-MysqlExe 'C:\xampp\mysql\bin\mysql.exe'` |
| Download blocked by proxy | Download `data_sync.sql.zip` manually and pass `-SqlUrl 'C:\path\data_sync.sql.zip'` |
| `Unknown database` | Create it first, or use `-FreshSchema` for an empty install |
| Accented/special characters garbled | The bundle is UTF-8; both script and client use `utf8mb4` — check the column charset |

---

## Regenerating the bundle (maintainers)

1. Update the local database (e.g. `mix buupass.pull`).
2. Generate a fresh bundle with the generator script kept in the development
   workspace (`scratch/gen_db_sync.ps1`), which produces `data_sync.sql` (plus
   `.zip`) and `schema.sql`.
3. Replace the files here, commit and push.

The generator only ever emits the tables listed above, excludes PII/secret
tables by design, and fails its own build if a destructive keyword appears.
