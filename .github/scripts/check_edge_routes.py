"""Walk request shapes through the rendered VirtualService and check which
route answers each one.

The edge rules are prefix, exact and regex matches on the path, and the first
route whose match accepts a request wins. A rule that reads right on its own
can still be dodged by a request shape nobody wrote a case for: Envoy compares
the path as literal text and Istio's default normalization leaves %2F encoded,
while the pod decodes it before it routes, so /api%2Fanalyze matched no /api
rule and reached the analyze route without a key (bluebird#620, #302). This
holds the route order and the matches to a table of requests and the route
each must land on, so that shape, and every one beside it, is a case.

It models the parts of Envoy's matching the chart uses: `prefix`, `exact` and
`regex` (a whole-path match, query string excluded, which Python's `re`
reads the same way RE2 does for these patterns) on the URI; `exact` and
`regex` on a header; `exact` on the method; and the gateway a match is bound
to. A route with no match is the catch-all. Requests arrive through the public
gateway, because that is the boundary these rules exist for.

With `--tunnel` it walks the render with `ingress.tunnel.peerRegex` set
(`tunnel_values.yaml` beside this file), where the gateway removes
CF-Connecting-IP from every request that did not come through the tunnel
(bluebird#631). The peer the gateway saw is modelled the way Envoy writes it:
appended as the last X-Forwarded-For hop, after anything the client sent. Each
request shape is then sent once from the tunnel's peer, where it must land on
its usual route with the header kept, and once from each peer a LAN device can
arrive as, where it must land on that route's `-off-tunnel` twin with the
header removed. Without `--tunnel`, no route may remove the header at all,
because the strip is opt-in and a deployment without a tunnel keeps today's
behaviour.

Standard library only, like check_pr_title.py: the workflow pipes the
VirtualService in as JSON (`yq -o=json`) and runs this on the runner's Python.
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Case:
    method: str
    path: str
    # The route each request must land on, named by the suffix the chart puts
    # after the release's full name.
    route: str
    headers: dict[str, str] = field(default_factory=dict)


KEY = {"x-open-meteo-key": "made-up-key"}
PREFLIGHT = {"origin": "https://example.com", "access-control-request-method": "POST"}

CASES = [
    # The encoded slash, in both cases of the hex digit and on the paths the
    # review reproduced (bluebird#620).
    Case("POST", "/api%2Fanalyze", "-api-internal"),
    Case("POST", "/api%2fanalyze", "-api-internal"),
    Case("POST", "/api%2Fanalyze%2Fstream", "-api-internal"),
    Case("GET", "/api%2Fversion", "-api-internal"),
    # A key does not open the encoded shape either: the keyed rule is a prefix
    # rule like the others.
    Case("POST", "/api%2Fanalyze", "-api-internal", KEY),
    # The literal shapes the allowlist already refused.
    Case("POST", "/api/analyze", "-api-internal"),
    Case("POST", "/api/analyze/stream", "-api-internal"),
    Case("GET", "/api/nonexistent", "-api-internal"),
    Case("GET", "/api", "-api-internal"),
    # What the gateway publishes.
    Case("GET", "/api/version", "-api-public"),
    Case("GET", "/api/capabilities", "-api-public"),
    Case("POST", "/api/analyze", "-api-keyed", KEY),
    Case("POST", "/api/analyze/stream", "-api-keyed", KEY),
    Case("OPTIONS", "/api/analyze", "-api-keyed", PREFLIGHT),
    # Everything outside /api rides the stable route untouched.
    Case("GET", "/", "-stable"),
    Case("GET", "/docs", "-stable"),
    Case("GET", "/apiary", "-stable"),
]


# The address a cloudflared pod has in the scenario's pod network, and the
# peers a LAN device reaches the gateway as. kube-proxy rewrites a LAN client's
# address to the node's cni0 (.1) or flannel.1 (.0) address on the way to a
# gateway Service with externalTrafficPolicy Cluster, and keeps the client's own
# address under Local. The last pair is a LAN client that typed the tunnel's
# address into X-Forwarded-For itself: the gateway's hop still comes after it.
TUNNEL_PEER = "10.244.2.62"
OFF_TUNNEL = [
    ("10.244.0.1", ""),
    ("10.244.0.0", ""),
    ("192.168.40.50", ""),
    ("10.244.0.1", TUNNEL_PEER),
    ("10.244.0.1", f"203.0.113.7, {TUNNEL_PEER}"),
]
# What Cloudflare's edge sends through the tunnel: the visitor's address.
TUNNEL_CLIENT_XFF = "203.0.113.7"
STRIPPED = "cf-connecting-ip"
NO_TWIN = {"-api-internal"}


def _xff(client_typed: str, peer: str, separator: str) -> str:
    """X-Forwarded-For as the gateway routes on it: the peer appended last."""
    return f"{client_typed}{separator}{peer}" if client_typed else peer


def _string_match(rule: dict, value: str | None) -> bool:
    if value is None:
        return False
    if "exact" in rule:
        return value == rule["exact"]
    if "prefix" in rule:
        return value.startswith(rule["prefix"])
    if "regex" in rule:
        return re.fullmatch(rule["regex"], value) is not None
    raise SystemExit(f"unmodelled string match: {rule}")


def _accepts(match: dict, case: Case, gateway: str, xff: str | None = None) -> bool:
    known = {"uri", "headers", "method", "gateways"}
    if set(match) - known:
        raise SystemExit(f"unmodelled match fields: {sorted(set(match) - known)}")
    if "gateways" in match and gateway not in match["gateways"]:
        return False
    if "uri" in match and not _string_match(match["uri"], case.path):
        return False
    if "method" in match and not _string_match(match["method"], case.method):
        return False
    headers = dict(case.headers)
    if xff is not None:
        headers["x-forwarded-for"] = xff
    return all(
        _string_match(rule, headers.get(name)) for name, rule in match.get("headers", {}).items()
    )


def first_route(
    http: list[dict], case: Case, gateway: str, xff: str | None = None
) -> dict | None:
    for route in http:
        matches = route.get("match")
        if not matches or any(_accepts(m, case, gateway, xff) for m in matches):
            return route
    return None


def _strips(route: dict) -> bool:
    removed = route.get("headers", {}).get("request", {}).get("remove", [])
    return STRIPPED in [name.lower() for name in removed]


def _report(failures: list[str], ok: bool, shown: str, got: str | None, want: str) -> None:
    if ok:
        print(f"ok    {shown} -> {got}")
        return
    failures.append(shown)
    print(f"FAIL  {shown} -> {got}, want {want}")
    print(
        f"::error file=charts/bluebird/templates/virtualservice.yaml::"
        f"{shown} reaches {got}, not {want}."
    )


def _structure(http: list[dict], tunnel: bool) -> list[str]:
    """Every route that forwards to the pod either keeps the header only for a
    tunnel peer, or removes it; and without a tunnel, none removes it."""
    problems = []
    for route in http:
        if "route" not in route:
            continue
        name = route["name"]
        if not tunnel:
            if _strips(route):
                problems.append(f"{name} removes {STRIPPED} with no tunnel configured")
            continue
        matches = route.get("match") or []
        tunnel_only = bool(matches) and all(
            "x-forwarded-for" in m.get("headers", {}) for m in matches
        )
        if not tunnel_only and not _strips(route):
            problems.append(f"{name} forwards {STRIPPED} from a peer that is not the tunnel")
    for problem in problems:
        print(f"FAIL  {problem}")
        print(f"::error file=charts/bluebird/templates/virtualservice.yaml::{problem}.")
    return problems


def main(argv: list[str]) -> int:
    tunnel = "--tunnel" in argv
    service = json.load(sys.stdin)
    public = [g for g in service["spec"]["gateways"] if g != "mesh"]
    if len(public) != 1:
        raise SystemExit(f"expected one public gateway, found {public}")
    gateway = public[0]
    http = service["spec"]["http"]
    failures: list[str] = []
    walked = 0
    for case in CASES:
        shown = f"{case.method} {case.path}" + (f" {sorted(case.headers)}" if case.headers else "")
        if not tunnel:
            walked += 1
            want = gateway + case.route
            route = first_route(http, case, gateway)
            got = route and route["name"]
            _report(failures, got == want, shown, got, want)
            continue
        for separator in (",", ", "):
            walked += 1
            want = gateway + case.route
            route = first_route(http, case, gateway, _xff(TUNNEL_CLIENT_XFF, TUNNEL_PEER, separator))
            got = route and route["name"]
            ok = got == want and not (route and _strips(route))
            _report(failures, ok, f"{shown} from the tunnel", got, f"{want}, header kept")
            for peer, typed in OFF_TUNNEL:
                walked += 1
                twin = case.route in NO_TWIN
                want = gateway + case.route + ("" if twin else "-off-tunnel")
                route = first_route(http, case, gateway, _xff(typed, peer, separator))
                got = route and route["name"]
                ok = got == want and (twin or bool(route and _strips(route)))
                origin = f"{shown} from {peer}" + (f" typing {typed!r}" if typed else "")
                _report(failures, ok, origin, got, want + ("" if twin else ", header removed"))
    problems = _structure(http, tunnel)
    print(f"{walked - len(failures)} of {walked} request shapes land on their route.")
    return 1 if failures or problems else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
