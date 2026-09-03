# Module 5 — Deferral, manifests, and rollout

**Gate:** other environments can consume the artifacts your project produces.

## The one-character break

Check out the branch that has it applied:

```bash
git checkout exercise/05-broken-deferral
git diff main -- dbt_project.yml
```

```diff
       compliance:
         +materialized: audit_table
-        +static_analysis: 'off'
+        # Tidied up during the upgrade -- the quotes looked redundant.
+        +static_analysis: off
```

Someone removed a pair of quotes during the upgrade. In YAML, unquoted `off` is
a **boolean**, not the string `off`.

## Watch how long it stays invisible

```bash
dbt parse --no-partial-parse       # dbt Core
```

Silent.

```bash
dbt build --select fct_regulated_potion_sales      # dbt Core
Done. PASS=1 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=1
```

Green.

```bash
dbt parse       # dbt Core v2
Finished 'parse' successfully for target 'dev'
```

Also clean. Four checks, no complaints.

Now look at what actually landed in the manifest:

```bash
python3 -c "
import json; m=json.load(open('target/manifest.json'))
print([v['config'].get('static_analysis') for k,v in m['nodes'].items() if 'regulated' in k][0])"
```

```
False
```

Not `'off'`. The boolean `False`.

## Where it surfaces

The failure appears when a *different* run tries to defer to that manifest:

```bash
cp target/manifest.json state/manifest.json
dbt compile --defer --state state --select fct_regulated_potion_sales
```

```
[error] [ManifestLoadFailed (dbt1150)]: Failed to load manifest.json from state
  path 'state': YAML error: nodes:
  nodes.model.merlinco_apothecaries.fct_regulated_potion_sales.config
  .static_analysis: invalid type: boolean `false`, expected a Value::Tagged enum
```

The project is green in isolation and only breaks once something downstream
consumes what it produced. Restore the quotes and it loads.

!!! tip "The general lesson"
    The manifest is an artifact other environments depend on. A config that
    serializes wrongly is not caught by parsing your own project — you have to
    either read the manifest or have something consume it. When you see
    `dbt1150`, check the config value it names against what is actually in the
    JSON.

## Other deferral failures

**Wrong or missing state path.** Point `--state` somewhere that does not exist:

```bash
dbt compile --defer --state state_does_not_exist --select fct_regulated_potion_sales
```

```
Finished 'compile' successfully for target 'dev'
```

It **succeeds**. There is no error and no warning — deferral silently does not
happen. A typo in a state path does not announce itself; you find out when a
model resolves against the wrong relation. Verify your state path is being
picked up rather than assuming.

**404 / `dbt1203` on a downloaded manifest.** On the dbt platform, the manifest
is fetched rather than read from disk. That fails when:

- the referenced environment or job has never produced a manifest
- deferral points at a **CI job** — CI does not update the state artifact used
  for deferral, so it must be a scheduled or manual production deploy job
- egress is blocked. One reported case had the pre-signed URL return fine while
  the blob storage `GET` was blocked by a corporate proxy. Symptom is a network
  failure at download, not a dbt config problem.

**Malformed docs in the upstream project.** A doc block without a name breaks
the manifest for whoever reads it. This project keeps its doc blocks named in
`models/_merlinco__docs.md`; if you want to see the failure, remove a name and
regenerate.

## Rollout strategy

One asymmetry drives the whole plan:

> dbt Core v2 can read dbt Core manifests. dbt Core cannot reliably read dbt
> Core v2 manifests.

Deferral flows from upper environments down. If production runs dbt Core and
development runs dbt Core v2, development can defer to production. Flip it and
your dbt Core environments cannot read what production now writes.

So the migration order is forced:

```
1. One developer, personal environment          -- blast radius of one person
2. The project's development environment        -- let the team work a sprint
3. Upper environments, once the team is comfortable
```

Additional points worth making explicit:

- Upgrade is **per project**, not per account. The Migration UI tracks it at
  project level and supersedes the older Readiness UI.
- **A job pinned to an older dbt version or a non-v2 image is not running dbt
  Core v2**, even if the project passed every migration check. Check your job
  configuration, not just the project status.
- Consider restricting who can upgrade to a Fusion Admin role if your account
  mixes conformant and non-conformant projects.
- Introduce state-aware orchestration as a **separate step** after the project
  compiles cleanly. `force-node-selection` remains on by default for
  compatibility. Do not change engines and orchestration behavior at once.
- Conformance dashboards are diagnostic, not verdicts. A conformance failure can
  come from harness or analytics limits rather than your code.

## Takeaways

- A config can be silently wrong locally and only fail for a downstream consumer.
- A bad `--state` path fails silently — confirm deferral is actually happening.
- Deferral must point at a production deploy job, not CI.
- Manifest compatibility is one-directional, which forces dev-first rollout.
- Migrate the engine and the orchestration model in separate steps.

**Exercise branch:** `exercise/05-broken-deferral`
