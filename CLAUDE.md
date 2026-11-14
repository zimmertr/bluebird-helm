# bluebird-helm

The Helm chart for zimmertr/bluebird (`charts/bluebird`), published as an OCI artifact to GHCR. The chart's values are in [`charts/bluebird/README.md`](charts/bluebird/README.md); the full release flow is in zimmertr/bluebird's `docs/CICD.md`.

This repo took a trimmed set of the files a new project starts with (zimmertr/yggdrasil record 0038). When a change here makes a decision, write its record in [`docs/architectural-decision-records/`](docs/architectural-decision-records/README.md); when it needs a `docs/` page, add it in the same PR.

## Rules

- **A merge to `main` that changes `charts/**` is a release.** yggdrasil's release module tags it from the PR title, pushes the chart, then opens self-merging bumps in Kubernetes-Manifests. Records: [0001](docs/architectural-decision-records/0001-yggdrasil-tags-the-release-and-this-repo-pushes-the-chart.md), [0005](docs/architectural-decision-records/0005-the-chart-goes-through-yggdrasils-modules.md)
- **The chart's checks are helm-unittest suites.** `Chart / Chart` runs `charts/bluebird/tests/` through yggdrasil's chart module: the stable and preview scenarios, and the edge routes pinned whole with and without the tunnel, so a route change fails until its suite says the same. Nothing walks request shapes through the routes or compares the gateway's 404 with the app's: the reviewer of a route change reasons about where each request lands. Never write shell assertions for the chart; a check helm-unittest can't hold goes to TJ first. Record: [0006](docs/architectural-decision-records/0006-the-chart-checks-are-helm-unittest-suites.md)
- **`appVersion` comes from Bluebird.** Bluebird's release bumps it here by PR, and the chart ships with what `Chart.yaml` says. Don't edit it by hand. Record: [0005](docs/architectural-decision-records/0005-the-chart-goes-through-yggdrasils-modules.md)
- **The README is TJ's.** Keep it accurate and in TJ's voice, and never restructure it. A value change updates `charts/bluebird/README.md` in the same PR.

## Issues

File issues with the `create-issue` skill from zimmertr/ai-config: the two-sentence summary, the six sections, the hemingway and humanizer passes, one priority, one type, the area labels and the session label. The skill reads the four things below from this section.

- **The reader**: someone who installs the chart and knows Helm and Kubernetes, but not Bluebird's code.
- **The gates**: `Chart / Chart`, `PR Title / PR Title` and the three `Lint /` checks pass; `charts/bluebird/README.md` changes with any value; the README changes only to stay accurate.
- **The constraints**: no secret values in the repo or in logs; a release must not break the stable app or the PR previews in Kubernetes-Manifests; the chart stays GPLv3.
- **The areas**: `chart` (the templates and values), `ci` (the workflows and Renovate), `security`.

## Working in this repo

- Work in a fresh clone in the session's scratchpad, never in TJ's checkout. Branch from the latest `origin/main`.
- Everything reaches main through a squash-merged PR. Never push to main.
- CI runs on zimmertr/yggdrasil's `pr-title`, `lint`, `chart` and `release` modules, pinned by commit SHA with the version beside it. Renovate bumps the pin as soon as a release ships.
- Actions are pinned to commit SHAs with the version in a comment. Helm's version is the one yggdrasil's modules install; no workflow here installs it.
