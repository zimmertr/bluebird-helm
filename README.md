# bluebird-helm

Helm chart for [Bluebird](https://github.com/zimmertr/bluebird), published as an OCI artifact to Docker Hub and indexed on [Artifact Hub](https://artifacthub.io).

- **Chart:** [`charts/bluebird`](./charts/bluebird) — see its [README](./charts/bluebird/README.md) for values and usage.
- **OCI location:** `oci://registry-1.docker.io/zimmertr/bluebird-helm`

## Release process

| Event | Action |
|---|---|
| Merge to `main` | GitVersion computes a SemVer from the squash commit's title (the PR title) alone: `!` before the colon is a major, `feat` a minor, every other prefix a patch, and a `BREAKING CHANGE:` footer in the body counts for nothing. The chart is packaged and `helm push`ed to the OCI repo; a `v<semver>` git tag + GitHub release are created. Each of the three is made only when missing, so a re-run of a failed release finishes it. When the merge changed `artifacthub-repo.yml` (or on a manual run), a separate job then pushes it via ORAS to the OCI repo's `artifacthub.io` tag, so a failed metadata push never blocks a release. |
| Pull request title | The `PR Title` check fails a title that none of `GitVersion.yml`'s patterns reads. It runs on every PR, forks included, and again when the title is edited. |
| Pull request (same-repo) | A **prerelease** chart `X.Y.Z-pr<n>.g<sha>` is packaged and pushed to the same OCI repo, so a preview can be pinned manually. The `ignore` entry in `artifacthub-repo.yml` keeps these versions off Artifact Hub. |

The chart goes to 1.0 with the app, and only by a PR here whose title carries `!`. Merge it after the app's 1.0.0 has released and its automatic `chore(release): bump chart appVersion to 1.0.0` PR has merged: that PR has no `!`, so it releases a chart patch whose default image is the app's 1.0.0, and the `!` PR after it releases chart 1.0.0 with the same default. The `!` PR must change a file under `charts/**` (or `artifacthub-repo.yml`), or no chart release runs. Merged before the app's 1.0.0, it would give chart 1.0.0 a pre-1.0 default image, and the automatic PR would then release chart 1.0.1.

The full flow, the bump table and how to finish a failed release are in [bluebird's `docs/CICD.md`](https://github.com/zimmertr/bluebird/blob/main/docs/CICD.md).

Consuming repos (e.g. `Kubernetes-Manifests`) pin a chart `version`/`targetRevision` — normally the latest SemVer, occasionally a prerelease.
