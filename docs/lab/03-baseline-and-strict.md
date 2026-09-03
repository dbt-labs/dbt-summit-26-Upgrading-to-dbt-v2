# Module 3 — Baseline and strict

**Gate:** static analysis. This is where dbt Core v2 earns its keep.

## Run baseline

Baseline is the default and the documented compatibility landing zone:

```bash
dbt compile --static-analysis baseline
```

```
Finished 'compile' successfully for target 'dev' [1.8s]
Summary: 96 total | 96 success
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

Open `dbt_project.yml`:

```yaml
      quarantine:
        # Switched off during past incidents and never revisited. Nothing here
        # is in the nightly job, so the SQL has not been exercised in months.
        +enabled: "{{ var('include_quarantined', false) }}"
        +tags: ['quarantined']
```

Three models in `models/marts/quarantine/` were switched off during past
incidents and never revisited. Every real project has some. Nobody knows what
state they are in, because nothing has compiled them in months.

Bring them back:

```bash
dbt compile --static-analysis strict --vars 'include_quarantined: true'
```

```
[error] [UnresolvedIdentifier (dbt0227)]: No column SUPPLIERS.CONTRACT_START_DATE
  found. Available are SUPPLIERS.CONTRACTED_SINCE, INGREDIENTS.INGREDIENT_NAME, ...
  --> models/marts/quarantine/dim_supplier_scorecard.sql:18:5

[error] [UnresolvedIdentifier (dbt0227)]: Ambiguous column 'POTION_SKU' found.
  Available are BREW_EVENTS.POTION_SKU, POTIONS.POTION_SKU, ...
  --> models/marts/quarantine/fct_brew_yield.sql:12:5

[error] [FunctionResolutionFailed (dbt0209)]: Failed to resolve function COUNT:
  Ambiguous column 'ORDER_ID' found. Available are ITEM_TOTALS.ORDER_ID,
  ORDERS.ORDER_ID, ...
  --> models/marts/quarantine/agg_shop_channel_mix.sql:15:20

Finished 'compile' with 3 errors for target 'dev'
```

Three real defects, each with a file, a line, a column, and the list of columns
that *were* available.

## The comparison that matters

Run the same code four ways:

| Command | Result |
|---|---|
| `dbt compile` (dbt Core) | silent, no errors |
| `dbt run` (dbt Core) | **3 Database Errors** |
| `dbt compile --static-analysis off` | 99/99 success |
| `dbt compile --static-analysis baseline` | 99/99 success |
| `dbt compile --static-analysis strict` | **the same 3 errors**, plus `dbt0432` |

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

**Ahead-of-time analysis is the product.** dbt Core found these too — but only by
sending broken SQL to Snowflake and reading the error back. dbt Core v2 found
them from the code, with no warehouse execution.

**Baseline did not find them.** Baseline does not download remote source
schemas, so it has no column information to check against. It cannot see
column-level defects *at all*. This is the single most important thing to
understand about the modes:

!!! danger "Reaching baseline clean is not the same as being correct"
    Baseline means **not blocked**. Strict means **checked**. A project that
    passes baseline can still be full of the errors above. Baseline is the right
    setting for deployment because you do not want a job blocked on an analyzer
    finding — not because it is a sufficient quality gate.

    This is exactly why the guidance is *strict in development, baseline in
    deployment*. Strict is where you catch things; baseline is where you avoid
    blocking production on them.

## Fix them

**`dim_supplier_scorecard`** — the column does not exist. The analyzer tells you
what does: `CONTRACTED_SINCE`. Change both the select list and the `group by`.

**`fct_brew_yield`** — `potion_sku` exists on both sides of the join. Qualify
every reference in the model.

**`agg_shop_channel_mix`** — two defects stacked. Qualify `order_id` inside the
`count(distinct ...)` first, then re-run:

```
[error] [UnaggregatedColumn (dbt0213)]: Un-aggregated columns in aggregation
  context: ...CHANNEL must be aggregated or appear in a GROUP BY clause
```

The second error was hidden behind the first. `channel` is in the select list
but not in the `group by` — which is precisely the duplicate-row behavior that
got this model quarantined in the first place. Add it.

Then:

```bash
dbt compile --static-analysis strict --vars 'include_quarantined: true'
```

Down to the single `dbt0432` finding from earlier, which
[Module 3b](03b-dynamic-sql-and-introspection.md) handles.

## When to opt out instead of fixing

Sometimes a finding is an analyzer limitation, not a bug — adapter-specific SQL
the analyzer cannot fully model, for instance. `static_analysis` can be set per
resource:

```yaml
      compliance:
        +materialized: audit_table
        +static_analysis: 'off'
```

Before you reach for this, check whether it is actually needed. Comment out that
line in this project and re-run strict — the compliance model compiles fine
without it. An opt-out that nobody revisits is a permanently unchecked model.

!!! warning "Quote the `off`"
    `+static_analysis: 'off'` with quotes. Module 5 is entirely about what
    happens when you drop them.

## Takeaways

- Strict finds real bugs from code alone; dbt Core needed a warehouse round trip.
- Baseline cannot see column-level problems. Clean baseline ≠ correct project.
- Strict in development, baseline in deployment.
- Fix findings by default; opt out only with a justification you have tested.

**Solution branch:** `solution/03-baseline-strict`

**Next:** [Module 3b — Dynamic SQL and introspection](03b-dynamic-sql-and-introspection.md)
