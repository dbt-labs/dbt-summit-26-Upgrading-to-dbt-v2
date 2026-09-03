# Instructor notes

Everything in this lab was verified against a live Snowflake warehouse on
**2026-09-02** with:

- dbt Core 1.10.23 / dbt-snowflake 1.10.8
- dbt Core v2 `dbt-fusion 2.0.0-preview.218`
- `dbt-autofix` latest via `uvx`

## Verified behavior matrix

| Fixture | dbt Core | v2 parse | `off` | `baseline` | `strict` | Deferral |
|---|---|---|---|---|---|---|
| Generic-test args at top level (11) | warning | **error** ×11 | — | — | — | — |
| `marts.materialized` missing `+` | silent | **error** | — | — | — | — |
| Model-level `docs:` key | silent | **error** | — | — | — | — |
| Macro `type: varchar` (4) | silent | **warning** ×4 | — | — | — | — |
| Column typo (`contract_start_date`) | run-time DB error | clean | clean | clean | **dbt0227** | — |
| Ambiguous `potion_sku` | run-time DB error | clean | clean | clean | **dbt0227** | — |
| Ambiguous `order_id` in `count()` | run-time DB error | clean | clean | clean | **dbt0209** | — |
| `channel` not in `group by` | run-time DB error | clean | clean | clean | **dbt0213** | — |
| Unquoted `static_analysis: off` | silent, builds | clean | clean | clean | clean | **dbt1150** |
| >1 MiB seed content change | not detected | — | — | — | — | see below |
| `--maximum-seed-size-mib 8` vs Core artifact | — | — | — | — | — | **all 3 seeds always modified** |

Counts: parse errors go 13 → 0 after Autofix; 4 warnings remain for the manual
step. Strict with `include_quarantined: true` reports 3 errors across 26 models.

## Things the source research predicted that did NOT reproduce

Be straight with the room about these — trainees who have read the field
guidance will ask, and the honest answer is more useful than the prediction.

**Unsafe introspection is not flagged.** The `run_query`/`execute` macro in
`get_potion_categories()` compiles cleanly in all three modes. It executes at
compile time and dbt Core v2 does not object. Teach it as technical debt with a
concrete cost (cold-start fragility, the required `depends_on` hint) rather than
as a blocker.

**Conditional-ephemeral materialization does not break.** `fct_orders_backfill`
switching to ephemeral under `PIPELINE_RUN_MODE=backfill` compiles and builds
successfully on both engines, and the downstream model inlines it fine. Teach it
as graph-stability hygiene, not as a failure.

**Snowflake-specific SQL is handled well.** Probes for `group by` on a select
alias, `qualify`, `select * exclude (...)`, and `join ... using (...)` all pass
strict. Do not promise dialect friction.

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
  Core v2    compile --static-analysis off        98/98 success
  Core v2    compile --static-analysis baseline   98/98 success
  Core v2    compile --static-analysis strict     3 errors, no warehouse
```

Two messages, and the second one is the one people miss:

1. Ahead-of-time analysis finds real bugs without touching the warehouse.
2. **Baseline finds none of them.** Baseline does not download remote schemas,
   so it cannot see column-level defects. "We reached baseline clean" means "we
   are not blocked", not "we are correct."

If a trainee leaves thinking baseline is a quality gate, the module failed.

## Timing

| Module | Time | Notes |
|---|---|---|
| 0 — Setup and context | 10–15 min | Modes table and AOT/JIT framing |
| 1 — Parse and deprecations | 30 min | Autofix dry-run, apply, manual fix |
| 2 — Compile with analysis off | 15 min | Short; read compiled SQL |
| 3 — Baseline and strict | 40 min | The core of the lab |
| 4 — Run, build, and state | 30 min | Seed state trap needs care |
| 5 — Deferral and rollout | 25 min | Half exercise, half discussion |

## Running the lab

Seeding takes roughly 90 seconds on dbt Core. Have trainees run `dbt seed` and a
full `dbt build` before Module 1 so warehouse time is not on the clock.

Snapshot of a clean starting state:

```bash
dbt build          # dbt Core -> PASS=92 WARN=0 ERROR=0 TOTAL=92
```

If someone falls behind, they can jump to the relevant branch:

| Branch | State |
|---|---|
| `main` | Core-green start |
| `solution/01-deprecations` | v2 parse clean, Core still PASS=92 |
| `solution/03-baseline-strict` | strict clean, 26 models, quarantine re-enabled |
| `exercise/05-broken-deferral` | the deferral trap, pre-applied |

Modules 2 and 4 change no code, so they have no branch.

## Warehouse setup

Seeds carry the data, so there is no pre-existing warehouse state to provision —
a fresh schema and a connection is all a trainee needs. Roughly 100k rows across
12 seeds.

Three seeds exceed 1 MiB (`raw_order_items`, `raw_orders`, `raw_payments`),
which is what makes the Module 4 state exercise work. Do not shrink them.
