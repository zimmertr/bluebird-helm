# bluebird-helm

Helm chart for [Bluebird](https://github.com/zimmertr/bluebird), published as an OCI artifact to Docker Hub and indexed on [Artifact Hub](https://artifacthub.io).

- **Chart:** [`charts/bluebird`](./charts/bluebird) — see its [README](./charts/bluebird/README.md) for values and usage.
- **OCI location:** `oci://registry-1.docker.io/zimmertr/bluebird-helm`

## Release process

| Event | Action |
|---|---|
| Merge to `main` | GitVersion computes a SemVer; the chart is packaged and `helm push`ed to the OCI repo; a `v<semver>` git tag + GitHub release are created. When the merge changed `artifacthub-repo.yml` (or on a manual run), a separate job then pushes it via ORAS to the OCI repo's `artifacthub.io` tag, so a failed metadata push never blocks a release. |
| Pull request (same-repo) | A **prerelease** chart `X.Y.Z-pr<n>.g<sha>` is packaged and pushed to the same OCI repo, so a preview can be pinned manually. The `ignore` entry in `artifacthub-repo.yml` keeps these versions off Artifact Hub. |

Consuming repos (e.g. `Kubernetes-Manifests`) pin a chart `version`/`targetRevision` — normally the latest SemVer, occasionally a prerelease.
