# Module 2 — Compile with static analysis off

**Gate:** the project renders to SQL under dbt Core v2 the way it does under dbt Core.

No code changes in this module. It is a checkpoint, and it is worth
understanding why the upgrade assistant includes it.

## Run it

```bash
dbt compile --static-analysis off
```

```
Finished 'compile' successfully for target 'dev' [2.7s]
Processed: 23 models | 59 tests | 1 snapshot | 12 seeds
Summary: 95 total | 95 success
```

## What this actually proved

`off` renders Jinja to SQL and stops. No column resolution, no type checking, no
schema downloads. It is deliberately the closest dbt Core v2 gets to dbt Core's
behavior.

So a clean run here tells you something narrow but valuable: **every macro,
every `ref`, every config, and every piece of Jinja in the project resolves
under the new engine.** Your graph is intact. Whatever comes up in the next
module will be about SQL semantics, not about the project failing to render.

That separation is the reason the assistant has this step. When strict mode
throws fifty errors, you want to already know they are all one category of
problem.

## Look at the rendered SQL

```bash
cat target/compiled/merlinco_apothecaries/models/marts/fct_orders.sql
```

Compare it against the dbt Core output for the same model. This is a good moment
to look at `agg_category_revenue_pivot`, which builds its column list by
querying the warehouse at compile time through `get_potion_categories()`:

```bash
cat target/compiled/merlinco_apothecaries/models/marts/agg_category_revenue_pivot.sql
```

The macro uses `run_query` behind an `execute` guard and a `load_relation`
existence check, and it needs an explicit `-- depends_on:` hint because the
`ref` is inside a conditional. dbt Core v2 runs it and renders it without
complaint.

!!! note "`off` does not excuse everything"
    Static analysis has no objection to this macro in any of the three modes —
    it runs the query, gets real values, and renders ordinary SQL.

    But introspection is gated separately from static analysis, and that gate
    catches it even here in `off` mode:

    ```bash
    dbt compile --static-analysis off --no-introspect --select agg_category_revenue_pivot
    ```

    ```
    [error] [DbUnsupportedFeature (dbt1307)]: Not Supported: Introspective
      queries are disabled (--no-introspect).
      --> macros/get_potion_categories.sql:21:11
    ```

    So `off` is Core parity for everything *except* introspection. That is
    covered properly in
    [Module 3b](03b-dynamic-sql-and-introspection.md).

## Takeaways

- `off` is a migration tool, not a destination. Do not ship it.
- A clean `off` compile isolates rendering problems from SQL problems, so the
  next gate's findings are all one kind of thing.
- Diff the compiled SQL against dbt Core's if you want reassurance before moving
  on.
- `off` is not a blanket amnesty: introspective queries fail even here.
