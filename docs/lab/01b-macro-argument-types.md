# Module 1b — Macro argument types

**Gate:** `dbt parse`. These are warnings, not errors — and Autofix will not
touch them.

This is a small, mechanical-looking exercise that is worth doing carefully,
because the obvious approach gets it wrong.

## Where they come from

Macro properties can document each argument's type:

```yaml
macros:
  - name: copper_to_gold
    arguments:
      - name: column_name
        type: varchar
```

`varchar` is a **warehouse** type. dbt's type annotations are a separate, much
smaller vocabulary describing what kind of *Jinja value* the argument takes —
not what SQL type it eventually renders into. dbt Core never checked, so nobody
found out.

A real customer ticket had roughly nineteen macros annotated this way. This
project has exactly nineteen.

## See them

```bash
dbt parse
```

```
Finished 'parse' with 19 warnings and 13 errors for target 'dev'
```

The thirteen errors are [Module 1](01-parse-and-deprecations.md). Look at the
warnings:

```
[warning] [ValidateMacroArgs (dbt1506)]: macros/_macros.yml: Macro
  "copper_to_gold": argument "column_name" has unsupported type "varchar".
  Supported types are: string, str, boolean, bool, integer, int, float, any,
  relation, column, list[T], dict[K,V], optional[T], T1|T2|...
```

Count what you are actually dealing with:

```bash
dbt parse 2>&1 | grep -oE 'unsupported type "[a-z]+"' | sort | uniq -c
```

```
   2 unsupported type "date"
   2 unsupported type "numeric"
   1 unsupported type "timestamp"
  14 unsupported type "varchar"
```

## Confirm Autofix will not help

```bash
uvx dbt-autofix@latest deprecations --dry-run
```

Nothing in the output touches `macros/_macros.yml` or
`macros/utils/_utils.yml`. Autofix resolves deprecations that dbt reports as
errors. These are warnings, so they are yours.

This is the general shape of the thing: **Autofix clears the blocking work and
leaves the judgement work.** Do not treat a clean Autofix run as a clean
project.

## Now do the fix

Here is the trap. The tempting move is:

```bash
# don't
sed -i '' 's/type: varchar/type: string/' macros/**/*.yml
```

That clears 14 of 19 and leaves 5, because four different warehouse types are in
play and **dbt's vocabulary has no `date` and no `timestamp` member at all**.
Read the supported list in the error again — it describes Jinja values.

Work out each one from what the argument actually receives:

| Annotation | Macro / argument | Receives | Fix |
|---|---|---|---|
| `varchar` ×14 | `column_name`, `numerator`, … | a column name or SQL expression, as a string | `string` |
| `date` ×2 | `days_between(start_date, end_date)` | a column **name**, not a date value | `string` |
| `timestamp` ×1 | `is_weekend(timestamp_column)` | a column **name** | `string` |
| `numeric` ×2 | `bucket_amount(low_threshold, high_threshold)` | an actual number | `float` |

The `date` and `timestamp` cases are the instructive ones. It is tempting to
hunt for a date type; there isn't one, and there shouldn't be. `days_between`
does not receive a date — it receives the *name of a column* and interpolates it
into SQL. The value passing through Jinja is a string.

!!! tip "`column` is also available"
    For arguments that always take a bare column name, `column` is arguably
    more precise than `string`. Either is accepted. Pick one convention and
    apply it consistently — the point of the annotation is that a reader can
    tell what to pass.

Then:

```bash
dbt parse
```

```
Finished 'parse' successfully for target 'dev'
```

## Re-verify on dbt Core

```bash
dbt build      # dbt Core
Done. PASS=93 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=93
```

Annotations are metadata — they do not change rendered SQL — but check anyway.
You just edited nineteen things by hand.

## Takeaways

- Warehouse types in macro annotations are silently wrong on dbt Core and
  reported by dbt Core v2. Nineteen of them here, matching a real ticket.
- Autofix clears none of them: it fixes errors, not warnings.
- A blanket `varchar` → `string` replace leaves five behind. There is no `date`
  or `timestamp` annotation, because the vocabulary describes Jinja values, not
  SQL types.
- Ask what the argument *receives*. Column names are strings; thresholds are
  numbers.

**Solution branch:** `solution/01-deprecations`
