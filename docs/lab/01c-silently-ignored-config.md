# Module 1c — Silently ignored config

**Gate:** `dbt parse`.

This module has the most important lesson in the lab, and it is not the one you
expect. Do not skip to the fix.

## The setup

`models/marts/dim_potions.sql` opens like this:

```jinja
{#
  Small dimension -- 120 potions -- so this is a view rather than a table. No
  point paying for storage and a rebuild on something this size.
#}

{{
    config(
        materialised = 'view'
    )
}}
```

British spelling. dbt Core does not recognise `materialised` as a config key, so
it **drops it silently** and falls back to the project default:

```yaml
    marts:
      +materialized: table
```

Run it and watch dbt Core describe what it is doing:

```bash
dbt run --select dim_potions
```

```
1 of 1 OK created sql table model ... dim_potions
Finished running 1 table model in 5.06s
Done. PASS=1 WARN=0 ERROR=0
```

"1 **table** model." The author asked for a view. Nothing warned anybody. Check
the warehouse:

```sql
select table_name, table_type
from information_schema.tables
where table_schema = 'YOUR_SCHEMA' and table_name = 'DIM_POTIONS';
```

```
DIM_POTIONS  |  BASE TABLE
```

This is the class of bug where someone says *"why is this stale?"* or *"why is
this costing us so much?"* and nobody can see why, because the code says view
and the warehouse says table.

## Now the one that corrupts data

`fct_payment_events` is an incremental model:

```jinja
{{
    config(
        materialized = 'incremental',
        unique_keys = 'payment_id',
        incremental_strategy = 'merge'
    )
}}
...
{% if is_incremental() %}
where paid_at >= (select max(paid_at) from {{ this }})
{% endif %}
```

`unique_keys`, plural. The window uses `>=` on purpose — a payment can land with
a `paid_at` slightly behind the previous high-water mark, so the boundary period
gets re-read every run. `unique_key` is what makes that safe: the merge matches
on it and updates rather than inserts.

With the key silently dropped, there is nothing to match on, so the merge
appends. Watch it happen:

```bash
dbt run --select fct_payment_events --full-refresh
dbt run --select fct_payment_events
dbt run --select fct_payment_events
```

After each run:

```sql
select count(*) as total_rows,
       count(distinct payment_id) as distinct_ids,
       count(*) - count(distinct payment_id) as duplicates
from {{ your_schema }}.fct_payment_events;
```

```
full refresh      17156 |  17156 |  0
incremental run   17157 |  17156 |  1
incremental run   17158 |  17156 |  2
```

One more duplicate every single night, forever. **dbt Core reports `PASS` every
time.**

!!! note "Why no test caught it"
    There is no `unique` test on `fct_payment_events.payment_id`. That is
    deliberate, and it is the realistic part — the absence of the test is *why*
    nobody noticed. Adding one belongs in the fix, not just the config change.

## What Core v2 says

```bash
dbt parse
```

```
[error] [UnusedConfigKey (dbt1060)]: Ignored unexpected key `"materialised"`.
  YAML path: `materialised`.
[error] [UnusedConfigKey (dbt1060)]: Ignored unexpected key `"unique_keys"`.
  YAML path: `unique_keys`.
```

Both, at parse, before anything runs. It is not clever analysis — it is simply
refusing to ignore a key it does not recognise.

The class is wider than these two. Probing a config block with five plausible
typos, Core v2 flags all of them and dbt Core flags none:

| Typo'd key | dbt Core | Core v2 |
|---|---|---|
| `materialised` | silent | `dbt1060` |
| `unique_keys` | silent | `dbt1060` |
| `incremental_strategey` | silent | `dbt1060` |
| `on_schema_changed` | silent | `dbt1060` |
| `tag` (for `tags`) | silent | `dbt1060` |

## Do not let Autofix near this

Here is the lesson. Run the dry run:

```bash
uvx dbt-autofix@latest deprecations --dry-run
```

```
    Moved custom config ['materialised'] to 'meta'
    Moved custom config ['unique_keys'] to 'meta'
```

Autofix cannot tell a typo from a deliberate custom key, so it assumes you meant
it and relocates it to `+meta`, which is where arbitrary keys legally live:

```jinja
{{ config(
    meta={'materialised': 'view'}
) }}
```

```jinja
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    meta={'unique_keys': 'payment_id'}
) }}
```

Apply it and check:

```bash
dbt parse
Finished 'parse' with 19 warnings for target 'dev'
```

**Zero errors.** The gate is green.

Now run the model again:

```
incremental run   17157 |  17156 |  1
```

The bug is untouched. `dim_potions` is still a table. The incremental still has
no unique key. Autofix did exactly what it was designed to do, the parse gate
went green, and **the data is still being corrupted every night** — except now
the typo sits under `meta`, where it looks deliberate, so nobody will ever
question it again.

!!! danger "A clean Autofix run is not a clean project"
    This is the strongest reason to read `--dry-run` output line by line rather
    than piping Autofix into a commit. Anything described as "moved custom
    config X to meta" is Autofix telling you it does not know what X is. That is
    a question for you, not a fix.

    The July 2026 Autofix regression that mis-classified package versions is the
    famous example, but this is the everyday one.

## The actual fix

Spell the keys correctly:

```jinja
{{ config(materialized = 'view') }}
```

```jinja
{{
    config(
        materialized = 'incremental',
        unique_key = 'payment_id',
        incremental_strategy = 'merge'
    )
}}
```

Then add the test whose absence let this run for months:

```yaml
  - name: fct_payment_events
    columns:
      - name: payment_id
        tests:
          - unique
          - not_null
```

!!! warning "Fixing the config does not fix the data"
    The duplicates already in the table stay there. `unique_key` only governs
    future merges, and the new `unique` test will now fail against the mess the
    typo already made:

    ```bash
    dbt build --select fct_payment_events                  # test FAILS
    dbt build --select fct_payment_events --full-refresh   # clean
    ```

    Budget a full refresh as part of the remediation. This is generally true of
    silent-config bugs: by the time you find one, you own a backfill as well as
    a code change.

Verify:

```bash
dbt parse                                             # Core v2, clean
dbt run --select dim_potions                          # "1 view model"
dbt run --select fct_payment_events                   # idempotent now
```

```
fixed, after 2 incremental runs   17156 |  17156 |  0
```

## Takeaways

- dbt Core silently drops config keys it does not recognise. Intent and reality
  diverge with no signal at all.
- Consequences run from "wrong object type and a surprising bill" to "one
  duplicate row per night, forever, reported as PASS".
- Core v2 catches the whole class at parse with `dbt1060`.
- **Autofix will move a typo'd key to `meta`**, turning the error green while
  leaving the bug in place and making it look intentional. Read the dry run.
- Fix the key, add the test whose absence hid it, and plan the backfill.

**Solution branch:** `solution/01-deprecations`
