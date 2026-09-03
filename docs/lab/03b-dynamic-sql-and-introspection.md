# Module 3b — Dynamic SQL and introspection

**Gate:** static analysis, plus one gate you have not met yet.

Two models in this project build their own SQL shape at run time. Both work on
dbt Core. They fail at **different** gates, which is the whole lesson.

## Why dynamic SQL is a problem at all

dbt Core v2 builds a logical plan ahead of time: it resolves every model's
columns and types before anything executes. A model whose column list is not
knowable until the query runs cannot participate in that — no column lineage, no
downstream type checking, no IDE completion through it.

So "dynamic SQL" is not banned because it is untidy. It is a hole in the graph.

## Fixture 1 — dynamic PIVOT

`agg_payment_method_mix` pivots collected revenue into one column per payment
method using Snowflake's dynamic pivot:

```sql
pivot (
    sum(collected_gold)
    for primary_payment_method in (any order by primary_payment_method)
) as pivoted
```

`in (any ...)` means "whatever values are in the data". Run the modes:

```bash
dbt compile --static-analysis off      --select agg_payment_method_mix   # clean
dbt compile --static-analysis baseline --select agg_payment_method_mix   # clean
dbt compile --static-analysis strict   --select agg_payment_method_mix
```

```
[error] [InvalidPivot (dbt0432)]: Dynamic PIVOT with ANY is not supported by
  dbt static analysis. Set static_analysis = 'off' for this model or consider
  one of the other options here:
  https://docs.getdbt.com/docs/fusion/new-concepts#dynamic-sql
  --> models/marts/agg_payment_method_mix.sql:...
```

**Clean in baseline, error in strict.** This is the mode contrast in its
purest form, and it is the reason to run strict in development even though
deployment stays on baseline. On baseline this model ships and silently
contributes nothing to lineage. Strict tells you.

### Fixing it

Two legitimate answers.

**Enumerate the values.** There are four payment methods, and there is already
an `accepted_values` test enforcing exactly that list on the staging model. Swap
the pivot for conditional aggregation over a declared list:

```jinja
{% set payment_methods = ['barter', 'coin', 'crystal_transfer', 'guild_credit'] %}

select
    shop_region,
    {% for method in payment_methods %}
    sum(case when primary_payment_method = '{{ method }}' then collected_gold else 0 end)
        as collected_gold_{{ method }},
    {% endfor %}
    sum(collected_gold) as collected_gold_total
from {{ ref('fct_orders') }}
group by shop_region
```

The `accepted_values` test is what keeps this honest — add a fifth method and
the test fails, pointing at the list.

**Or opt out**, as the error message itself suggests:

```yaml
      +static_analysis: 'off'
```

That is a real option, not a cop-out — but understand the cost. The model is
then never checked, and nothing downstream of it can be type-checked through it.
Prefer enumeration where the value set is small and already governed.

## Fixture 2 — compile-time introspection

`get_potion_categories()` discovers the category list by querying the warehouse
while the model compiles:

```jinja
{% set results = run_query(category_query) %}
{% set categories = results.columns[0].values() %}
```

Note what it takes to make that safe. The macro needs an `execute` guard
(there is no connection during parsing), a `load_relation` check (the upstream
table may not exist yet on a cold start), and the model needs an explicit
`-- depends_on:` hint because the `ref` sits inside a conditional. Three
workarounds for one convenience.

Run the modes:

```bash
dbt compile --static-analysis off      --select agg_category_revenue_pivot   # clean
dbt compile --static-analysis baseline --select agg_category_revenue_pivot   # clean
dbt compile --static-analysis strict   --select agg_category_revenue_pivot   # clean
```

All three clean. Static analysis has no objection — the macro runs, gets real
values, and renders ordinary SQL.

Now the gate you have not met:

```bash
dbt compile --static-analysis strict --no-introspect --select agg_category_revenue_pivot
```

```
[error] [DbUnsupportedFeature (dbt1307)]: Not Supported: Introspective queries
  are disabled (--no-introspect).
  --> macros/get_potion_categories.sql:21:11
```

Straight to the line. And try the other modes with the same flag:

| | `off` | `baseline` | `strict` |
|---|---|---|---|
| default | clean | clean | clean |
| `--no-introspect` | **dbt1307** | **dbt1307** | **dbt1307** |

**Introspection is its own gate, orthogonal to static analysis.** It fails even
in `off` mode — the one mode whose entire job is to behave like dbt Core. That
is the sharpest thing in this module: `off` excuses everything except this.

Which matters because a genuine ahead-of-time compile cannot run your queries.
Any compile path that will not open a warehouse connection hits this, regardless
of the analysis level you configured.

### Fixing it

Move the unknown out of compile time. Declare the list:

```yaml
vars:
  potion_categories:
    - clarity
    - healing
    - invisibility
    - love
    - luck
    - strength
```

```jinja
{% macro get_potion_categories() %}
    {{ return(var('potion_categories')) }}
{% endmacro %}
```

All three workarounds disappear with it — no `execute` guard, no
`load_relation` fallback, no `depends_on` hint. The same `accepted_values` test
guards the list.

Verify the whole project now compiles with no warehouse introspection at all:

```bash
dbt compile --static-analysis strict --no-introspect
```

```
Finished 'compile' successfully for target 'dev'
Summary: 99 total | 99 success
```

## The pair, side by side

| | dbt Core | `off` | `baseline` | `strict` | `--no-introspect` |
|---|---|---|---|---|---|
| Dynamic `PIVOT ... IN (ANY)` | builds | clean | clean | **dbt0432** | clean |
| Compile-time `run_query` | builds | clean | clean | clean | **dbt1307** |

Two patterns that look like the same category of sin, caught by two different
gates, and **neither caught by baseline**. If your acceptance criterion is
"baseline is clean", you ship both.

## Takeaways

- Dynamic SQL is a hole in the ahead-of-time graph, not a style problem.
- Dynamic `PIVOT ... IN (ANY)` fails strict (`dbt0432`); baseline lets it through.
- Compile-time introspection fails `--no-introspect` (`dbt1307`) in **all three
  modes**, including `off`.
- Both fixes are the same move: turn a discovered value into a declared one, and
  let a test guard the declaration.
- `static_analysis: 'off'` is a legitimate escape hatch with a real cost —
  prefer enumeration when the value set is small and already governed.

**Solution branch:** `solution/03b-dynamic-sql`
