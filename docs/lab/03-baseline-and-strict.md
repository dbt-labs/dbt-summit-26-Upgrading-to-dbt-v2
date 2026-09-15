# Module 3 — Baseline and strict

**Gate:** static analysis. This is where dbt Core v2 earns its keep.

## Run baseline

Baseline is the default and the documented compatibility landing zone:

```bash
dbt compile --static-analysis baseline
```

```
Finished 'compile' successfully for target 'dev' [3.2s]
Processed: 25 models | 61 tests | 1 snapshot | 12 seeds
Summary: 99 total | 99 success
```

Clean. If you stopped here you would conclude the project is in good shape.

## Run strict

```bash
dbt compile --static-analysis strict
```

```
[error] [InvalidPivot (dbt0432)]: Dynamic PIVOT with ANY is not supported by
  dbt static analysis.
  --> models/marts/agg_payment_method_mix.sql:...
Finished 'compile' with 1 error for target 'dev'
```

One finding, on a model that baseline passed a moment ago. Set it aside — it is
a dynamic-SQL problem and it gets its own module,
[3b](03b-dynamic-sql-and-introspection.md). The rest of the nightly job is
sound.

## Now look at what is not in the graph

Open any of the three quarantined models — `fct_brew_yield`,
`dim_supplier_scorecard`, `agg_shop_channel_mix` — and you will find the same
shape at the top:

```jinja
{{
    config(
        enabled = var('include_quarantined', false),
        tags = ['quarantined']
    )
}}
```

Three models at the marts root were switched off during past incidents and
never revisited. Every real project has some. Nobody knows what state they are
in, because nothing has compiled them in months.

Bring them back:

```bash
dbt compile --static-analysis strict --vars 'include_quarantined: true'
```

```
[error] [UnresolvedIdentifier (dbt0227)]: Ambiguous column 'POTION_SKU' found.
  Available are BREW_EVENTS.POTION_SKU, POTIONS.POTION_SKU, POTIONS.POTION_NAME,
  POTIONS.POTENCY, BREW_EVENTS.BATCH_SIZE, BREW_EVENTS.SHOP_ID,
  BREW_EVENTS.BREW_ID ..(and 11 more)
  --> models/marts/fct_brew_yield.sql:19:5

[error] [UnresolvedIdentifier (dbt0227)]: No column SUPPLIERS.CONTRACT_START_DATE
  found. Available are SUPPLIERS.CONTRACTED_SINCE, INGREDIENTS.INGREDIENT_NAME,
  INGREDIENTS.UNIT_COST_GOLD, INGREDIENTS.HARVEST_SEASON, ..(and 6 more)
  --> models/marts/dim_supplier_scorecard.sql:25:5

[error] [SyntaxInvalid (dbt0101)]: no viable alternative at input 'courier_owl
  as ( select orders.shop_region, date_trunc('month', orders.ordered_at) as
  order_month, sum(item_totals.gross_amount_gold as'
  --> models/marts/agg_shop_channel_mix.sql:51:43

[error] [InvalidPivot (dbt0432)]: Dynamic PIVOT with ANY is not supported by
  dbt static analysis.
  --> models/marts/agg_payment_method_mix.sql:30:36

Finished 'compile' with 4 errors for target 'dev'
```

Four findings. Three of them are the quarantined models, each with a file, a
line, and — where the analyzer can offer one — the list of columns that *were*
available. The fourth is the pivot from a moment ago; it was already there,
unrelated to quarantine, and it stays parked for [Module 3b](03b-dynamic-sql-and-introspection.md).

