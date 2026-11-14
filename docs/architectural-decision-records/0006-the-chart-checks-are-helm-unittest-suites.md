# 0006. The chart's checks are helm-unittest suites that pin the edge routes, and the request walk moves to Bluebird

- Status: Accepted. Supersedes 0002 in part: the route walk in `Chart / Chart`. Supersedes 0005 in part: the renders and walks in the chart module's `test` input.
- Date: 2026-11-13
- Decider: TJ, 2026-11-13: helm-unittest for every chart (zimmertr/yggdrasil record 0060, on hevy-garmin-sync#67), then, for the route walk on #513, both of: the rendered routes pinned by helm-unittest here, and the walk moved into Bluebird's own tests.
- Issues and PRs: #513, zimmertr/yggdrasil#113, hevy-garmin-sync#67
- Cited in code as: record 0006, in `.github/workflows/pr.yml` and `charts/bluebird/tests/`
- Guide: [`CLAUDE.md`](../../CLAUDE.md), Rules, "The chart's checks are helm-unittest suites"

## Context

yggdrasil record 0060 makes a chart's checks helm-unittest suites and deprecates the chart module's `test` input. That input held this repo's stable and preview renders and both route walks (record [0005](0005-the-chart-goes-through-yggdrasils-modules.md)). helm-unittest renders the chart and checks the documents. It can't send a request through a VirtualService's routes, which is what `.github/scripts/check_edge_routes.py` does.

## Decision

- The stable and preview renders are `charts/bluebird/tests/scenarios_test.yaml`.
- The VirtualService's routes are pinned whole, without the tunnel in `virtualservice_test.yaml` and with `ingress.tunnel.peerRegex` set in `virtualservice_tunnel_test.yaml`: the names in order, each route's matches, its destinations or its 404 answer, and which routes remove CF-Connecting-IP. Any change to a route fails `Chart / Chart` until the suite says the same.
- The walk of request shapes through the routes moves into Bluebird's own tests. Until those land, `edge-404.yml` runs it here, where it reports and does not block. Its 404 comparison moves to Bluebird too (#513).
- `pr.yml` passes the chart module no `test`.

## Evidence

- 2026-11-13: helm-unittest 1.2.1's assertions compare rendered documents with values or snapshots. None evaluates a request against Istio's route matching, which record 0002 also found on 2026-11-06.

## Alternatives rejected

- `matchSnapshot` for the routes: the expected routes would sit in a generated `__snapshot__` file, away from the test that names them, and helm-unittest writes a missing snapshot and passes, so a deleted one fails nothing.
- Keeping the walk in `test`: shell in an input yggdrasil deprecates and will remove.

## Consequences

- A route change edits the template and its pinned route in the same PR. The pin says what changed; Bluebird's walk says which requests now land elsewhere.
- The 404 route's response headers aren't pinned here, because `edge-404.yml` compares them with the app's `backend/edge_not_found.json`.
- Until Bluebird's walk lands, a route change that moves a request shape blocks nothing here: `Edge 404` shows red without stopping the merge.
