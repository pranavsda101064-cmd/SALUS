from datetime import timedelta

import pandas as pd
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone

from data_dna.models import CanaryIssuance
from data_dna.service import prepare_asset
from events.services import record_event
from incidents.models import Incident
from incidents.services import create_investigation
from organizations.models import Organization, User


def _frame(count=24):
    return pd.DataFrame(
        {
            "email": [f"user{index}@example.test" for index in range(count)],
            "pan": [f"ABCDE{index:04d}F" for index in range(count)],
        }
    )


@override_settings(DEMO_MODE=True)
class SimulationStoryboardTests(TestCase):
    def setUp(self):
        self.organization = Organization.objects.create(
            id="ORG-01",
            name="Acme Traders",
            slug="acme-traders",
            is_demo=True,
        )
        self.user = User.objects.create_user(
            username="owner@acme.test",
            email="owner@acme.test",
            password="x",
            public_id="USER-501",
            organization=self.organization,
        )
        self.source_df = _frame()
        self.source, _fingerprints = prepare_asset(
            organization=self.organization,
            name="customer_master_v1",
            filename="customer_master_v1.xlsx",
            df=self.source_df,
            kind="ORIGINAL",
            watermark="SALUS-WM-TEST",
            id_floor=9281,
        )
        CanaryIssuance.objects.create(
            public_id="CN-TEST",
            organization=self.organization,
            asset=self.source,
            recipient="vendor@external.test",
            token="CN-TEST",
            row_labels=["CN-007-A"],
            issued_at=timezone.now(),
        )
        record_event(
            organization=self.organization,
            event_id="EV-9001",
            actor_id=self.user.public_id,
            asset_id=self.source.public_id,
            action="FILE_DOWNLOADED",
            source="SIMULATOR",
            destination="local_device",
            timestamp=timezone.now() - timedelta(hours=3),
            evidence={"rows": self.source.row_count, "simulated": True},
        )
        record_event(
            organization=self.organization,
            event_id="EV-9002",
            actor_id=self.user.public_id,
            asset_id=self.source.public_id,
            action="EXTERNAL_SHARE",
            source="SIMULATOR",
            destination="external_domain.com",
            timestamp=timezone.now() - timedelta(hours=2, minutes=55),
            evidence={"rows": 10, "simulated": True},
        )
        suspect = self.source_df.head(12)
        upload = SimpleUploadedFile(
            "clients_export_final.csv",
            suspect.to_csv(index=False).encode("utf-8"),
            content_type="text/csv",
        )
        self.result = create_investigation(self.organization, self.user, upload)

    def test_storyboard_is_public_and_live(self):
        response = self.client.get("/api/v1/simulation/ghost-copy")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Cache-Control"], "no-store")
        body = response.json()
        self.assertTrue(body["available"])
        self.assertEqual(body["mode"], "LIVE_DEMO")
        self.assertEqual(body["organization"]["organization_id"], "ORG-01")
        self.assertEqual(body["dataset"]["name"], "customer_master_v1")
        self.assertEqual(body["dataset"]["canary"]["canary_id"], "CN-TEST")
        self.assertEqual(len(body["movement"]["events"]), 2)
        self.assertEqual(body["ghost_copy"]["original_rows"], 24)
        self.assertEqual(body["ghost_copy"]["ghost_rows"], 12)
        self.assertTrue(body["match"]["match_id"].startswith("MT-"))
        self.assertEqual(body["behaviour"]["architecture"], [10, 8, 4, 10])
        self.assertIn("score", body["behaviour"])
        self.assertIn("total", body["risk"])
        self.assertIn("summary", body["report"])
        self.assertGreaterEqual(len(body["tracking"]["lineage"]["edges"]), 1)

    def test_storyboard_does_not_expose_raw_values(self):
        response = self.client.get("/api/v1/simulation/ghost-copy")
        content = response.content.decode("utf-8")
        self.assertNotIn("user0@example.test", content)
        self.assertNotIn("ABCDE0000F", content)
        self.assertNotIn("SALUS_HASH_SALT", content)

    def test_storyboard_reports_missing_incident(self):
        Incident.objects.all().delete()
        response = self.client.get("/api/v1/simulation/ghost-copy")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertFalse(body["available"])
        self.assertEqual(body["mode"], "NO_INCIDENT")

    @override_settings(DEMO_MODE=False)
    def test_storyboard_is_disabled_outside_demo_mode(self):
        response = self.client.get("/api/v1/simulation/ghost-copy")
        self.assertEqual(response.status_code, 403)
