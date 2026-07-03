# bluebird-helm

Helm chart for [Bluebird](https://github.com/zimmertr/bluebird), published as an OCI artifact to Docker Hub and indexed on [Artifact Hub](https://artifacthub.io).

- **Chart:** [`charts/bluebird`](./charts/bluebird) — see its [README](./charts/bluebird/README.md) for values and usage.
- **OCI location:** `oci://registry-1.docker.io/zimmertr/bluebird-helm`

## Release process

| Event | Action |
|---|---|
| Merge to `main` | GitVersion computes a SemVer; the chart is packaged and `helm push`ed to the OCI repo; `artifacthub-repo.yml` is refreshed via ORAS; a `v<semver>` git tag + GitHub release are created. |
| Pull request (same-repo) | A **prerelease** chart `X.Y.Z-pr<n>.g<sha>` is packaged and pushed to the same OCI repo, so a preview can be pinned manually. |

Consuming repos (e.g. `Kubernetes-Manifests`) pin a chart `version`/`targetRevision` — normally the latest SemVer, occasionally a prerelease.
