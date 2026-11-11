# Contributing

Changes come through PRs that TJ reviews.

1. Branch from the latest `main`.
2. Make one change per PR, and title it `type(scope): summary`, such as `fix(chart): keep the canary's port`. The title decides the release: `!` before the colon is a major, `feat` a minor, anything else a patch.
3. Open the PR. `Chart / Chart` lints the chart, renders it in each scenario the cluster uses, and checks which route answers each request shape.
4. Change `charts/bluebird/README.md` in the same PR when a value changes, and add a decision record when the PR makes a decision ([docs/architectural-decision-records](docs/architectural-decision-records/README.md)).

A merge that changes `charts/**` releases a chart and opens the Kubernetes-Manifests bumps that deploy it.
