# Module 4 — Run, build, and state

**Gate:** the project actually materializes, and state-based selection behaves.

No code changes in this module.

## Build the whole project on dbt Core v2

```bash
dbt build
```

```
Finished 'build' successfully for target 'dev' [26.4s]
Processed: 23 models | 59 tests | 1 snapshot | 12 seeds
Summary: 95 total | 92 success | 3 no-op
```

The same build on dbt Core takes roughly 90 seconds. Note also that static
analysis applies to tests, seeds and snapshots — not just models.

## Custom materializations

`fct_regulated_potion_sales` uses a house materialization, `audit_table`, which
builds the relation and then stamps a row into a build ledger for Compliance:

```bash
dbt build --select fct_regulated_potion_sales
```

```
Succeeded [  1.63s] model dbt_trouze.fct_regulated_potion_sales (audit_table)
```

It works on both engines. It carries `+static_analysis: 'off'`, which — as you
found in Module 3 — is not actually required here. Worth flagging in your own
project: inherited opt-outs are worth re-testing rather than assuming.

## Dynamic materialization

`fct_orders_backfill` picks its materialization from a variable:

```jinja
{% set run_mode = var('PIPELINE_RUN_MODE', 'standard') %}

{{ config(materialized = 'ephemeral' if run_mode == 'backfill' else 'table') }}
```

Under the default `standard` it is a table. Under `backfill` it becomes
ephemeral, and `agg_revenue_by_region` — which refs it — inlines it as a CTE
instead of reading a table. The shape of the graph changes based on a variable.

```bash
dbt build --vars 'PIPELINE_RUN_MODE: backfill' --select fct_orders_backfill+
```

```
Succeeded [  2.06s] model dbt_trouze.agg_revenue_by_region (table)
Finished 'build' successfully for target 'dev'
```

!!! note "This one works, and it is still a liability"
    Guidance you may have read describes conditional-ephemeral materialization
    breaking the upgrade. On `dbt-fusion 2.0.0-preview.218` it compiles and
    builds cleanly in both engines.

    The reason to fix it anyway is that dbt Core v2 builds a stable logical plan
    ahead of time, and this model has two different plans depending on an
    environment variable. Anything that reasons about your graph — state
    comparison, deferral, column lineage, the IDE — is reasoning about whichever
    plan it happened to be handed. Two materializations behind one name is
    ambiguity you are choosing to keep.

## State comparison

Save a dbt Core manifest as your production artifact, then ask dbt Core v2 what
changed:

```bash
dbt parse --no-partial-parse          # dbt Core
mkdir -p state && cp target/manifest.json state/manifest.json

dbt list --select state:modified --state state      # dbt Core v2
```

With identical code, nothing is reported. Now touch a model and re-run:

```
merlinco_apothecaries.marts.dim_potions
merlinco_apothecaries.marts.not_null_dim_potions_potion_sku
merlinco_apothecaries.marts.unique_dim_potions_potion_sku
```

dbt Core reports exactly the same three nodes. Cross-engine state comparison
agrees on models — no spurious modifications.

## Takeaways

- Static analysis covers tests, seeds and snapshots, not just models.
- Custom materializations work; re-test inherited `static_analysis` opt-outs.
- Dynamic materialization builds fine and is still worth removing — one name
  should mean one plan.
- Cross-engine state comparison agrees on models.
