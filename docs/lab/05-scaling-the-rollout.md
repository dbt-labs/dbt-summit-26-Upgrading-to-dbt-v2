# Module 5 — Scaling the rollout: cloning production, permissions, and overrides

**Gate:** none of your own — this module takes the deferral mechanics from
Module 5 and applies them at the scale of a real account: one project with
many jobs, and an account with many projects.

## Recap: why the rollout order is forced

Module 5 established the asymmetry that drives everything else in this module:

> dbt Core v2 can read dbt Core manifests. dbt Core cannot reliably read dbt
> Core v2 manifests.

Deferral only flows downward, from upper environments to lower ones. That is
why the order is dev (one person) → team dev → staging → production, and why
it is enforced per **project**, not per account.

## The wrinkle: clone production into staging before you flip it

The standard guidance for the staging step is: switch staging's environment
version to v2, run the critical jobs once, then watch scheduled jobs for a few
days to catch anything time- or data-dependent. That works, but it means the
first time you exercise the *whole* DAG on v2 is whenever staging's nightly job
happens to touch every model — which could be days away, and by then you are
debugging in a shared environment instead of before you ever flipped it.

There is a cheaper way to get the same coverage on day one: **defer to
production's manifest and clone production's relations into staging**, then
build only what has actually changed. You get a complete, queryable staging
environment — built end-to-end on v2 — without re-processing a single row that
production didn't already handle.

In this lab, the dbt Core build you already have stands in for "production."

### 1. Capture production's state

```bash
dbt parse --no-partial-parse       # dbt Core
mkdir -p state && cp target/manifest.json state/manifest.json
```

This is exactly the artifact Module 5 used for the `dbt1150` deferral failure —
here you are using it for real instead of breaking it.

### 2. Make the change you'd actually be shipping

Add a column to `dim_potions` (or make whatever small, real edit you'd ship
next) so that `state:modified` has something to find:

```sql
-- models/marts/dim_potions.sql
, potion_sku as legacy_potion_sku   -- new column
```

### 3. Add a staging target

In your local `profiles.yml` (gitignored — this does not get committed), add a
second output next to `dev` that points at its own schema, e.g.
`dbt_your_name_staging`. (On the dbt platform, this is the same idea as
pointing a Staging environment's deferral at the Production job — the
commands below are what that setting is doing under the hood.)

### 4. Clone everything unmodified straight out of "production"

```bash
dbt clone --state state --target staging --exclude state:modified
```

`dbt clone` does a zero-copy clone on Snowflake — every relation *not* touched
by your change lands in the staging schema instantly, with no data movement
and no rebuild.

### 5. Build only what changed, against the clone

```bash
dbt build --target staging --state state --select state:modified+ --defer
```

`--defer` covers anything still not physically present (sources, or nodes
`dbt clone` doesn't apply to) by reading it straight from production instead
of failing. Everything downstream of your change gets rebuilt fresh, on v2,
against a staging schema that is otherwise a complete mirror of production.

When this finishes, every node in the project exists and is queryable in
staging — some via clone, the rest freshly built — and you have validated the
entire DAG on v2 before touching staging's real environment setting. This is
additive to the standard staging step, not a replacement for it: still flip the
environment version and still monitor scheduled jobs afterward. The clone gets
you a clean first day instead of a hopeful one.

!!! tip "Same trap, different door"
    A config that serializes wrongly (Module 5's unquoted `off`) fails a
    `dbt clone` or `--defer` run exactly the same way it fails any other
    manifest consumer. Cloning production into staging is also, incidentally,
    the cheapest place to catch that class of bug — you find out before the
    rest of the team is depending on staging, not after.

## Scaling across many projects: permissions, not personal gatekeeping

None of the above changes when an account has thirty projects instead of one —
except that one admin cannot personally run or babysit thirty migrations. The
platform's permission model is built for that:

- An account admin checks **Enable fusion migration permissions** under
  Account Settings → Account → Settings. Once on, only users holding
  **Fusion Admin** permissions can execute an upgrade, even though everyone
  can still see the readiness panel.
- That permission is granted **per project**, through the relevant group's
  permission settings. This is the lever for a multi-project rollout: give
  each project's tech lead **Fusion Admin** scoped to *their* project only.
- The result is delegation, not a bottleneck. Every tech lead runs their own
  project through the same dev → staging → production order, on their own
  timeline, without needing the account admin to click anything — and without
  being able to touch any other team's project.
- The migration dashboard tracks readiness per project for exactly this
  reason: "the account is upgraded" is meaningless. "Project X is upgraded" is
  the unit that matters, and it's the unit this permission is scoped to.

## Job-level version overrides

An environment's dbt version is the default for every job in it, applied on
each job's next run. For a project with one or two jobs that's the whole
story. For a project with thirty jobs of varying blast radius, that default is
too blunt in both directions:

- **Canary a job ahead of the environment.** Override one low-risk job to v2
  before flipping the environment, to get a real signal from a real schedule
  without exposing every other job.
- **Hold one job back.** If a fragile job needs more time after the
  environment has already moved to v2, override just that job back to v1
  while everything else runs on the new default.
- **Clean up afterward.** Once you trust the environment on v2, go back and
  remove the overrides. A job override is meant to be temporary; left in
  place, it's silent drift — the project looks upgraded on the dashboard while
  one job quietly still isn't, which is exactly the "job pinned to an older
  version is not running v2" trap from Module 5.

## The developer escape hatch

Upgrading the development environment to v2 is a team decision. Whether any
one developer's next command runs on v2 does not have to be.

If a developer is blocked by something that isn't fixed yet and needs to ship,
they can override their own IDE session or job back to v1 without touching the
environment setting, and without affecting anyone else's session. It's narrow
and personal on purpose: it unblocks one person for one task. It does not roll
back the team's environment, and it should not be read as a signal about the
project's real readiness — the environment setting and the migration
dashboard stay the source of truth for that.

## Takeaways

- Cloning production into staging via `dbt clone` + `--defer --state` gets you
  a full, cheap, end-to-end v2 validation on day one, before you flip staging's
  real environment version — not instead of the standard monitoring period.
- Multi-project rollout is a permissions problem, not a staffing problem:
  scope **v2 Migration Admin** per project to each project's tech lead and let
  them run their own dev → staging → production sequence.
- Job-level version overrides let one job move ahead of or lag behind its
  environment's default — canary a job early, hold a fragile one back, and
  remove the override once it's no longer doing either.
- A developer overriding their own session back to v1 is a personal escape
  hatch, not a rollback — it unblocks one task without changing what the
  environment or the migration dashboard say is true.
