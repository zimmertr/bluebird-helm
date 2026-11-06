# bluebird-helm

Helm chart for [Bluebird](https://github.com/zimmertr/bluebird), published as an OCI artifact to Docker Hub.

- **Chart:** [`charts/bluebird`](./charts/bluebird) — see its [README](./charts/bluebird/README.md) for values and usage.
- **OCI location:** `oci://registry-1.docker.io/zimmertr/bluebird-helm`

## Release process

| Event | Action |
|---|---|
| Merge to `main` | [yggdrasil](https://github.com/zimmertr/yggdrasil)'s release module runs GitVersion, which computes a SemVer from the squash commit's title (the PR title) alone: `!` before the colon is a major, `feat` a minor, every other prefix a patch, and a `BREAKING CHANGE:` footer in the body counts for nothing. The module creates the `v<semver>` git tag + GitHub release, then the chart is packaged and `helm push`ed to the OCI repo under that version. A re-run skips a chart that is already pushed, so it finishes a failed release. |
| Manual run (`workflow_dispatch`) | The same release, from `main` only: every job checks the ref, so a run started from another branch publishes nothing and opens no bump. |
| Pull request title | The `PR Title / PR Title` check (yggdrasil's pr-title module) fails a title the release can't read. It runs on every PR, forks included, and again when the title is edited. |
| Dependabot PR | A patch or minor update merges itself once the required checks pass (yggdrasil's auto-merge module). Majors wait for review. |

The chart goes to 1.0 with the app, and only by a PR here whose title carries `!`. Merge it after the app's 1.0.0 has released and its automatic `chore(release): bump chart appVersion to 1.0.0` PR has merged: that PR has no `!`, so it releases a chart patch whose default image is the app's 1.0.0, and the `!` PR after it releases chart 1.0.0 with the same default. The `!` PR must change a file under `charts/**`, or no chart release runs. Merged before the app's 1.0.0, it would give chart 1.0.0 a pre-1.0 default image, and the automatic PR would then release chart 1.0.1.

Every action in the workflows is pinned to a full commit SHA with its version in a comment, and Dependabot moves the pins by PR (`.github/dependabot.yml`). Helm is pinned to an exact version in the workflows themselves, where Dependabot does not look, and moves by hand (bluebird#632).

The full flow, the bump table, the release credentials and how to finish a failed release are in [bluebird's `docs/CICD.md`](https://github.com/zimmertr/bluebird/blob/main/docs/CICD.md).

Consuming repos (e.g. `Kubernetes-Manifests`) pin a chart `version`/`targetRevision`: the latest SemVer, written by this repo's release.
