# bluebird

A Helm chart for [Bluebird](https://github.com/zimmertr/bluebird) — a map-based weather window finder for hikers and mountaineers, live at [bluebirdforecast.com](https://bluebirdforecast.com).

By default the chart deploys a plain **Deployment** + **Service**, so it runs on any standard Kubernetes cluster with no extra operators. **Argo Rollouts** (canary / blue-green) and **Istio** ingress are entirely opt-in.

Every instance is **release-scoped**: all selectors key on `app.kubernetes.io/instance`, so a stable release and any number of per-PR preview releases can safely coexist in a single namespace.

## Quick start

```bash
helm install bluebird oci://registry-1.docker.io/zimmertr/bluebird-helm --version <version>
kubectl port-forward svc/bluebird 8080:8000   # then open http://localhost:8080
```

## Consuming via GitOps

### kustomize

```yaml
# kustomization.yml
namespace: bluebird-system
helmCharts:
  - name: bluebird-helm
    repo: oci://registry-1.docker.io/zimmertr
    version: 0.2.0
    releaseName: bluebird
    valuesFile: values.yml
```

### Argo CD ApplicationSet (PR previews)

```yaml
sources:
  - repoURL: oci://registry-1.docker.io/zimmertr/bluebird-helm
    chart: bluebird-helm
    targetRevision: 0.2.0
    helm:
      releaseName: bluebird-pr-{{ .number }}
      valueFiles: [$values/public/bluebird/values.yml]
      parameters:
        - { name: image.name, value: zimmertr/bluebird-pr }
        - { name: image.tag,  value: "pr-{{ .number }}-{{ .head_sha }}" }
        - { name: replicas,   value: "1" }
        - { name: strategy,   value: RollingUpdate }
        - { name: ingress.hosts[0], value: "pr-{{ .number }}.ganymede.sol.milkyway" }
```

## Deployment strategy

`useRollout` selects the workload kind; `strategy` selects the matching values block (`rollingUpdate` / `canary` / `blueGreen`) becomes the workload's `spec.strategy` **verbatim**:

| `useRollout` | `strategy` | Rendered kind | Strategy block |
|---|---|---|---|
| `false` (default) | `RollingUpdate` (default) | `Deployment` | `rollingUpdate` (optional; unset = API defaults) |
| `false` | `Recreate` | `Deployment` | — |
| `true` | `Canary` | Argo `Rollout` | `canary` — the full [Rollout canary spec](https://argo-rollouts.readthedocs.io/en/stable/features/specification/) |
| `true` | `BlueGreen` | Argo `Rollout` | `blueGreen` — the full Rollout blue-green spec |

The `canary` / `blueGreen` blocks are tpl-rendered, so the shipped defaults (service names, `role:` pod metadata) track the release name and per-PR preview releases keep working; overrides follow normal Helm coalescing (maps deep-merge, lists like `steps` replace wholesale). `Canary`/`BlueGreen` also render a second `-canary` Service whose name follows `canaryService`/`previewService`.

The defaults deliberately stop at what works on any cluster: a bare `strategy: Canary` progresses by ReplicaSet-ratio weighting. Everything environment-specific is opt-in through the same verbatim block — e.g. Istio traffic shifting against the chart's VirtualService (requires `ingress.enabled: true`):

```yaml
canary:
  dynamicStableScale: true
  trafficRouting:
    istio:
      virtualService:
        name: '{{ include "bluebird.fullname" . }}'
        routes: ['{{ include "bluebird.fullname" . }}-stable']
```

`analysis`, `experiment` steps, `managedRoutes`, plural `virtualServices`, `pingPong`, ... — any upstream field works the same way. Referenced `AnalysisTemplate`s are not rendered by this chart; deploy them alongside it.

> **Behavior change vs 0.4.x:** probes now default to `GET /healthz` instead of `GET /`, and a Rollout requires `useRollout: true` rather than being implied by `strategy: Canary`.

> **Breaking change vs 0.1.x:** `canary.trafficRouting` is no longer a boolean (nor a default) — supply the verbatim `trafficRouting` map above to keep the previous `true` behavior. `canary.dynamicStableScale` is likewise no longer defaulted on. The default image tag is now the chart `appVersion` instead of `latest`, which the image repo never publishes.

## Values

| Key | Default | Description |
|---|---|---|
| `nameOverride` | `""` | Override `app.kubernetes.io/name` (default `bluebird`) |
| `fullnameOverride` | `""` | Override resource name base (default: release name) |
| `commonLabels` / `commonAnnotations` | `{}` | Merged onto every resource |
| `replicas` | `1` | Replica count. **Omitted from the rendered manifest entirely when `autoscaling.enabled`**, so a GitOps controller cannot fight the HPA over `spec.replicas`; `autoscaling.minReplicas` is the floor instead |
| `image.name` | `zimmertr/bluebird` | Image repository |
| `image.tag` | `""` → chart `appVersion` | Image tag (the repo publishes SemVer only, no `latest`) |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | `[]` | Image pull secrets |
| `containerPort` | `8000` | Container port |
| `extraEnv` | the app's env surface at its baked-in defaults | Container env vars. Ships fully populated as documentation-that-deploys: every tunable the app reads, at the value it would use anyway. Helm replaces lists wholesale, so an override must supply the complete list it wants (see below) |
| `resources` | CPU request `250m`, memory `512Mi`/`2Gi` | Container resource requests/limits. Sized from cgroup measurements against production; **no CPU limit** by design, since CFS throttling costs tail latency on a latency-sensitive async service for no benefit. The memory request covers the resident national wildfire-perimeter snapshot the app holds from 0.44 onward (measured 225-253Mi steady across three replicas, 2026-08; the snapshot grows with the national fire count, so the request holds roughly twice that for fire season) |
| `podSecurityContext` | `runAsNonRoot`, uid/gid `10001`, `seccompProfile: RuntimeDefault` | Pod-level security context, asserting what the image already provides |
| `securityContext` | `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]` | Container-level security context. The read-only root needs no writable volume: the app writes nothing to disk |
| `autoscaling.enabled` | `false` | Render a HorizontalPodAutoscaler targeting the rendered workload kind (`Rollout` or `Deployment`) |
| `autoscaling.minReplicas` / `maxReplicas` | `3` / `10` | Bounds. `minReplicas` replaces `replicas` as the floor when enabled |
| `autoscaling.metrics` | CPU at `70%` utilization | Upstream `spec.metrics` verbatim. CPU because it is the only metric available without a custom-metrics adapter, and a real signal here: static SPA serving is CPU-bound |
| `autoscaling.behavior` | `{}` | Upstream `spec.behavior` verbatim |
| `podDisruptionBudget.enabled` | `false` | Render a PodDisruptionBudget selecting this release's pods |
| `podDisruptionBudget.minAvailable` | `50%` | PDB percentages round **up**, so at 3 replicas this keeps 2 pods; `maxUnavailable: 50%` would instead permit 2 disruptions and leave 1 |
| `podDisruptionBudget.maxUnavailable` | `""` | Alternative to `minAvailable`; set one, blank the other |
| `topologySpreadConstraints` | `[]` | Upstream `spec.topologySpreadConstraints` verbatim, except `labelSelector`, which the chart injects to match its own pods |
| `probes.liveness` / `probes.readiness` | `GET /healthz :8000` | Probe definitions |
| `probes.startup.enabled` | `true` | Enable the startup probe |
| `probes.startup` | `GET /healthz :8000`, `failureThreshold: 30` | Startup probe definition |
| `useRollout` | `false` | Render an Argo `Rollout` instead of a `Deployment` |
| `progressDeadlineSeconds` | *unset* | Deployment and Rollout; unset = the API default of 600s |
| `progressDeadlineAbort` | `false` | Rollout only. Exceeding the deadline otherwise marks it Degraded but never rolls back |
| `strategy` | `RollingUpdate` | `RollingUpdate` \| `Recreate` \| `Canary` \| `BlueGreen` — selects which block below applies |
| `rollingUpdate` | *unset* | Optional Deployment `spec.strategy.rollingUpdate`, verbatim (`maxSurge`/`maxUnavailable`); unset = API defaults |
| `canary` | services, `role:` pod metadata, steps `33 → 66 → 100` | Rollout `spec.strategy.canary`, verbatim + tpl-rendered — any upstream field works (`trafficRouting`, `analysis`, `stableMetadata`, ...) |
| `blueGreen` | services | Rollout `spec.strategy.blueGreen`, verbatim + tpl-rendered |
| `podAnnotations` / `podLabels` | `{}` | Extra pod metadata |
| `nodeSelector` / `tolerations` / `affinity` | `{}` / `[]` / `{}` | Scheduling |
| `service.type` | `ClusterIP` | Service type |
| `service.port` / `service.targetPort` | `8000` | Service ports |
| `ingress.enabled` | `false` | Render Istio `Gateway` + `VirtualService` |
| `ingress.gatewaySelector` | `{istio: gateway}` | Istio ingress workload selector |
| `ingress.hosts` | `[chart-example.local]` | Gateway/VirtualService hosts |
| `ingress.port` | `80` | HTTP listener port |
| `ingress.httpsRedirect` | `false` | Redirect `:80` → `:443` |
| `ingress.tls.enabled` / `ingress.tls.credentialName` | `false` / `""` | Terminate TLS on `:443` |
| `ingress.mesh` | `true` | Attach the in-mesh gateway + internal host to the VS |
| `experiment.enabled` | `false` | Header-matched (`experiment: true`) route |
| `experiment.host` | `""` | Destination for the experiment route (default: `-canary` service) |

## Environment variables

The default `extraEnv` declares every env var the app reads, at the app's own
baked-in defaults, so the chart is the one place to discover what can be
tuned. Deploying the defaults unchanged is a no-op for behavior.

| Variable | Default | Meaning |
|---|---|---|
| `LOG_LEVEL` | `WARNING` | Log verbosity: `TRACE`, `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |
| `RATE_LIMIT_ANALYZE_PER_MINUTE` | `12` | Per-client-address analyze requests per minute, shared by `POST /api/analyze` and `/api/analyze/stream`; `0` disables |
| `RATE_LIMIT_ANALYZE_BURST` | `6` | Analyze requests an idle client may send back-to-back |
| `RATE_LIMIT_DESTINATIONS_PER_MINUTE` | `30` | Per-client-address `POST /api/destinations` requests per minute, its own bucket; `0` disables |
| `RATE_LIMIT_DESTINATIONS_BURST` | `10` | Destinations requests an idle client may send back-to-back |
| `RATE_LIMIT_GEOCODE_PER_MINUTE` | `30` | Per-client-address `GET /api/geocode` requests per minute; `0` disables |
| `RATE_LIMIT_GEOCODE_BURST` | `10` | Geocode requests an idle client may send back-to-back |
| `RATE_LIMIT_WILDFIRES_PER_MINUTE` | `90` | Per-client-address `GET /api/wildfires` requests per minute; `0` disables. The loosest bucket: it answers from a snapshot the pod already holds and reaches no upstream, and the map overlay refetches on every pan |
| `RATE_LIMIT_WILDFIRES_BURST` | `30` | Wildfire requests an idle client may send back-to-back |
| `WILDFIRE_CACHE_TTL_S` | `600` | How long a fetched national wildfire-perimeter snapshot counts as current. Past it the snapshot is still served, with a refresh running behind the request |
| `WILDFIRE_RETRY_AFTER_FAILURE_S` | `60` | How long a failed refresh suppresses the next attempt, so an upstream outage does not turn every request into its own retry |
| `RATE_LIMIT_SMOKE_PER_MINUTE` | `90` | Per-client-address `GET /api/smoke` requests per minute; `0` disables. As loose as the wildfire bucket and for the same reason: it answers from a snapshot the pod already holds and reaches no upstream |
| `RATE_LIMIT_SMOKE_BURST` | `30` | Smoke requests an idle client may send back-to-back |
| `SMOKE_CACHE_TTL_S` | `1800` | How long a fetched NOAA HMS smoke analysis counts as current. Longer than the wildfire TTL because HMS publishes about twice a day, so this bounds how soon a new pass is seen rather than how stale the answer is. Past it the snapshot is still served, with a refresh running behind the request |
| `SMOKE_RETRY_AFTER_FAILURE_S` | `60` | How long a failed smoke refresh suppresses the next attempt. Same contract as the wildfire twin above |
| `UPSTREAM_CONCURRENCY_WEATHER` | `4` | In-flight Open-Meteo weather batches per pod, across all concurrent analyses (fairness knob; the weighted budgets are the rate protection) |
| `UPSTREAM_CONCURRENCY_AQI` | `4` | Same cap for the air-quality API |
| `UPSTREAM_WEIGHT_PER_MINUTE_WEATHER` | `550` | Per-pod Open-Meteo weather spend in weighted calls per minute (one batched location = one call). The full safe rate on **every** pod, not a per-replica share: one analysis runs end to end on one pod and must cover its whole fan-out. `0` disables pacing, which fails analyses rather than slowing them |
| `UPSTREAM_WEIGHT_PER_MINUTE_AQI` | `550` | Same budget for the air-quality API, metered separately |
| `UPSTREAM_WEIGHT_MAX_WAIT_S` | `120` | A paced batch that would wait longer than this sheds with a 503 |
| `UPSTREAM_CONCURRENCY_OVERPASS` | `2` | In-flight Overpass queries per pod |
| `NOMINATIM_MIN_INTERVAL_MS` | `3500` | Minimum spacing between Nominatim calls per pod (3 replicas at 3.5s stay under Nominatim's absolute ~1 req/s) |
| `UPSTREAM_BUDGET_WAIT_S` | `30` | Queue bound on a saturated upstream budget before shedding with a 503 |

Per-client limits are enforced per pod, so the effective ceiling is roughly
the value times the current replica count — a range rather than a fixed
number once `autoscaling` is enabled. The Open-Meteo weighted budgets are
deliberately per-pod ceilings rather than a rationed share, so they do not
divide by replica count at all. Full semantics live in the app repo:
[README Configuration](https://github.com/zimmertr/bluebird#configuration) and
[docs/TRAFFIC.md](https://github.com/zimmertr/bluebird/blob/main/docs/TRAFFIC.md).

Because Helm replaces lists, overriding `extraEnv` replaces this whole set —
restate every variable you still want declared (dropping one only reverts the
app to that same baked-in default, so the risk is documentation drift, not
behavior drift).

## License

GPL-3.0-only.
