# Module 1 — Parse and deprecations

**Gate:** `dbt parse` must succeed before anything else runs.

## Start with dbt Core

First, confirm what dbt Core thinks of this project:

```bash
dbt parse --no-partial-parse --show-all-deprecations
```

dbt Core parses it, builds it, and reports deprecation **warnings**:

```
[WARNING][MissingArgumentsPropertyInGenericTestDeprecation]: Deprecated functionality
Found top-level arguments to test `accepted_values`. Arguments to generic tests
should be nested under the `arguments` property.

[WARNING][DeprecationsSummary]: Summary of encountered deprecations:
- MissingArgumentsPropertyInGenericTestDeprecation: 11 occurrences
```

Warnings. The project still builds. This is exactly the position most teams are
in: deprecations have been accruing quietly for a year and nothing forced the
issue.

## Now run dbt Core v2

```bash
dbt parse
```

```
Finished 'parse' with 4 warnings and 13 errors for target 'dev'
```

The same project. Thirteen errors, and it will not proceed.

Read the errors — they fall into three groups:

```
[error] [SerializationError (dbt1013)]: Invalid model definition
  `merlinco_apothecaries.marts.materialized`: Unrecognized key
  `merlinco_apothecaries.marts.materialized`. Custom keys must go under `+meta`.
  --> dbt_project.yml:38:21

[error] [UnusedConfigKey (dbt1060)]: While parsing config: Ignored unexpected
  key `"docs"`. YAML path: `docs`.
  --> models/marts/_marts__models.yml:6:5

[error] [DbtYamlValidationError (dbt1159)]: Deprecated test arguments:
  ["values"] at top-level detected. Please migrate to the new format under the
  'arguments' field.
  --> models/staging/abra_pos/_stg_abra_pos__models.yml:33:23
```

!!! note "Why `materialized` without a `+` is an error, not a typo"
    In `dbt_project.yml`, config keys take a `+` prefix. Without it, the key is
    ambiguous with a subdirectory name — `marts.materialized` could mean "the
    materialized config for marts" or "a folder called materialized". dbt Core
    guesses; dbt Core v2 makes you say which.

## Run dbt-autofix

```bash
uvx dbt-autofix@latest deprecations --dry-run
```

Read the dry run before applying it. It proposes seven changesets:

- generic-test arguments moved under `arguments` (11 tests)
- model-level `docs:` moved under `config:`
- `+` prefix added to `marts.materialized`
- deprecated `target-path` removed
- `flags.require_generic_test_arguments_property` set to `true`

Then apply it:

```bash
uvx dbt-autofix@latest deprecations
dbt parse
```

```
Finished 'parse' with 4 warnings for target 'dev'
```

Thirteen errors down to zero. Four warnings remain.

## Finish the job by hand

Autofix cleared the errors and left the warnings alone:

```
[warning] [ValidateMacroArgs (dbt1506)]: macros/_macros.yml: Macro
  "copper_to_gold": argument "column_name" has unsupported type "varchar".
  Supported types are: string, str, boolean, bool, integer, int, float, any,
  relation, column, list[T], dict[K,V], optional[T], T1|T2|...
```

The macro properties annotate arguments with `varchar` — a warehouse type. dbt's
type annotations are its own vocabulary, and `string` is the right token.

In `macros/_macros.yml`, change all four:

```yaml
    arguments:
      - name: column_name
        type: string        # was: varchar
```

```bash
dbt parse
```

```
Finished 'parse' successfully for target 'dev'
```

## Confirm you did not break dbt Core

Autofix rewrote your YAML and set a behavior flag. Verify the project still
builds on the engine that is currently serving production:

```bash
dbt build      # dbt Core
Done. PASS=92 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=92
```

Green, and dbt Core no longer reports deprecations either. Both engines are now
happy with the same code — which is what makes a staged rollout possible.

!!! warning "Trust, but verify Autofix"
    A July 2026 Autofix regression mis-classified compatible package versions as
    incompatible, affecting roughly a thousand projects. It is fixed, but the
    habit it should leave you with is the right one: read the `--dry-run`, and
    re-run your dbt Core build after applying changes.

## Takeaways

- dbt Core's deprecation warnings are dbt Core v2's parse errors. Clearing them
  is not optional cleanup — it is the first gate.
- Autofix handles the mechanical majority. It does not touch warnings.
- `--dry-run` first, and re-verify on dbt Core afterwards.

**Solution branch:** `solution/01-deprecations`
