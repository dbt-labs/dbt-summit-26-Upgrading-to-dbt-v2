# Upgrading to dbt Core v2 — training lab

A hands-on lab for upgrading a real analytics project from dbt Core to **dbt
Core v2** (the engine previously called Fusion).

The project is **Merlin & Co. Apothecaries**, a fifteen-shop potion retailer. It
runs green on dbt Core before you touch anything:

```
dbt build
Done. PASS=94 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=94
```

That matters. You are not starting from a broken repo — you are starting from a
project a team could plausibly be running in production today, and you will walk
it through the upgrade gate by gate, the same way the upgrade assistant does.

## The lab

| Module | Gate | Code changes |
|---|---|---|
| [0 — Setup and context](docs/lab/00-setup.md) | — | — |
| [1 — Parse and deprecations](docs/lab/01-parse-and-deprecations.md) | `dbt parse` | yes |
| [1b — Macro argument types](docs/lab/01b-macro-argument-types.md) | `dbt parse` warnings | yes |
| [1c — Silently ignored config](docs/lab/01c-silently-ignored-config.md) | `dbt parse` | yes |
| [2 — Compile with analysis off](docs/lab/02-compile-static-analysis-off.md) | `--static-analysis off` | no |
| [3 — Baseline and strict](docs/lab/03-baseline-and-strict.md) | `baseline` / `strict` | yes |
| [3b — Dynamic SQL and introspection](docs/lab/03b-dynamic-sql-and-introspection.md) | `strict`, `--no-introspect` | yes |
| [4 — Run, build, and state](docs/lab/04-run-build-and-state.md) | `dbt build`, `state:` | no |
| [5 — Deferral and rollout](docs/lab/05-deferral-and-rollout.md) | manifests, deferral | yes |

Instructors: see [instructor notes](docs/instructor-notes.md) for the verified
behavior matrix, timings, and the findings that field guidance predicts but that
do **not** reproduce on the current build.

## What breaks, and when

Every fixture in this project passes on dbt Core. Each one surfaces at exactly
one gate:

- **Parse** — 14 errors from deprecated YAML and config shapes that dbt Core
  only warns about, plus **19** macro type-annotation warnings Autofix will not
  touch. Matching a real ticket, they span four warehouse types, so the obvious
  blanket replace clears only 14 of them.
- **Silently dropped config** — a `materialised` typo that makes a model
  materialize as a table when the code says view, and a `unique_keys` typo that
  costs an incremental model its merge key and appends one duplicate row per
  night. dbt Core discards both keys without a word and reports `PASS`. Autofix
  "fixes" them by moving them to `meta`, which turns the gate green and leaves
  the corruption running.
- **Strict** — three quarantined models carrying a column typo, two ambiguous
  column references, and a missing `group by` column. dbt Core's `compile` says
  nothing about any of them; `dbt run` finds them only by asking Snowflake.
  Plus a dynamic `PIVOT ... IN (ANY)` that baseline passes and strict rejects.
- **Introspection** — a macro that queries the warehouse at compile time. Clean
  in all three analysis modes, and fatal under `--no-introspect` in all three,
  including `off`. An incremental model trips the same flag legitimately, so the
  module also teaches which introspection is worth removing and which is not.
- **Deferral** — `static_analysis: off` without quotes, which YAML turns into
  the boolean `False`. Silent locally, fatal for anything deferring to the
  manifest.

The headline comparison, on identical code:

| | Result |
|---|---|
| dbt Core `compile` | silent |
| dbt Core `run` | 3 Database Errors |
| v2 `compile --static-analysis off` | 99/99 success |
| v2 `compile --static-analysis baseline` | 99/99 success |
| v2 `compile --static-analysis strict` | 4 errors, no warehouse execution |

Note the third row. **Baseline finds none of them** — it does not download
remote schemas, so it cannot see column-level defects. Reaching baseline clean
means you are not blocked, not that you are correct. Strict in development,
baseline in deployment.

## Getting started

```bash
git clone <this repo> && cd dbt-summit-26-Upgrading-to-dbt-v2
cp profiles.yml.example profiles.yml     # then fill in your connection

dbt deps
dbt seed        # ~90s on dbt Core
dbt build       # expect PASS=94 ERROR=0
```

Then open [Module 0](docs/lab/00-setup.md).

## Branches

| Branch | State |
|---|---|
| `main` | Core-green starting state — begin here |
| `solution/01-deprecations` | v2 parse clean, all 19 annotations fixed |
| `solution/03-baseline-strict` | column-level findings fixed |
| `solution/03b-dynamic-sql` | strict 102/102, dynamic SQL removed |
| `exercise/05-broken-deferral` | the deferral trap, pre-applied |

## Project layout

```
seeds/            12 seeds across 3 source systems (~100k rows)
  grimoire_crm/     customers, guilds, guild memberships
  abra_pos/         orders, order items, payments, potions
  alembic_ops/      shops, suppliers, ingredients, recipes, brew events
models/
  staging/        12 models, one per source table
  intermediate/    3 ephemeral models
  marts/           facts, dimensions, aggregates
    compliance/     custom `audit_table` materialization
    quarantine/     switched-off models with latent defects (Module 3)
macros/           conforming macros, one introspective macro, one materialization
  utils/            internal helper library (19 macro args, wrongly annotated)
snapshots/         1 check-strategy snapshot
```

## Data

Seeds come from
[dbt-labs/merlinco-apothecaries](https://github.com/dbt-labs/merlinco-apothecaries)
(`medium_data` tier). Referential integrity is intact — the deliberate messiness
is in formats and casing, which is what the staging layer is for: mixed-case
categoricals, two timestamp formats, four spellings per region, messy booleans,
and copper-piece prices that report in gold crowns.
