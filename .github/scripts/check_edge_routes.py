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


def _accepts(match: dict, case: Case, gateway: str) -> bool:
    known = {"uri", "headers", "method", "gateways"}
    if set(match) - known:
        raise SystemExit(f"unmodelled match fields: {sorted(set(match) - known)}")
    if "gateways" in match and gateway not in match["gateways"]:
        return False
    if "uri" in match and not _string_match(match["uri"], case.path):
        return False
    if "method" in match and not _string_match(match["method"], case.method):
        return False
    return all(
        _string_match(rule, case.headers.get(name))
        for name, rule in match.get("headers", {}).items()
    )


def first_route(http: list[dict], case: Case, gateway: str) -> str | None:
    for route in http:
        matches = route.get("match")
        if not matches or any(_accepts(m, case, gateway) for m in matches):
            return route["name"]
    return None


def main() -> int:
    service = json.load(sys.stdin)
    public = [g for g in service["spec"]["gateways"] if g != "mesh"]
    if len(public) != 1:
        raise SystemExit(f"expected one public gateway, found {public}")
    gateway = public[0]
    http = service["spec"]["http"]
    failures = 0
    for case in CASES:
        want = gateway + case.route
        got = first_route(http, case, gateway)
        shown = f"{case.method} {case.path}" + (f" {sorted(case.headers)}" if case.headers else "")
        if got == want:
            print(f"ok    {shown} -> {got}")
        else:
            failures += 1
            print(f"FAIL  {shown} -> {got}, want {want}")
            print(
                f"::error file=charts/bluebird/templates/virtualservice.yaml::"
                f"{shown} reaches {got}, not {want}."
            )
    print(f"{len(CASES) - failures} of {len(CASES)} request shapes land on their route.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
