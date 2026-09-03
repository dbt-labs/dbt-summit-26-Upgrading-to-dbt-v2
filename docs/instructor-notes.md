# Instructor notes

Everything in this lab was verified against a live Snowflake warehouse on
**2026-09-02** with:

- dbt Core 1.10.23 / dbt-snowflake 1.10.8
- dbt Core v2 `dbt-fusion 2.0.0-preview.218`
- `dbt-autofix` latest via `uvx`

## Verified behavior matrix

| Fixture | dbt Core | v2 parse | `off` | `baseline` | `strict` | `--no-introspect` | Deferral |
|---|---|---|---|---|---|---|---|
| Generic-test args at top level (11) | warning | **error** ×11 | — | — | — | — | — |
| `marts.materialized` missing `+` | silent | **error** | — | — | — | — | — |
| Model-level `docs:` key | silent | **error** | — | — | — | — | — |
| Macro warehouse-type annotations (19) | silent | **warning** ×19 | — | — | — | — | — |
| Column typo (`contract_start_date`) | run-time DB error | clean | clean | clean | **dbt0227** | — | — |
| Ambiguous `potion_sku` | run-time DB error | clean | clean | clean | **dbt0227** | — | — |
| Ambiguous `order_id` in `count()` | run-time DB error | clean | clean | clean | **dbt0209** | — | — |
| `channel` not in `group by` | run-time DB error | clean | clean | clean | **dbt0213** | — | — |
| Dynamic `PIVOT ... IN (ANY)` | builds | clean | clean | clean | **dbt0432** | clean | — |
| Compile-time `run_query` | builds | clean | clean | clean | clean | **dbt1307** | — |
| Unquoted `static_analysis: off` | silent, builds | clean | clean | clean | clean | — | **dbt1150** |
| >1 MiB seed content change | not detected | — | — | — | — | — | see below |
| `--maximum-seed-size-mib 8` vs Core artifact | — | — | — | — | — | — | **all 3 seeds always modified** |

### Exact counts

Starting state (`main`): v2 parse reports **13 errors and 19 warnings**; dbt
Core builds `PASS=93 ERROR=0` with 11 deprecation warnings.

After Module 1 (`solution/01-deprecations`), v2 parse is clean and:

| | `off` | `baseline` | `strict` |
|---|---|---|---|
| quarantine off (default) | 96/96 | 96/96 | **1 error** (dbt0432) |
| quarantine on | 99/99 | 99/99 | **4 errors** (2× dbt0227, dbt0209, dbt0432) |

The 19 macro warnings break down as 14 `varchar`, 2 `date`, 2 `numeric`, 1
`timestamp`. A blanket `varchar` → `string` replace clears only 14 — that is the
intended trap in Module 1b, since dbt's type vocabulary has no `date` or
`timestamp` member.

## Things the source research predicted that did NOT reproduce

Be straight with the room about these — trainees who have read the field
guidance will ask, and the honest answer is more useful than the prediction.

**Unsafe introspection is not flagged by static analysis** — but it *is* caught,
by a separate gate. `get_potion_categories()` compiles cleanly in all three
modes. Disable introspection and it fails in **all three**, including `off`:

```
dbt compile --static-analysis off --no-introspect
[error] [DbUnsupportedFeature (dbt1307)]: Not Supported: Introspective queries
  are disabled (--no-introspect).
  --> macros/get_potion_categories.sql:21:11
```

So the finding is real; it is just orthogonal to the `off`/`baseline`/`strict`
axis. Introspection is its own gate, and it is the one thing `off` does not
excuse — which matters because any genuine ahead-of-time compile path cannot run
your queries. Module 3b covers this.

**Conditional-ephemeral materialization does not break.** `fct_orders_backfill`
switching to ephemeral under `PIPELINE_RUN_MODE=backfill` compiles and builds
successfully on both engines, and the downstream model inlines it fine. Teach it
as graph-stability hygiene, not as a failure.

**Dynamic SQL *is* flagged in strict**, via a different route than introspection:
Snowflake's `pivot (... in (any ...))` fails strict with `dbt0432` while passing
baseline. Paired with the introspection finding above, this is the strongest
argument in the deck for running strict in development.

