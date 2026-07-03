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
    version: 0.1.0
    releaseName: bluebird
    valuesFile: values.yml
```

### Argo CD ApplicationSet (PR previews)

```yaml
sources:
  - repoURL: oci://registry-1.docker.io/zimmertr/bluebird-helm
    chart: bluebird-helm
    targetRevision: 0.1.0
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

`strategy` selects the workload kind:

| `strategy` | Rendered kind | Notes |
|---|---|---|
| `RollingUpdate` (default) | `Deployment` | Honors `rollingUpdate.maxSurge`/`maxUnavailable` |
| `Recreate` | `Deployment` | |
| `Canary` | Argo `Rollout` | Adds a `-canary` Service; uses Istio traffic routing when `canary.trafficRouting` **and** `ingress.enabled` |
| `BlueGreen` | Argo `Rollout` | Adds a `-canary` Service as the blue-green preview |

## Values

| Key | Default | Description |
|---|---|---|
| `nameOverride` | `""` | Override `app.kubernetes.io/name` (default `bluebird`) |
| `fullnameOverride` | `""` | Override resource name base (default: release name) |
| `commonLabels` / `commonAnnotations` | `{}` | Merged onto every resource |
| `replicas` | `1` | Replica count |
| `image.name` | `zimmertr/bluebird` | Image repository |
| `image.tag` | `latest` | Image tag |
| `image.pullPolicy` | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | `[]` | Image pull secrets |
| `containerPort` | `8000` | Container port |
| `extraEnv` | `[]` | Extra container env vars |
| `resources` | `{}` | Container resource requests/limits |
| `podSecurityContext` | `{}` | Pod-level security context |
| `securityContext` | `{}` | Container-level security context |
| `probes.liveness` / `probes.readiness` | `GET / :8000` | Probe definitions |
| `probes.startup.enabled` | `true` | Enable the startup probe |
| `probes.startup` | `GET / :8000`, `failureThreshold: 30` | Startup probe definition |
| `strategy` | `RollingUpdate` | `RollingUpdate` \| `Recreate` \| `Canary` \| `BlueGreen` |
| `rollingUpdate` | `maxSurge: 25%`, `maxUnavailable: 25%` | Applies when `strategy=RollingUpdate` |
| `canary.dynamicStableScale` | `true` | Scale down stable as canary scales up |
| `canary.trafficRouting` | `true` | Use Istio VirtualService weighting (needs `ingress.enabled`) |
| `canary.steps` | `33 → 66 → 100` | Canary weight steps |
| `blueGreen.autoPromotionEnabled` | `true` | Auto-promote the preview |
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

## License

GPL-3.0-only.
