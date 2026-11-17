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
    investigation = payload["investigation"]

    print(
        "\ninvestigation:",
        investigation["investigation_id"],
        "duplicate" if payload.get("duplicate") else "new",
    )
    print("incident:", incident["incident_id"], incident["severity"])
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
    assert len(report["evidence_hash"]) == 64, "report must carry an evidence hash"
    assert bundle["investigation"]["investigation_id"] == investigation["investigation_id"]
    assert bundle["audit_trail"], "incident bundle must include an audit trail"

    detail = client.get(f"{BASE}/incidents/{incident['incident_id']}")
    assert detail.status_code == 200
    detail_payload = detail.json()
    assert detail_payload["investigation"]["investigation_id"] == investigation["investigation_id"]
    assert detail_payload["audit_trail"]
    print("\nincident detail ok, lineage nodes:", len(detail_payload["lineage"]["nodes"]))
    print("audit trail:", [(item["action"], item["actor_id"]) for item in detail_payload["audit_trail"]])

    duplicate_upload = SimpleUploadedFile(
        "clients_export_final.csv", GHOST.read_bytes(), content_type="text/csv"
    )
    duplicate = client.post(
        f"{BASE}/investigations", {"file": duplicate_upload}, format="multipart"
    )
    assert duplicate.status_code == 200, duplicate.content
    duplicate_payload = duplicate.json()
    assert duplicate_payload["duplicate"] is True
    assert (
        duplicate_payload["investigation"]["investigation_id"]
        == investigation["investigation_id"]
    )
    assert duplicate_payload["bundle"]["incident"]["incident_id"] == incident["incident_id"]
    print("duplicate upload returns", duplicate_payload["investigation"]["investigation_id"])

    investigations = client.get(f"{BASE}/investigations")
    assert investigations.status_code == 200
    ids = [item["investigation_id"] for item in investigations.json()["results"]]
    assert investigation["investigation_id"] in ids
    print("investigations:", ids)

    investigation_detail = client.get(
        f"{BASE}/investigations/{investigation['investigation_id']}"
    )
    assert investigation_detail.status_code == 200
    assert investigation_detail.json()["incident"]["incident_id"] == incident["incident_id"]
    print("investigation detail ok")

    status_change = client.post(
        f"{BASE}/incidents/{incident['incident_id']}/status",
        {"status": "TRIAGED"},
        format="json",
    )
    assert status_change.status_code == 200, status_change.content
    regenerated = client.post(
        f"{BASE}/incidents/{incident['incident_id']}/report", {}, format="json"
    )
    assert regenerated.status_code == 200, regenerated.content
    regenerated_report = regenerated.json()["report"]
    assert len(regenerated_report["evidence_hash"]) == 64
    assert regenerated_report["evidence_hash"] == report["evidence_hash"]

    audit = client.get(f"{BASE}/audit?entity_id={incident['incident_id']}")
    assert audit.status_code == 200
    audit_actions = [item["action"] for item in audit.json()["results"]]
    assert "INCIDENT_STATUS_CHANGED" in audit_actions
    assert "REPORT_REGENERATED" in audit_actions
    print("audit entries:", audit_actions)

    events = client.get(f"{BASE}/events?asset_id=SL-9281")
    print("source events:", [(e["event_id"], e["action"], e["simulated"]) for e in events.json()["results"]])

    print("\nE2E OK")


if __name__ == "__main__":
    main()
