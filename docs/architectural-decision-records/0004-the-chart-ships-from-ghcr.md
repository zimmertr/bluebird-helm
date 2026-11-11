# 0004. The chart ships from GHCR

- Status: Accepted. Supersedes 0003 in part: the registry.
- Date: 2026-11-11
- Decider: TJ, 2026-11-11, while working zimmertr/yggdrasil#9: "Can we just move Bluebird/Bluebird Helm to GHCR right now to close out yggrasil #9", then "Yes, lets just do it now. The organzation move will happen later."
- Issues and PRs: zimmertr/bluebird#111, zimmertr/yggdrasil#9, this PR
- Cited in code as: none
- Guide: [`CLAUDE.md`](../../CLAUDE.md); zimmertr/bluebird's `docs/CICD.md`, Path 2 and its record 0280

## Context

Bluebird's images move from Docker Hub to `ghcr.io/zimmertr/...` (zimmertr/bluebird record 0280). The chart named them as its defaults and was itself pushed to Docker Hub with a long-lived token. yggdrasil's release module at v1.0.0 drops its Docker Hub inputs and asks every caller for `packages: write`.

## Decision

- `release.yml` pushes the chart to `oci://ghcr.io/zimmertr/bluebird-helm` with the job's own `GITHUB_TOKEN`, and checks GHCR for a version already pushed. `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are deleted.
- The chart's defaults are `ghcr.io/zimmertr/bluebird` and `ghcr.io/zimmertr/bluebird-fill`.
- Charts already on Docker Hub stay there. They name the Docker Hub images, which stay too.
- The chart moves again, to the `Bluebird-Forecast` organization's namespace, with zimmertr/bluebird#311.

## Evidence

- 2026-11-10, zimmertr/yggdrasil#73: `GITHUB_TOKEN` with `packages: write` pushed a chart to GHCR, and the new package started public.
- 2026-11-11: hevy-garmin-sync's chart ships from `oci://ghcr.io/zimmertr` the same way, and Kubernetes-Manifests pulls it.

## Alternatives rejected

- Waiting for zimmertr/bluebird#311 so the chart moves once: Docker Hub's credentials stay until then, with no date set.

## Consequences

- The first chart release from GHCR resolves `appVersion` from Bluebird's latest release, which is still a Docker Hub-only version until Bluebird's own GHCR PR releases. Nothing installs that chart; Kubernetes-Manifests moves to the one after it.
