# 0003. The chart is not listed on Artifact Hub

- Status: Accepted. Supersedes the `ignore` entry in 0001. Superseded in part by 0004: the chart is on GHCR.
- Date: 2026-11-06
- Decider: TJ, 2026-11-06: "Maybe we just stop using ArtifactHub?", then "Yes. Lets completely drop it"
- Issues and PRs: zimmertr/yggdrasil#7
- Cited in code as: none
- Guide: [`CLAUDE.md`](../../CLAUDE.md)

## Context

Artifact Hub listed the chart from its OCI repo on Docker Hub, and read the repo's metadata (owner, verified publisher, the `ignore` list) from the `artifacthub.io` tag in that repo. Updating the metadata means pushing to that tag again. The Docker Hub repo's tags are immutable, on purpose, so the push can never succeed again.

## Decision

The chart is published to Docker Hub only. `artifacthub-repo.yml`, the `artifacthub-metadata` job and the `artifacthub.io/*` annotations in `Chart.yaml` are gone. Nothing TJ runs reads Artifact Hub: Kubernetes-Manifests pulls the chart from Docker Hub.

## Evidence

- 2026-11-06: the release of v0.18.27 pushed the chart, then the metadata push failed: "tag artifacthub.io is already assigned to an image in this repository and cannot be updated due to immutability settings."

## Alternatives rejected

- An immutability exception for the `artifacthub.io` tag: TJ keeps immutability as it is.
- Keeping the listing and deleting only the job: the metadata could never change again, and nothing TJ runs needs the listing.

## Consequences

People who don't already know the chart can't find it on Artifact Hub. Anyone installing it from `oci://registry-1.docker.io/zimmertr/bluebird-helm` is unaffected.
