# Module 0 — Setup and context

## What you are starting from

A working analytics project for **Merlin & Co. Apothecaries**, a fifteen-shop
potion retailer. It runs green on dbt Core today:

```
dbt build
Done. PASS=92 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=92
```

That is the whole point. You are not starting from a broken repo — you are
starting from a project your team could plausibly be running in production right
now, and you are going to walk it through the upgrade to dbt Core v2 (the engine
previously called Fusion).

## What's in the project

| Layer | Count | Notes |
|---|---|---|
| Seeds | 12 | Three source systems, roughly 100k rows total |
| Staging | 12 | One per source table, doing the conforming work |
| Intermediate | 3 | Ephemeral |
| Marts | 8 | Facts, dimensions, aggregates, one compliance table |
| Snapshot | 1 | Check strategy on guild memberships |
| Tests | 59 | Including one `dbt_utils` composite-key test |

Three source systems land as seeds:

- **grimoire_crm** — customers, guilds, guild memberships
- **abra_pos** — orders, order lines, payments, potion catalogue
- **alembic_ops** — shops, suppliers, ingredients, recipes, brew events

Everything upstream arrives as text, so the staging layer conforms casing, the
two timestamp formats, messy booleans, copper-to-gold conversion, and the region
coding. Referential integrity is intact — the messiness is in formats, not
broken joins.

## The upgrade path you'll follow

The upgrade assistant (`dbt init --fusion-upgrade`) walks three gates in order,
and this lab follows the same sequence:

```
  parse                      ->  is the project structurally valid?
  compile --static-analysis off      ->  does it render like dbt Core does?
  compile --static-analysis baseline ->  the compatibility landing zone
  compile --static-analysis strict   ->  the strongest SQL checks
```

Then run/build, then deferral and rollout.

## Static analysis modes

| Mode | What it does | Where it belongs |
|---|---|---|
| `off` | Renders Jinja to SQL, no semantic analysis. Mimics dbt Core. | Migration step only |
| `baseline` | Default. Findings are warnings. No remote schema downloads. | Deployment |
| `strict` | Strongest SQL checks, richest IDE features. | Development |

!!! important "Baseline and strict are not the same check at a lower volume"
    Baseline does not download remote source schemas, so it **cannot see
    column-level problems at all**. In Module 3 you will watch baseline report a
    clean project and strict report three real errors in the same code. Reaching
    baseline is not the same as being correct — it means you are not blocked.

## Ahead-of-time vs just-in-time

dbt Core compiles Jinja to SQL and hands it to the warehouse. Whether the SQL is
*valid* is the warehouse's problem, discovered at run time.

dbt Core v2 analyzes the SQL ahead of time — it resolves columns, types and
lineage before anything executes. You will see this concretely in Module 3:
three models that dbt Core's `compile` says nothing about, and that only fail
when you actually run them against Snowflake.

## Prerequisites

- dbt Core 1.10.x with an adapter, for the baseline runs
- dbt Core v2 installed (`dbt --version` reports `dbt-fusion 2.x`)
- `uvx` available, for `dbt-autofix`
- A warehouse connection you can build into

## Branches

| Branch | Contents |
|---|---|
| `main` | Core-green starting state. Begin here. |
| `solution/01-deprecations` | Parse gate cleared |
| `solution/03-baseline-strict` | Static-analysis findings fixed |
| `exercise/05-broken-deferral` | The deferral trap, pre-applied |

Modules 2 and 4 involve no code changes — they are command-line exploration, so
they have no solution branch.
