# ⚡ Upgrading to dbt Core v2

Welcome to the **Summit 2026 Upgrading to dbt v2 Training**! This training repository provides hands-on experience upgrading from **dbt Core <v2.0 to dbt v2+**. Below you'll find useful links and information to following along in your own sandbox.

## Workshop Account Setup

Use this link: [https://workshops.us1.dbt.com/workshop](https://workshops.us1.dbt.com/workshop)
<br>
Find the course by name: Upgrading to dbt v2
<br>
Passcode `Summit2026!`

## The lab

Work through the modules in order. Each one maps to a gate in the upgrade flow:

| Module | Gate |
|---|---|
| [0 — Setup and context](lab/00-setup.md) | — |
| [1 — Parse and deprecations](lab/01-parse-and-deprecations.md) | `dbt parse` |
| [1b — Macro argument types](lab/01b-macro-argument-types.md) | `dbt parse` warnings |
| [2 — Compile with analysis off](lab/02-compile-static-analysis-off.md) | `--static-analysis off` |
| [3 — Baseline and strict](lab/03-baseline-and-strict.md) | `baseline` / `strict` |
| [3b — Dynamic SQL and introspection](lab/03b-dynamic-sql-and-introspection.md) | `strict`, `--no-introspect` |
| [4 — Run, build, and state](lab/04-run-build-and-state.md) | `dbt build`, `state:` |
| [5 — Deferral and rollout](lab/05-deferral-and-rollout.md) | manifests, deferral |

## Helpful Links

- Google Slides: [https://docs.google.com/presentation/d/1mGREYqR_SCkWQh6vfjtmjAtRP8xdt83Ky6dHBw2Fu44/edit?usp=sharing](https://docs.google.com/presentation/d/1mGREYqR_SCkWQh6vfjtmjAtRP8xdt83Ky6dHBw2Fu44/edit?usp=sharing)
- Demo Repository: [https://github.com/dbt-labs/dbt-summit-26-Upgrading-to-dbt-v2](https://github.com/dbt-labs/dbt-summit-26-Upgrading-to-dbt-v2)

## Getting your project compiling

If you're not able to get your project to compile by the end of the hands-on portion, you may switch to use our branch that contains all fixes needed to compile so you can continue.

## After the Training

Try it out on your own project at home!

You'll have access to the workshop account for 7 days if you need to go back and remember anything you did during this exercise.

## Survey

Please use [this link](https://tinyurl.com/dbt-summit-survey) to give feedback on the training!
