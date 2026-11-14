# 0002. The edge 404 comparison and the route walk stay this repo's own checks

- Status: Accepted. Superseded in part by 0006: the route walk in `Chart / Chart`.
- Date: 2026-11-06
- Decider: TJ, 2026-11-06, on zimmertr/yggdrasil#7 step 5.5's plan ("Continue")
- Issues and PRs: zimmertr/yggdrasil#7, bluebird#565, bluebird#620, bluebird#631
- Cited in code as: none
- Guide: [`CLAUDE.md`](../../CLAUDE.md), Rules

## Context

zimmertr/yggdrasil#7 asked for a tool to replace any custom check before keeping it. This repo has two: `edge-404.yml` compares the gateway's rendered 404 with Bluebird's `backend/edge_not_found.json` (bluebird#565), and `.github/scripts/check_edge_routes.py` walks request shapes through the rendered VirtualService to check which route answers each (bluebird#620, #631).

## Decision

Both stay. `edge-404.yml` is `helm template`, `yq`, `jq` and `diff`. The route walk stays in `Lint & render`, where it blocks a PR, and in `edge-404.yml`, where it reports on `main`.

## Evidence

- 2026-11-06: a web search found no tool that tells offline which Istio route a request matches. `istioctl analyze --use-kube=false` validates the files without saying which route a request takes, and `istioctl proxy-config routes` needs a running cluster.
- 2026-11-06: the Helm test tools found (helm-unittest, conftest, testchart) compare a render with values or snapshots kept in this repo. None reads a file from another repo, which the 404 comparison does.

## Alternatives rejected

- helm-unittest snapshots for the 404: the expected body would be a copy kept here, which is the drift bluebird#565 fixed.

## Consequences

The route walk models the parts of Envoy's matching the chart uses. A new kind of match in the chart needs the walk taught it too.
