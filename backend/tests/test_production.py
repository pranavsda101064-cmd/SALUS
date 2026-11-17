from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.db.utils import DatabaseError
from django.test import TestCase, override_settings
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from assets.models import Asset
from organizations.models import Organization, User


class ProductionApiTests(TestCase):
    def setUp(self):
        self.organization = Organization.objects.create(
            id="ORG-P1", name="Prod Traders", slug="prod-traders"
        )
        self.user = User.objects.create_user(
            username="owner@prod.test",
            email="owner@prod.test",
            password="x",
            public_id="USER-301",
            organization=self.organization,
        )
        token = Token.objects.create(user=self.user)
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    @override_settings(DEMO_MODE=False)
    def test_demo_login_is_disabled_outside_demo_mode(self):
        response = APIClient().post(
            "/api/v1/auth/demo-login", {"email": "owner@prod.test"}, format="json"
        )
        self.assertEqual(response.status_code, 403)

    @override_settings(DEMO_MODE=False)
    def test_dev_seed_is_disabled_outside_demo_mode(self):
        response = APIClient().post("/api/v1/dev/seed", {"reset": False}, format="json")
        self.assertEqual(response.status_code, 403)

    def test_health_reports_database_and_demo_mode(self):
        response = APIClient().get("/api/v1/health")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["database"], "ok")
        self.assertTrue(body["demo_mode"])

    def test_health_reports_database_failure(self):
        with patch("api.views.connection.cursor", side_effect=DatabaseError("down")):
            response = APIClient().get("/api/v1/health")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["database"], "unavailable")

    def test_request_id_is_echoed(self):
        response = APIClient().get(
            "/api/v1/health", HTTP_X_REQUEST_ID="support-case-42"
        )
        self.assertEqual(response["X-Request-ID"], "support-case-42")

    def test_asset_pagination_and_invalid_limit(self):
        for index in range(3):
            Asset.objects.create(
                public_id=f"SL-P{index}",
                organization=self.organization,
                name=f"asset_{index}",
                row_count=1,
            )
        response = self.client.get("/api/v1/assets?limit=2&offset=2")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["count"], 3)
        self.assertEqual(body["limit"], 2)
        self.assertEqual(body["offset"], 2)
        self.assertEqual(len(body["results"]), 1)

        bad = self.client.get("/api/v1/assets?limit=abc")
        self.assertEqual(bad.status_code, 400)
        self.assertIn("limit", bad.json())

    @override_settings(SALUS_MAX_UPLOAD_BYTES=10)
    def test_upload_size_limit(self):
        upload = SimpleUploadedFile(
            "data.csv", b"a,b\n1,2\n3,4\n5,6\n", content_type="text/csv"
        )
        response = self.client.post("/api/v1/assets", {"file": upload}, format="multipart")
        self.assertEqual(response.status_code, 400)
        self.assertIn("MB", response.json()["detail"])

    def test_fake_xlsx_is_rejected(self):
        upload = SimpleUploadedFile(
            "data.xlsx",
            b"this is not a zip",
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        response = self.client.post("/api/v1/assets", {"file": upload}, format="multipart")
        self.assertEqual(response.status_code, 400)
        self.assertIn("XLSX", response.json()["detail"])

    def test_simulator_rejects_foreign_actor(self):
        Asset.objects.create(
            public_id="SL-PSRC",
            organization=self.organization,
            name="source",
            kind="ORIGINAL",
            row_count=10,
        )
        response = self.client.post(
            "/api/v1/simulator/run", {"actor_id": "USER-999"}, format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("actor_id", response.json()["detail"])