Each of the three quarantined models is hiding a **second** defect behind the
one shown above — the analyzer cannot report a problem it has not reached yet.
[Fix them](#fix-them) below to see what surfaces.

## What baseline actually catches

Run the same quarantine reveal at baseline instead of strict:

```bash
dbt compile --static-analysis baseline --vars 'include_quarantined: true'
```

```
[warning] [SyntaxInvalid (dbt0101)]: no viable alternative at input 'courier_owl
  as ( select orders.shop_region, date_trunc('month', orders.ordered_at) as
  order_month, sum(item_totals.gross_amount_gold as'
  --> models/marts/agg_shop_channel_mix.sql:51:43

Finished 'compile' with 1 warning for target 'dev' [3.1s]
Processed: 28 models | 61 tests | 1 snapshot | 12 seeds
Summary: 102 total | 102 success
```

Baseline still compiles the whole graph successfully — a syntax error is only
a **warning** here, not a blocker — but it is the one and only thing baseline
has any opinion about. It has nothing to say about the ambiguous column in
`fct_brew_yield` or the missing column in `dim_supplier_scorecard`, and it
cannot see the two defects hiding behind the ones it does catch. Malformed SQL
is a grammar problem; baseline parses Jinja and SQL grammar without touching a
warehouse, so grammar is exactly as far as it reaches.

## The comparison that matters

Run the same code four ways:

| Command | Result |
|---|---|
| `dbt compile` (dbt Core) | silent, no errors |
| `dbt run` (dbt Core) | **3 Database Errors** |
| `dbt compile --static-analysis off` | 102/102 success |
| `dbt compile --static-analysis baseline` | 102/102 success, 1 warning |
| `dbt compile --static-analysis strict` | **4 errors** — the 3 above, plus `dbt0432` |

Try the dbt Core half yourself:

```bash
dbt compile --vars 'include_quarantined: true' --select tag:quarantined   # silent
dbt run     --vars 'include_quarantined: true' --select tag:quarantined
```

```
Completed with 3 errors, 0 partial successes, and 0 warnings:
  Database Error in model dim_supplier_scorecard
    invalid identifier 'SUPPLIERS.CONTRACT_START_DATE'
Done. PASS=0 WARN=0 ERROR=3 SKIP=0 NO-OP=0 TOTAL=3
```

Two things to take from that table.

**Ahead-of-time analysis is the product.** dbt Core found the column-level
defects too — but only by sending broken SQL to Snowflake and reading the error
back. dbt Core v2 found them from the code, with no warehouse execution.

**Baseline finds almost none of them.** Baseline does not download remote
source schemas, so it has no column information to check against — it cannot
see a single one of the five column- and type-level defects in this project.
The one thing it does catch, a broken-grammar syntax error, it catches as a
warning that does not even block the compile. This is exactly why the guidance
is *strict in development, baseline in deployment*:

!!! danger "Reaching baseline clean is not the same as being correct"
    Baseline means **not blocked**. Strict means **checked**. A project that
    passes baseline — even with a warning logged — can still be full of the
    errors above. Baseline is the right setting for deployment because you do
    not want a job blocked on an analyzer finding — not because it is a
    sufficient quality gate. Five of this project's six quarantined defects are
    completely invisible to it.

## Fix them

Each fix below reveals a second, previously hidden defect. Re-run strict after
each first fix to see it.

**`fct_brew_yield`** — `potion_sku` exists on both sides of the join. Qualify
every reference in the model:

```sql
select
    brew_events.brew_id,
    brew_events.potion_sku,
    brew_events.shop_id,
    ...
```

Re-run, and a new error appears where the old one was:

```
[error] [FunctionResolutionFailed (dbt0209)]: Failed to resolve function
  DATEADD: Argument type mismatch: actual: (VARCHAR, TIMESTAMP_NTZ(9), bigint);
  candidates: ...
  --> models/marts/fct_brew_yield.sql:27:5
```

`dateadd('minute', brew_events.brewed_at, brew_events.brew_duration_minutes)`
has its arguments transposed — Snowflake's signature is
`dateadd(part, value, date)`, and this model passes the timestamp where the
number belongs. Swap them:

```sql
dateadd('minute', brew_events.brew_duration_minutes, brew_events.brewed_at)
    as brew_finished_at
```

This is the capability gap the other two defects do not show: a type error is
invisible to `off`, invisible to `baseline`, and invisible to dbt Core's
`compile`. It only exists because the analyzer resolved types from the schema
— exactly what baseline cannot do.

**`dim_supplier_scorecard`** — the column does not exist. The analyzer tells
you what does: `CONTRACTED_SINCE`. Change the select list, then re-run:

```
[error] [UnaggregatedColumn (dbt0213)]: Un-aggregated columns in aggregation
  context: SUPPLIERS.REGION must be aggregated or appear in a GROUP BY clause
  --> models/marts/dim_supplier_scorecard.sql:20:5
```

`region` is in the select list but dropped from the `group by` — the exact
duplicate-row behavior this model was re-scoped over before it ever shipped.
Add it back.

**`agg_shop_channel_mix`** — two defects stacked, and the story behind them is
one edit interrupted. The `courier_owl` branch has an unclosed `sum(` — fix the
parenthesization first:

```sql
sum(item_totals.gross_amount_gold) as gross_revenue_gold,
count(distinct orders.order_id) as order_count
```

Re-run, and the defect behind it is not a column problem at all:

```
[error] [ProjectionFailed (dbt0301)]: Failed to align columns for UNION ALL
  query: Queries must have the same number of columns. Expected 3, but got 4
  --> models/marts/agg_shop_channel_mix.sql:63:1
```

`in_store` selects three columns; `courier_owl` selects four. Someone was
mid-edit adding `order_count` to the courier branch, got pulled off, and left
both an unclosed paren and two branches that no longer agree — which
`select *` at the union site hides from a reader completely. Add the missing
`count(distinct orders.order_id) as order_count` to `in_store` as well.

Then:

```bash
dbt compile --static-analysis strict --vars 'include_quarantined: true'
```

```
Finished 'compile' with 1 error for target 'dev'
```

Down to the single `dbt0432` finding from earlier, which
[Module 3b](03b-dynamic-sql-and-introspection.md) handles.

## When to opt out instead of fixing

Sometimes a finding is an analyzer limitation, not a bug — adapter-specific SQL
the analyzer cannot fully model, for instance. `static_analysis` can be set per
resource, right in the model's own `config()`:

```jinja
{{
    config(
        materialized = 'audit_table',
        static_analysis = 'off',
        compliance_owner = 'guild-audit-team'
    )
}}
```

Before you reach for this, check whether it is actually needed. Comment out
the `static_analysis` line in `fct_regulated_potion_sales.sql` and re-run
strict — the model compiles fine without it. An opt-out that nobody revisits is
a permanently unchecked model.

!!! warning "Quote the `off`"
    In a **YAML** config — `dbt_project.yml` or a properties file like
    `_marts__models.yml` — `+static_analysis: 'off'` needs the quotes. Without
    them, YAML parses bare `off` as the boolean `False`, not the string `'off'`.
    A Jinja `config()` block like the one above cannot make this mistake — a
    string is always a string there. Module 5 is entirely about what happens
    when the YAML form loses its quotes.

## Takeaways

- Strict finds real bugs from code alone; dbt Core needed a warehouse round trip.
- Baseline cannot see column-level or type-level problems, and treats malformed
  SQL as a warning rather than a block. Clean baseline ≠ correct project.
- Strict in development, baseline in deployment.
- Fix findings by default; opt out only with a justification you have tested.

**Solution branch:** `solution/03-baseline-strict`

**Next:** [Module 3b — Dynamic SQL and introspection](03b-dynamic-sql-and-introspection.md)
