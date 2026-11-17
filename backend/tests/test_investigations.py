from datetime import timedelta

import pandas as pd
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from django.utils import timezone

from ai_reports.models import Report
from assets.models import Asset
from data_dna.service import prepare_asset
from events.services import EventError, record_event
from incidents.models import Incident, Investigation
from incidents.services import correlate, create_investigation
from organizations.models import AuditLog, Organization, User
from risk_engine.engine import _d_factor


def _customer_frame(count=30, start=0):
    return pd.DataFrame(
        {
            "email": [f"user{index}@example.test" for index in range(start, start + count)],
            "pan": [f"ABCDE{index:04d}F" for index in range(start, start + count)],
        }
    )


class InvestigationTests(TestCase):
    def setUp(self):
        self.organization = Organization.objects.create(
            id="ORG-INV", name="Investigation Traders", slug="investigation-traders"
        )
        self.user = User.objects.create_user(
            username="owner@investigation.test",
            email="owner@investigation.test",
            password="x",
            public_id="USER-401",
            organization=self.organization,
        )
        self.source_df = _customer_frame()
        self.source, _fp = prepare_asset(
            organization=self.organization,
            name="customers",
            filename="customers.csv",
            df=self.source_df,
            kind="ORIGINAL",
            id_floor=9281,
        )

    def _upload(self, frame):
        content = frame.to_csv(index=False).encode("utf-8")
        return SimpleUploadedFile("suspect.csv", content, content_type="text/csv")

    def test_investigation_is_first_class_and_deduplicates(self):
        suspect_df = self.source_df.head(10).copy()
        first = create_investigation(
            self.organization, self.user, self._upload(suspect_df)
        )
        self.assertTrue(first["matched"])
        self.assertFalse(first["duplicate"])
        investigation = first["investigation"]
        self.assertEqual(investigation.status, "OPEN")
        self.assertEqual(investigation.created_by, self.user)
        self.assertEqual(Investigation.objects.count(), 1)
        self.assertEqual(Incident.objects.count(), 1)
        self.assertEqual(Report.objects.count(), 1)
        report = Report.objects.get()
        self.assertEqual(len(report.evidence_hash), 64)
        self.assertTrue(
            AuditLog.objects.filter(
                action="INVESTIGATION_CREATED",
                entity_id=first["incident"].public_id,
            ).exists()
        )

        second = create_investigation(
            self.organization, self.user, self._upload(suspect_df)
        )
        self.assertTrue(second["duplicate"])
        self.assertEqual(second["investigation"].public_id, investigation.public_id)
        self.assertEqual(second["incident"].public_id, first["incident"].public_id)
        self.assertEqual(Investigation.objects.count(), 1)
        self.assertEqual(Incident.objects.count(), 1)
        self.assertEqual(Asset.objects.filter(kind="SUSPECT").count(), 1)

    def test_no_match_is_recorded_as_investigation(self):
        unrelated = pd.DataFrame(
            {
                "email": [f"other{index}@elsewhere.test" for index in range(10)],
                "pan": [f"ZZZZZ{index:04d}Z" for index in range(10)],
            }
        )
        result = create_investigation(
            self.organization, self.user, self._upload(unrelated)
        )
        self.assertFalse(result["matched"])
        self.assertFalse(result["duplicate"])
        self.assertEqual(result["investigation"].status, "NO_MATCH")
        self.assertEqual(Incident.objects.count(), 0)
        self.assertTrue(
            AuditLog.objects.filter(
                action="INVESTIGATION_CREATED",
                entity_type="INVESTIGATION",
            ).exists()
        )


class ShareOnlyCorrelationTests(TestCase):
    def test_external_share_without_download_is_used(self):
        organization = Organization.objects.create(
            id="ORG-SHARE", name="Share Traders", slug="share-traders"
        )
        user = User.objects.create_user(
            username="owner@share.test",
            email="owner@share.test",
            password="x",
            public_id="USER-402",
            organization=organization,
        )
        source = Asset.objects.create(
            public_id="SL-8101",
            organization=organization,
            name="source",
            kind="ORIGINAL",
            row_count=10,
        )
        share, _ = record_event(
            organization=organization,
            event_id="EV-8101",
            actor_id=user.public_id,
            asset_id=source.public_id,
            action="EXTERNAL_SHARE",
            source="SIMULATOR",
            destination="external_domain.com",
            timestamp=timezone.now() - timedelta(hours=1),
            evidence={"rows": 10, "simulated": True},
        )
        correlation = correlate(organization, source, timezone.now())
        self.assertIsNone(correlation["download_event"])
        self.assertEqual(len(correlation["share_events"]), 1)
        self.assertTrue(correlation["share_only"])
        d_factor = _d_factor([share], None)
        self.assertEqual(d_factor["score"], 85)
        self.assertEqual(d_factor["destination"], "external_domain.com")


class EventActorValidationTests(TestCase):
    def test_foreign_actor_is_rejected_for_simulated_events(self):
        organization = Organization.objects.create(
            id="ORG-EVT", name="Event Traders", slug="event-traders"
        )
        User.objects.create_user(
            username="owner@event.test",
            email="owner@event.test",
            password="x",
            public_id="USER-403",
            organization=organization,
        )
        asset = Asset.objects.create(
            public_id="SL-8102",
            organization=organization,
            name="source",
            row_count=1,
        )
        with self.assertRaises(EventError):
            record_event(
                organization=organization,
                event_id="EV-8102",
                actor_id="USER-999",
                asset_id=asset.public_id,
                action="FILE_VIEWED",
                source="SIMULATOR",
                timestamp=timezone.now(),
            )

    def test_connector_can_carry_external_actor(self):
        organization = Organization.objects.create(
            id="ORG-EVT2", name="Connector Traders", slug="connector-traders"
        )
        asset = Asset.objects.create(
            public_id="SL-8103",
            organization=organization,
            name="source",
            row_count=1,
        )
        event, created = record_event(
            organization=organization,
            event_id="EV-8103",
            actor_id="external:vendor",
            asset_id=asset.public_id,
            action="FILE_VIEWED",
            source="CONNECTOR",
            timestamp=timezone.now(),
        )
        self.assertTrue(created)
        self.assertIsNone(event.actor_ref)
        self.assertEqual(event.actor_id, "external:vendor")
