# 0001. yggdrasil's release module tags the release, then this repo pushes the chart and opens the deploy bumps; PRs publish no chart

- Status: Accepted. Its `ignore` entry is superseded by 0003, and its `chart` and `bump-manifests` jobs by 0005.
- Date: 2026-11-06
- Decider: TJ, 2026-11-06, on zimmertr/yggdrasil#7 step 5.5: "1: A" and, on the PR charts, "Yup, drop them. Unless they are somehow invovled in pr containers/preview environments"
- Issues and PRs: zimmertr/yggdrasil#7
- Cited in code as: decision record 0001, in `.github/workflows/release.yml` and `artifacthub-repo.yml`
- Guide: [`CLAUDE.md`](../../CLAUDE.md), Rules

## Context

TJ's repos release through yggdrasil's reusable `release` module, pinned by commit SHA. The module works out the version, tags and releases, then opens its deploy bumps straight away. A chart release needs its chart on Docker Hub before the Kubernetes-Manifests bumps open, because their `Validate manifests` check renders the new version. The module has no step for a chart between the release and the bumps. Each same-repo PR also pushed a prerelease chart, versioned by this repo's own `GitVersion.yml`.

## Decision

- `release.yml` calls the module for the version, the `v<semver>` tag and the GitHub release, with the module's default GitVersion patterns. `GitVersion.yml` is gone.
- The `chart` job then pushes the chart for the tag on that commit. A commit with no tag pushes nothing, and a chart already on Docker Hub is not pushed again, so a re-run finishes a failed release.
- `bump-manifests` then points the preview ApplicationSet and the stable app at the chart: the module's deploy job, copied here so it runs after the push (`yq`, `peter-evans/create-pull-request`, auto-merge armed).
- PRs publish no chart. The `ignore` entry in `artifacthub-repo.yml` stays, because the old PR charts are still in the OCI repo.
- `pr-title.yml`, `lint.yml` and `dependabot-auto-merge.yml` call yggdrasil's `pr-title`, `lint` and `auto-merge` modules.

## Evidence

- 2026-11-06: GitVersion 6.8.2 in Docker, on a copy of `main` (tagged v0.18.26) with one `fix(chart):` commit added, gave 0.18.27 with this repo's `GitVersion.yml` and 0.18.27 with yggdrasil v0.9.2's `defaults/GitVersion.yml`.
- 2026-11-06: none of Kubernetes-Manifests' 1,368 commits under `public/bluebird` or `public/bluebird-pr` ever pinned a PR chart. The preview ApplicationSet pins the released chart (`targetRevision: 0.18.26`); a preview gets the PR's image, not a PR chart.
- 2026-11-06: `yq` 4.54.1 on copies of `public/bluebird-pr/applicationset.yml` and `public/bluebird/kustomization.yml` changed one line in each.

## Alternatives rejected

- A `charts` input in yggdrasil's release module: a new module feature for one repo, carrying Bluebird's `appVersion` lookup and the subchart fetch.
- PR charts named from the latest tag: nothing used them.

## Consequences

- The GitHub release exists a few seconds before its chart does.
- The bump job is a copy of the module's deploy job, so a fix to one is made by hand in the other.
- Bluebird's `docs/CICD.md`, which described the PR charts and this repo's own title check, needs the same change.