**Snowflake-specific SQL is handled well.** Probes for `group by` on a select
alias, `qualify`, `select * exclude (...)`, and `join ... using (...)` all pass
strict. Dynamic `PIVOT ... IN (ANY)` is the exception, and it fails for a
semantic reason rather than a dialect one — the output columns are unknowable
ahead of time.

**`dbt_utils.unpivot` compiles cleanly** in all three modes and with
`--no-introspect`, as long as the introspected relation exists. The documented
failure mode (introspection returning nothing, rendering `select * from ()`) is
a cold-start problem and could not be made Core-green, so it is not a fixture.

**Seeds and snapshots do not spuriously appear modified** on a like-for-like
cross-engine comparison. The seed problem is real but has a specific cause — the
1 MiB hashing limit — not general state flakiness.

**`resource_type` parse-time macro failure** was not built as a fixture. It does
not survive the Core-green requirement, and the parse module has thirteen real
errors without it.

**A custom top-level key in `dbt_project.yml`** is a hard error in dbt Core
1.10.23, not a deprecation, so it cannot ship in a Core-green project. Autofix
still demonstrates the `+meta` guidance via the `materialized` prefix finding.

## Framing the headline

The most valuable slide in this deck is the Module 3 table:

```
same code, include_quarantined: true

  dbt Core   compile                              silent
  dbt Core   run                                  3 Database Errors
  Core v2    compile --static-analysis off        99/99 success
  Core v2    compile --static-analysis baseline   99/99 success
  Core v2    compile --static-analysis strict     4 errors, no warehouse
```

Two messages, and the second one is the one people miss:

1. Ahead-of-time analysis finds real bugs without touching the warehouse.
2. **Baseline finds none of them.** Baseline does not download remote schemas,
   so it cannot see column-level defects. "We reached baseline clean" means "we
   are not blocked", not "we are correct."

If a trainee leaves thinking baseline is a quality gate, the module failed.

The Module 3b pair reinforces the same point from a different angle — two
dynamic-SQL patterns, two different gates, neither one caught by baseline:

```
  Dynamic PIVOT ... IN (ANY)     strict: dbt0432    baseline: clean
  Compile-time run_query         strict: clean      --no-introspect: dbt1307
```

## Timing

| Module | Time | Notes |
|---|---|---|
| 0 — Setup and context | 10–15 min | Modes table and AOT/JIT framing |
| 1 — Parse and deprecations | 30 min | Autofix dry-run, apply, manual fix |
| 2 — Compile with analysis off | 15 min | Short; read compiled SQL |
| 1b — Macro argument types | 20 min | The blanket-sed trap is the point |
| 3 — Baseline and strict | 40 min | The core of the lab |
| 3b — Dynamic SQL and introspection | 30 min | Two gates; do both fixtures |
| 4 — Run, build, and state | 30 min | Seed state trap needs care |
| 5 — Deferral and rollout | 25 min | Half exercise, half discussion |

## Running the lab

Seeding takes roughly 90 seconds on dbt Core. Have trainees run `dbt seed` and a
full `dbt build` before Module 1 so warehouse time is not on the clock.

Snapshot of a clean starting state:

```bash
dbt build          # dbt Core -> PASS=93 WARN=0 ERROR=0 TOTAL=93
```

If someone falls behind, they can jump to the relevant branch:

| Branch | State |
|---|---|
| `main` | Core-green start |
| `solution/01-deprecations` | v2 parse clean, 19 annotations fixed, Core PASS=93 |
| `solution/03-baseline-strict` | column findings fixed, quarantine re-enabled |
| `solution/03b-dynamic-sql` | strict 99/99 and clean under `--no-introspect` |
| `exercise/05-broken-deferral` | the deferral trap, pre-applied |

Modules 2 and 4 change no code, so they have no branch. Module 1b's fix lands
in `solution/01-deprecations`.

## Warehouse setup

Seeds carry the data, so there is no pre-existing warehouse state to provision —
a fresh schema and a connection is all a trainee needs. Roughly 100k rows across
12 seeds.

Three seeds exceed 1 MiB (`raw_order_items`, `raw_orders`, `raw_payments`),
which is what makes the Module 4 state exercise work. Do not shrink them.
