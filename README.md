# usgs-pipeline

Daily ELT pipeline for earthquake data: a Python script pulls events from the
USGS/FDSN earthquake catalog and appends them to BigQuery, dbt handles
deduplication and incremental merge on top.

## Why this project exists

Most "incremental" portfolio pipelines run once against a static historical
dataset. This one runs daily against a live feed where the same record can
legitimately change after the fact (USGS revises magnitude and location for
days, sometimes weeks, after an event). That forces the project to deal with
late-arriving updates for real, not as a theoretical exercise.

## Architecture

```bash
GitHub Actions (daily cron)
        |
        v
scripts/fetch_earthquakes.py  --(FDSN API, magnitude >= 3.0)-->  raw_earthquakes (BigQuery)
        |
        v
dbt:
  stg_usgs__earthquakes        casts raw JSON fields to proper types
        |
        v
  int_usgs__earthquakes_current   dedupes by event_id (latest ingested_at wins),
                                   incremental merge, watermark-based filtering
```

The raw layer does one job only: fetch and append, no business logic. All
deduplication and "what is the current truth for this event_id" logic lives
in dbt. This mirrors how most production ELT stacks split ingestion from
transformation (e.g. Fivetran/Airbyte + dbt).

## What the fetch script does

`scripts/fetch_earthquakes.py` queries the USGS FDSN event API
(`https://earthquake.usgs.gov/fdsnws/event/1/query`) for events with
`magnitude >= 3.0`, currently using a rolling `starttime` window of the last
~24 hours, and appends every row it gets to `raw_earthquakes` via a BigQuery
load job (not DML, so this works even before billing is fully configured).

Each row carries:

- `event_id`: the USGS catalog ID (natural unique key, no need to invent one)
- `event_time`: when the earthquake occurred
- `updated_at`: when USGS last touched this record (their own revision clock)
- `ingested_at`: when *this script* wrote the row, independent of the two above
- `raw_json`: the full original feature, kept as a safety net

## What dbt does

- `stg_usgs__earthquakes`: casts the raw columns, no logic beyond typing.
- `int_usgs__earthquakes_current`: incremental model, `unique_key='event_id'`,
  `incremental_strategy='merge'`. Deduplicates by keeping the row with the
  highest `ingested_at` per `event_id`, then merges into a persistent table.
  Filters only the new batch since the last run, using a watermark fetched
  via `run_query()` and inlined as a literal, because BigQuery will not
  prune partitions on a subquery, only on a literal value in the WHERE
  clause.

## Known limitation (accepted, not yet fixed)

The current fetch window (`starttime`-based, ~24h) only catches a revision
if the event is still inside that window when USGS updates it. If USGS
revises an event after it has aged out of the rolling window, this pipeline
will never see that revision, full dbt refresh will not fix it either,
since a refresh only reprocesses what is already in BigQuery, it does not
re-query USGS.

This is a deliberate v1 simplification, not an oversight. The fix (querying
FDSN with `updatedafter=<last_known_updated_at>` instead of `starttime`,
using a watermark read from BigQuery itself) is the planned next iteration,
see Roadmap.

## Setup

1. Enable billing on the GCP project. This is required: dbt's `merge`
   strategy issues DML statements, and BigQuery Sandbox (no billing account
   linked) blocks all DML and auto-expires every table after 60 days.
   Enabling billing does not mean you will be charged, the same free tier
   (10GB storage / 1TB query per month) still applies. Set a budget alert
   as a safety net.
2. Create the dataset, then run `sql/create_raw_table.sql` once (edit the
   project/dataset placeholders first).
3. Create a GCP service account with `BigQuery Data Editor` and
   `BigQuery Job User` roles on the project, download its JSON key.
4. Add these repo secrets (Settings -> Secrets and variables -> Actions):
   - `GCP_SA_KEY_B64`: base64 of the service account JSON
     (`base64 -w 0 service-account.json`, or on PowerShell:
     `[Convert]::ToBase64String([IO.File]::ReadAllBytes("service-account.json"))`)
   - `BQ_PROJECT`, `BQ_DATASET`
5. Push. The workflow runs daily; trigger it manually from the Actions tab
   (`workflow_dispatch`) to test without waiting for the cron.
6. Run `dbt run` locally (or wire it into CI, see Roadmap) after the first
   successful fetch.

## Repo structure

```
usgs-pipeline/
  .github/workflows/daily_fetch.yml
  scripts/fetch_earthquakes.py
  requirements.txt
  sql/create_raw_table.sql
  models/
    staging/stg_usgs__earthquakes.sql
    intermediate/int_usgs__earthquakes_current.sql
```

## Roadmap

- Switch the fetch from `starttime` to `updatedafter`, with the watermark
  read from `max(updated_at)` in BigQuery, removing the known limitation
  above and the daily re-ingestion of unchanged events from window overlap.
- Wire `dbt run` into the same GitHub Actions workflow, currently it's a
  manual step.
- Mart layer on top of the current model: geolocation for mapping,
  average magnitude over time, delay between `event_time` and `updated_at`,
  distribution of `automatic` vs `reviewed` status.
