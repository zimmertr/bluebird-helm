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
| `replicas` | `1` | Replica count |
| `image.name` | `zimmertr/bluebird` | Image repository |
| `image.tag` | `""` → chart `appVersion` | Image tag (the repo publishes SemVer only, no `latest`) |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | `[]` | Image pull secrets |
| `containerPort` | `8000` | Container port |
| `extraEnv` | the app's env surface at its baked-in defaults | Container env vars. Ships fully populated as documentation-that-deploys: every tunable the app reads, at the value it would use anyway. Helm replaces lists wholesale, so an override must supply the complete list it wants (see below) |
| `resources` | `{}` | Container resource requests/limits |
| `podSecurityContext` | `{}` | Pod-level security context |
| `securityContext` | `{}` | Container-level security context |
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
| `RATE_LIMIT_GEOCODE_PER_MINUTE` | `30` | Per-client-address `GET /api/geocode` requests per minute; `0` disables |
| `RATE_LIMIT_GEOCODE_BURST` | `10` | Geocode requests an idle client may send back-to-back |
| `UPSTREAM_CONCURRENCY_WEATHER` | `8` | In-flight Open-Meteo weather batches per pod, across all concurrent analyses |
| `UPSTREAM_CONCURRENCY_AQI` | `8` | Same cap for the air-quality API |
| `UPSTREAM_CONCURRENCY_OVERPASS` | `2` | In-flight Overpass queries per pod |
| `NOMINATIM_MIN_INTERVAL_MS` | `2000` | Minimum spacing between Nominatim calls per pod |
| `UPSTREAM_BUDGET_WAIT_S` | `30` | Queue bound on a saturated upstream budget before shedding with a 503 |

Per-client limits are enforced per pod, so the effective ceiling is roughly
the value times `replicas`. Full semantics live in the app repo:
[README Configuration](https://github.com/zimmertr/bluebird#configuration) and
[docs/TRAFFIC.md](https://github.com/zimmertr/bluebird/blob/main/docs/TRAFFIC.md).

Because Helm replaces lists, overriding `extraEnv` replaces this whole set —
restate every variable you still want declared (dropping one only reverts the
app to that same baked-in default, so the risk is documentation drift, not
behavior drift).

## License

GPL-3.0-only.
