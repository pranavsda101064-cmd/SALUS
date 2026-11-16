"""End to end check for the Ghost Copy path, using the live API contract.

Run after: python manage.py seed_demo && python scripts/generate_dataset.py
           && python scripts/ghost_copy.py
"""

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "backend"))

import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "salus.settings")
import django  # noqa: E402

django.setup()

from django.core.files.uploadedfile import SimpleUploadedFile  # noqa: E402
from rest_framework.test import APIClient  # noqa: E402

BASE = "/api/v1"
GHOST = REPO_ROOT / "demo_data" / "clients_export_final.csv"


def main():
    if not GHOST.exists():
        raise SystemExit("Ghost file missing. Run the dataset and ghost scripts first.")

    client = APIClient()
    login = client.post(
        f"{BASE}/auth/demo-login",
        {"email": "meera@acmetraders.test"},
        format="json",
    )
    assert login.status_code == 200, login.content
    token = login.json()["token"]
    client.credentials(HTTP_AUTHORIZATION=f"Token {token}")

    health = client.get(f"{BASE}/health")
    print("health:", health.json()["report_provider"])

    overview = client.get(f"{BASE}/overview")
    print("overview:", json.dumps(overview.json(), indent=2)[:500])

    assets = client.get(f"{BASE}/assets")
    print("assets:", [(item["asset_id"], item["name"], item["sensitivity_label"]) for item in assets.json()["results"]])

    upload = SimpleUploadedFile(
        "clients_export_final.csv", GHOST.read_bytes(), content_type="text/csv"
    )
    response = client.post(f"{BASE}/investigations", {"file": upload}, format="multipart")
    assert response.status_code == 200, response.content
    payload = response.json()
    assert payload["matched"] is True, payload

    bundle = payload["bundle"]
    match = bundle["match"]
    risk = bundle["risk"]
    report = bundle["report"]
    lineage = bundle["lineage"]
    incident = bundle["incident"]

    print("\nincident:", incident["incident_id"], incident["severity"])
    print(
        "match:",
        match["match_id"],
        "score", match["match_score"],
        "containment", match["containment"],
        "recall", match["recall_vs_original"],
        "rows", match["matched_rows"],
        "columns", len(match["matched_columns"]),
    )
    print("canary:", match["canary"])
    print("risk:", risk["risk_id"], risk["total"], risk["band"], risk["factors"]["E"]["reasons"])
    print("report:", report["provider"], "|", report["summary"])
    print("actions:")
    for action in report["recommended_actions"]:
        print("  ", action["priority"], action["action"])
    print("lineage edges:")
    for edge in lineage["edges"]:
        print("  ", edge["relation"], edge["from"], "->", edge["to"], edge["ref"])
    print("limits:", bundle["limits"])

    assert match["recall_vs_original"] > 0.2, "expected about 30 percent recall"
    assert match["match_score"] > 0.8, "expected a strong match score"
    assert match["canary"]["found"] is True, "canary should be flagged"
    assert all(edge["ref"]["type"] in {"EVENT", "MATCH"} for edge in lineage["edges"])
    assert report["provider"] in {"SALUS_TEMPLATE", "GEMINI"}
    assert report["recommended_actions"], "report must include next actions"

    detail = client.get(f"{BASE}/incidents/{incident['incident_id']}")
    assert detail.status_code == 200
    print("\nincident detail ok, lineage nodes:", len(detail.json()["lineage"]["nodes"]))

    events = client.get(f"{BASE}/events?asset_id=SL-9281")
    print("source events:", [(e["event_id"], e["action"], e["simulated"]) for e in events.json()["results"]])

    print("\nE2E OK")


if __name__ == "__main__":
    main()
