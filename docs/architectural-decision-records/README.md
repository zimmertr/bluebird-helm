# Architectural decision records

One file for each decision: what was decided, when, who decided, and the evidence that settled it. A record sits beside the `CLAUDE.md` rule that states the decision today and does not replace it.

This folder started on 2026-11-06 (zimmertr/yggdrasil#7). Decisions made before then live in the commit history, in the comments beside the workflows, and in Bluebird's records (zimmertr/bluebird `docs/architectural-decision-records/`).

## Write a record

- Copy [`0000-template.md`](0000-template.md) to `NNNN-slug.md` with the next free number. Numbers have four digits and are never reused.
- The title is the decision, as one sentence.
- Take the date and the decider from the conversation or issue that settled it, quoting the decider where the words exist.
- Give every observation the date it was made.
- Link the record from its `CLAUDE.md` rule as ` Record: [NNNN](docs/architectural-decision-records/NNNN-slug.md)`.
- A decision ships in the same PR as its record.

## Supersede a record

A new record that reverses an old one says `Supersedes NNNN` in its status line. The old record changes its status line to `Superseded by NNNN` and nothing else.

## Index

| Record | Decision | Date | Status |
|---|---|---|---|
| [0001](0001-yggdrasil-tags-the-release-and-this-repo-pushes-the-chart.md) | yggdrasil's release module tags the release, then this repo pushes the chart and opens the deploy bumps; PRs publish no chart | 2026-11-06 | Accepted; superseded in part by 0005 |
| [0002](0002-the-edge-checks-stay-this-repos-own.md) | The edge 404 comparison and the route walk stay this repo's own checks | 2026-11-06 | Accepted; superseded in part by 0006 |
| [0003](0003-the-chart-is-not-listed-on-artifact-hub.md) | The chart is not listed on Artifact Hub | 2026-11-06 | Accepted; superseded in part by 0004 |
| [0004](0004-the-chart-ships-from-ghcr.md) | The chart ships from GHCR | 2026-11-11 | Accepted |
| [0005](0005-the-chart-goes-through-yggdrasils-modules.md) | The chart is checked, pushed and deployed by yggdrasil's modules, with the `appVersion` in `Chart.yaml` | 2026-11-11 | Accepted; supersedes 0001 in part; superseded in part by 0006 |
| [0006](0006-the-chart-checks-are-helm-unittest-suites.md) | The chart's checks are helm-unittest suites that pin the edge routes, and the request walk moves to Bluebird | 2026-11-13 | Accepted; supersedes 0002 and 0005 in part |
