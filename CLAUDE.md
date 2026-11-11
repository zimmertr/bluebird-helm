# bluebird-helm

The Helm chart for zimmertr/bluebird (`charts/bluebird`), published as an OCI artifact to GHCR. The chart's values are in [`charts/bluebird/README.md`](charts/bluebird/README.md); the full release flow is in zimmertr/bluebird's `docs/CICD.md`.

This repo took a trimmed set of the files a new project starts with (zimmertr/yggdrasil record 0038). When a change here makes a decision, write its record in [`docs/architectural-decision-records/`](docs/architectural-decision-records/README.md); when it needs a `docs/` page, add it in the same PR.

## Rules

- **A merge to `main` that changes `charts/**` is a release.** yggdrasil's release module tags it from the PR title, then `release.yml` pushes the chart and opens self-merging bumps in Kubernetes-Manifests. Record: [0001](docs/architectural-decision-records/0001-yggdrasil-tags-the-release-and-this-repo-pushes-the-chart.md)
- **The edge routes are tested here.** `Lint & render` walks request shapes through the rendered routes and blocks a PR on a wrong route; `edge-404.yml` compares the gateway's 404 with Bluebird's and only reports. A new kind of route match needs the walk taught it. Record: [0002](docs/architectural-decision-records/0002-the-edge-checks-stay-this-repos-own.md)
- **`appVersion` comes from Bluebird.** Bluebird's release bumps it here by PR, and the release resolves it again from Bluebird's latest release. Don't edit it by hand.
- **The README is TJ's.** Keep it accurate and in TJ's voice, and never restructure it. A value change updates `charts/bluebird/README.md` in the same PR.

## Issues

File issues with the `create-issue` skill from zimmertr/ai-config: the two-sentence summary, the six sections, the hemingway and humanizer passes, one priority, one type, the area labels and the session label. The skill reads the four things below from this section.

- **The reader**: someone who installs the chart and knows Helm and Kubernetes, but not Bluebird's code.
- **The gates**: `Lint & render`, `PR Title / PR Title` and the three `Lint /` checks pass; `charts/bluebird/README.md` changes with any value; the README changes only to stay accurate.
- **The constraints**: no secret values in the repo or in logs; a release must not break the stable app or the PR previews in Kubernetes-Manifests; the chart stays GPLv3.
- **The areas**: `chart` (the templates and values), `ci` (the workflows and Dependabot), `security`.

## Working in this repo

- Work in a fresh clone in the session's scratchpad, never in TJ's checkout. Branch from the latest `origin/main`.
- Everything reaches main through a squash-merged PR. Never push to main.
- CI runs on zimmertr/yggdrasil's `pr-title`, `lint`, `auto-merge` and `release` modules, pinned by commit SHA with the version beside it. Dependabot bumps the pin, three days after a release.
- Actions are pinned to commit SHAs with the version in a comment. Helm is pinned in the workflows and moves by hand.
