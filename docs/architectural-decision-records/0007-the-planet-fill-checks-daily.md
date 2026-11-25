# 0007. The planet fill checks daily, not weekly

- Status: Proposed, in the PR that makes it; accepted when TJ merges it.
- Date: 2026-11-25
- Decider: proposed for TJ by zimmertr/bluebird's reliability plan (`docs/RELIABILITY.md`, "A Fill That Starts Itself", zimmertr/bluebird#1001)
- Issues and PRs: zimmertr/bluebird#1001, zimmertr/bluebird#760
- Cited in code as: the comment above `fill:` in `charts/bluebird/values.yaml`
- Guide: [`charts/bluebird/README.md`](../../charts/bluebird/README.md), `fill.schedule`

## Context

The planet fill's CronJob ran weekly (zimmertr/bluebird#760, Bluebird record 0184). Each run checks the places table and exits within seconds when it was filled under the running release's rules, so the schedule only decides how long an empty table waits: a new database, a lost one, or a release that changed the rules waited up to a week, searching Overpass the whole time. Overpass answered 21 of 152 production requests over 30 days (measured 2026-11-25).

## Decision

`fill.schedule` is `17 9 * * *`, the same minute, every day. It stays a CronJob that creates its scratch volume, so a check costs one volume created and deleted a day. Hourly would churn a 120 GiB volume every hour. Faster than daily needs the check split from the fill (a small CronJob with no volume, allowed to create the fill's Job), which is not built.

## Consequences

- An empty or stale table searches Overpass for a day at most, plus the fill's own 80 minutes or so to the load.
- Six more scratch volumes a week are created and deleted. Each check that finds the table current downloads nothing.
