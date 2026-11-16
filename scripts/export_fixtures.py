"""Export live API responses into contract fixtures.

Run after the seed and the ghost copy investigation.
"""

import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "backend"))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "salus.settings")

import django  # noqa: E402

django.setup()

from rest_framework.test import APIClient  # noqa: E402

BASE = "/api/v1"
OUT = REPO_ROOT / "contract" / "fixtures"


def save(name, payload):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.json"
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    print("wrote", path)


def main():
    client = APIClient()
    login = client.post(
        f"{BASE}/auth/demo-login", {"email": "meera@acmetraders.test"}, format="json"
    )
    assert login.status_code == 200, login.content
    client.credentials(HTTP_AUTHORIZATION=f"Token {login.json()['token']}")

    login_payload = login.json()
    login_payload["token"] = "demo-token-redacted"
    save("login", login_payload)
    save("health", client.get(f"{BASE}/health").json())
    save("overview", client.get(f"{BASE}/overview").json())
    save("risk_policy", client.get(f"{BASE}/risk/policy").json())

    assets = client.get(f"{BASE}/assets?include_baseline=1").json()["results"]
    source = next(item for item in assets if item["asset_id"] == "SL-9281")
    save("asset", source)

    events = client.get(f"{BASE}/events?asset_id=SL-9281").json()["results"]
    save("event", events[-1] if events else {})

    incidents = client.get(f"{BASE}/incidents").json()["results"]
    if not incidents:
        raise SystemExit("No incidents. Run scripts/e2e_check.py first.")
    incident_id = incidents[0]["incident_id"]
    bundle = client.get(f"{BASE}/incidents/{incident_id}").json()
    save("incident_bundle", bundle)
    save("match", bundle["match"])
    save("risk", bundle["risk"])
    save("report", bundle["report"])
    save("lineage", bundle["lineage"])
    save("investigation", bundle["investigation"])
    save("audit_trail", bundle["audit_trail"])
    save("incident_list", {"results": incidents})

    investigations = client.get(f"{BASE}/investigations").json()
    save("investigation_list", investigations)
    audit = client.get(f"{BASE}/audit?entity_id={incident_id}").json()
    save("audit", audit)

    storyboard = client.get(f"{BASE}/simulation/ghost-copy").json()
    save("simulation_storyboard", storyboard)
    landing_snapshot = REPO_ROOT / "frontend" / "landing" / "simulation-data.json"
    landing_snapshot.write_text(
        json.dumps(storyboard, indent=2, ensure_ascii=True) + "\n", encoding="utf-8"
    )
    print("wrote", landing_snapshot)
    print("fixtures exported for", incident_id)


if __name__ == "__main__":
    main()
