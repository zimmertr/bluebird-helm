# 0005. The chart is checked, pushed and deployed by yggdrasil's modules, with the `appVersion` in `Chart.yaml`

- Status: Accepted. Supersedes 0001 in part: the `chart` and `bump-manifests` jobs. Superseded in part by 0006: the renders and walks in the `test` input.
- Date: 2026-11-11
- Decider: TJ, 2026-11-11, on zimmertr/yggdrasil#74: "C", the release module pushing the chart itself, then "LGTM" to zimmertr/yggdrasil#82.
- Issues and PRs: zimmertr/yggdrasil#74, #471
- Cited in code as: decision record 0005, in `.github/workflows/pr.yml`, `release.yml` and `edge-404.yml`
- Guide: [`CLAUDE.md`](../../CLAUDE.md), Rules

## Context

0001 kept the chart push and the Kubernetes-Manifests bumps in this repo, because yggdrasil's release module opened its deploy bumps before a chart could exist. It rejected a `charts` input as a feature for one repo. hevy-garmin-sync then copied all three chart jobs from here, and yggdrasil v1.1.0 took them in (its record 0054).

## Decision

- On a PR, the `Chart` job calls yggdrasil's `chart.yml`. The stable and preview renders and both route walks go in its `test` input, and the module's default render is the portable scenario. The required check is `Chart / Chart`, where it was `Lint & render`.
- On main, the release module gets `charts` and `deploys`. It pushes the chart after the tag, then opens the preview and stable bumps. The `chart` and `bump-manifests` jobs are deleted.
- The chart ships with the `appVersion` in `Chart.yaml`. The release no longer reads Bluebird's latest release as it packages.
- `edge-404.yml` calls `chart.yml` too, so no workflow here installs Helm. The comparison and the route walk are still this repo's own (record [0002](0002-the-edge-checks-stay-this-repos-own.md)).

## Evidence

- 2026-11-11: Bluebird's release sets `appVersion` in `Chart.yaml` through its `chore(release): bump chart appVersion` PR, and that PR's merge is what releases the chart. `Chart.yaml` said 0.132.38 that day, Bluebird's latest release.
- 2026-11-11, in Docker with Helm v4.3.0: `helm package --dependency-update` fetched the database subchart with no `helm repo add`.
- 2026-11-11: hevy-garmin-sync's v0.7.1 release pushed its chart and opened its Kubernetes-Manifests PR through the module.

## Alternatives rejected

- Keeping the `appVersion` lookup as a module input: it only repeats what Bluebird's PR already wrote.
- Leaving `edge-404.yml` on its own Helm: its render could then differ from the one the release packages.

## Consequences

- A chart released between a Bluebird release and its `appVersion` PR carries the earlier `appVersion`, a published tag. The PR's own merge releases the chart again.
- A failed chart push is finished with "Re-run failed jobs". "Re-run all jobs" finds the tag and pushes nothing, where this repo's own job would have pushed.
- The two bump jobs share one name, `Release / Deploy Bump (zimmertr/Kubernetes-Manifests)`. Each job's log names its file.
