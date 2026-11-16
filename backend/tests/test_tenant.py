import pandas as pd
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from assets.models import Asset
from data_dna.service import prepare_asset
from events.models import Event
from organizations.models import Organization, User


class TenantIsolationTests(TestCase):
    def setUp(self):
        self.org_a = Organization.objects.create(id="ORG-A", name="Alpha", slug="alpha")
        self.org_b = Organization.objects.create(id="ORG-B", name="Beta", slug="beta")
        self.user_a = User.objects.create_user(
            username="owner@alpha.test",
            email="owner@alpha.test",
            password="x",
            public_id="USER-201",
            organization=self.org_a,
        )
        self.user_b = User.objects.create_user(
            username="owner@beta.test",
            email="owner@beta.test",
            password="x",
            public_id="USER-202",
            organization=self.org_b,
        )
        self.asset_a = Asset.objects.create(
            public_id="SL-8001",
            organization=self.org_a,
            name="alpha_data",
            row_count=10,
        )
        self.asset_b = Asset.objects.create(
            public_id="SL-8002",
            organization=self.org_b,
            name="beta_data",
            row_count=10,
        )
        Event.objects.create(
            event_id="EV-8001",
            organization=self.org_a,
            actor_id=self.user_a.public_id,
            asset_id=self.asset_a.public_id,
            action="FILE_DOWNLOADED",
            source="SIMULATOR",
            timestamp=timezone.now(),
            simulated=True,
        )
        Event.objects.create(
            event_id="EV-8002",
            organization=self.org_b,
            actor_id=self.user_b.public_id,
            asset_id=self.asset_b.public_id,
            action="FILE_DOWNLOADED",
            source="SIMULATOR",
            timestamp=timezone.now(),
            simulated=True,
        )
        token = Token.objects.create(user=self.user_a)
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_asset_list_is_org_scoped(self):
        response = self.client.get("/api/v1/assets")
        self.assertEqual(response.status_code, 200)
        ids = [item["asset_id"] for item in response.json()["results"]]
        self.assertEqual(ids, ["SL-8001"])

    def test_other_org_asset_is_404(self):
        response = self.client.get("/api/v1/assets/SL-8002")
        self.assertEqual(response.status_code, 404)

    def test_event_list_is_org_scoped(self):
        response = self.client.get("/api/v1/events")
        self.assertEqual(response.status_code, 200)
        event_ids = [item["event_id"] for item in response.json()["results"]]
        self.assertEqual(event_ids, ["EV-8001"])

    def test_investigation_never_matches_another_org(self):
        df = pd.DataFrame(
            {
                "email": ["priya@example.test", "arjun@example.test"],
                "pan": ["ABCDE1234F", "BCDEF2345G"],
            }
        )
        prepare_asset(
            organization=self.org_b,
            name="beta_customers",
            filename="beta_customers.csv",
            df=df,
            kind="ORIGINAL",
            id_floor=9281,
        )
        upload = SimpleUploadedFile(
            "suspect.csv",
            df.to_csv(index=False).encode("utf-8"),
            content_type="text/csv",
        )
        response = self.client.post("/api/v1/investigations", {"file": upload}, format="multipart")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.json()["matched"])
