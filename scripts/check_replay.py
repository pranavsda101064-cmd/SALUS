"""QA check for demo bootstrap and replay.

This resets the demo, logs in, replays simulated activity, uploads the
ghost copy, and prints the fresh event ids used by the incident.
"""

import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "backend"))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "salus.settings")

import django  # noqa: E402

django.setup()

from django.core.files.uploadedfile import SimpleUploadedFile  # noqa: E402
from rest_framework.test import APIClient  # noqa: E402

BASE = "/api/v1"
GHOST = REPO_ROOT / "demo_data" / "clients_export_final.csv"


def main():
    client = APIClient()
    reset = client.post(f"{BASE}/dev/seed", {"reset": True}, format="json")
    assert reset.status_code == 200, reset.content
    login = client.post(
        f"{BASE}/auth/demo-login", {"email": "meera@acmetraders.test"}, format="json"
    )
    assert login.status_code == 200, login.content
    client.credentials(HTTP_AUTHORIZATION=f"Token {login.json()['token']}")

    replay = client.post(f"{BASE}/simulator/run", {"scenario": "ghost_copy"}, format="json")
    assert replay.status_code == 200, replay.content
    new_ids = [event["event_id"] for event in replay.json()["created"]]
    print("replayed:", new_ids)

    upload = SimpleUploadedFile(
        "clients_export_final.csv", GHOST.read_bytes(), content_type="text/csv"
    )
    response = client.post(f"{BASE}/investigations", {"file": upload}, format="multipart")
    assert response.status_code == 200, response.content
    bundle = response.json()["bundle"]
    timeline_ids = [event["event_id"] for event in bundle["timeline"]]
    print("timeline:", timeline_ids)
    assert any(event_id in timeline_ids for event_id in new_ids), timeline_ids
    print("risk:", bundle["risk"]["total"], bundle["risk"]["band"])
    print("report:", bundle["report"]["provider"])
    print("REPLAY OK")


if __name__ == "__main__":
    main()
