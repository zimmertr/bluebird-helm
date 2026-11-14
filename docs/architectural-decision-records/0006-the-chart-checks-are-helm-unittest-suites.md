# 0006. The chart's checks are helm-unittest suites that pin the edge routes, and the edge 404 comparison and the route walk are dropped

- Status: Accepted. Supersedes 0002. Supersedes 0005 in part: the renders and walks in the chart module's `test` input, and `edge-404.yml`.
- Date: 2026-11-13
- Decider: TJ, 2026-11-13: helm-unittest for every chart (zimmertr/yggdrasil record 0060, on hevy-garmin-sync#67), then, on #513, the rendered routes pinned by helm-unittest here, and the 404 comparison and the route walk dropped under KISS and YAGNI.
- Issues and PRs: #513, zimmertr/yggdrasil#113, hevy-garmin-sync#67
- Cited in code as: record 0006, in `.github/workflows/pr.yml`, `charts/bluebird/templates/virtualservice.yaml` and `charts/bluebird/tests/`
- Guide: [`CLAUDE.md`](../../CLAUDE.md), Rules, "The chart's checks are helm-unittest suites"

## Context

yggdrasil record 0060 makes a chart's checks helm-unittest suites and deprecates the chart module's `test` input. That input held this repo's stable and preview renders and the walk of request shapes through the rendered routes, and `edge-404.yml` used it to compare the gateway's 404 with Bluebird's `backend/edge_not_found.json` (records [0002](0002-the-edge-checks-stay-this-repos-own.md), [0005](0005-the-chart-goes-through-yggdrasils-modules.md)). helm-unittest renders the chart and checks the documents. It can't send a request through a VirtualService's routes, and it can't read another repo's file.

## Decision

- The stable and preview renders are `charts/bluebird/tests/scenarios_test.yaml`.
- The VirtualService's routes are pinned whole, without the tunnel in `virtualservice_test.yaml` and with `ingress.tunnel.peerRegex` set in `virtualservice_tunnel_test.yaml`: the names in order, each route's matches, its destinations or its 404 answer and headers, and which routes remove CF-Connecting-IP. Any change to a route fails `Chart / Chart` until the suite says the same.
- The route walk (`.github/scripts/check_edge_routes.py`) and the 404 comparison (`edge-404.yml`) are deleted, and nothing replaces them, here or in Bluebird.
- `pr.yml` passes the chart module no `test`.

## Evidence

- 2026-11-13: helm-unittest 1.2.1's assertions compare rendered documents with values or snapshots. None evaluates a request against Istio's route matching, which record 0002 also found on 2026-11-06.
- 2026-11-13: the pod refuses a `%2F` anywhere in a path itself, with backend tests (bluebird record 0096), so the request shape bluebird#620 found doesn't depend on the edge rules alone.

## Alternatives rejected

- Moving the walk and the 404 comparison into Bluebird's tests, TJ's first choice on 2026-11-13: more code to keep for little gain. A 404 copy that drifts from the app's is cosmetic: a caller of an unpublished path gets a slightly different body. And the shape the walk exists for is refused by the pod and frozen in the suites.
- Keeping the walk in `test`: shell in an input yggdrasil deprecates and will remove.
- `matchSnapshot` for the routes: the expected routes would sit in a generated `__snapshot__` file, away from the test that names them, and helm-unittest writes a missing snapshot and passes, so a deleted one fails nothing.

## Consequences

- A route change edits the template and its pinned route in the same PR, so no rule changes out of view.
- No test says where each request shape lands after a rule changes. The reviewer reasons about it.
- A change to the app's 404 body or headers is copied into the template and the suites by hand, and nothing says when they lag.
