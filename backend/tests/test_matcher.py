import pandas as pd
from django.test import TestCase, override_settings
from django.utils import timezone

from assets.models import Asset
from data_dna.matcher import find_best_match
from data_dna.models import CanaryIssuance
from data_dna.service import prepare_asset
from demo.generator import CANARY_RECIPIENT, CANARY_TOKEN, COLUMNS, generate_rows
from demo.seed import _canary_hashes
from organizations.models import Organization


class GhostCopyMatchingTests(TestCase):
    def test_partial_copy_survives_column_and_row_loss(self):
        organization = Organization.objects.create(
            id="ORG-T1", name="Test Traders", slug="test-traders"
        )
        all_rows = generate_rows(seed=42)
        normal_rows = [row for row in all_rows if not row["customer_ref"].startswith("CN-007")]
        canary_rows_all = [row for row in all_rows if row["customer_ref"].startswith("CN-007")]
        rows = normal_rows[:200] + canary_rows_all
        source_df = pd.DataFrame(rows, columns=COLUMNS)
        source, _fp = prepare_asset(
            organization=organization,
            name="customer_master_v1",
            filename="customer_master_v1.xlsx",
            df=source_df,
            kind="ORIGINAL",
            watermark="SALUS-WM-0727",
            canary_rows=5,
            id_floor=9281,
        )
        canary_rows, canary_hashes = _canary_hashes(rows)
        CanaryIssuance.objects.create(
            public_id="CN-007",
            organization=organization,
            asset=source,
            recipient=CANARY_RECIPIENT,
            token=CANARY_TOKEN,
            value_hashes=canary_hashes,
            row_labels=[row["customer_ref"] for row in canary_rows],
            issued_at=timezone.now(),
        )

        canaries = source_df[source_df["customer_ref"].str.startswith("CN-007")].head(3)
        normal = source_df[~source_df["customer_ref"].str.startswith("CN-007")].head(77)
        ghost_df = pd.concat([normal, canaries]).sample(frac=1.0, random_state=7)
        ghost_df = ghost_df.drop(columns=["customer_ref", "city", "account_no"])
        ghost_df = ghost_df.reset_index(drop=True)

        suspect, suspect_fp = prepare_asset(
            organization=organization,
            name="clients_export_final",
            filename="clients_export_final.csv",
            df=ghost_df,
            kind="SUSPECT",
            id_floor=9310,
        )
        match, matched_source, scanned = find_best_match(organization, suspect, suspect_fp)

        self.assertIsNotNone(match)
        self.assertEqual(matched_source.pk, source.pk)
        self.assertEqual(scanned, 1)
        self.assertGreaterEqual(match.match_score, 0.9)
        self.assertEqual(match.matched_rows, 80)
        self.assertAlmostEqual(match.recall_vs_original, round(80 / 205, 4), places=4)
        self.assertTrue(match.canary["found"])
        self.assertEqual(match.canary["matched_rows"], 3)
        self.assertIn("customer_ref", match.dropped_columns)
        self.assertIn("city", match.dropped_columns)
        self.assertNotIn("city", match.matched_columns)
        self.assertGreater(match.evidence["cell_recall"], 0.2)
        self.assertTrue(match.evidence["watermark_stripped"])


class MatchThresholdTests(TestCase):
    def test_threshold_setting_controls_meaningful_match(self):
        organization = Organization.objects.create(
            id="ORG-T2", name="Threshold Traders", slug="threshold-traders"
        )
        df = pd.DataFrame(
            {
                "email": [f"user{index}@example.test" for index in range(5)],
                "pan": [f"ABCDE123{index}F" for index in range(5)],
            }
        )
        prepare_asset(
            organization=organization,
            name="source",
            filename="source.csv",
            df=df,
            kind="ORIGINAL",
            id_floor=9281,
        )
        suspect, suspect_fp = prepare_asset(
            organization=organization,
            name="suspect",
            filename="suspect.csv",
            df=df,
            kind="SUSPECT",
            id_floor=9310,
        )

        with override_settings(SALUS_MATCH_THRESHOLD=0.3):
            match, _source, _scanned = find_best_match(organization, suspect, suspect_fp)
        self.assertIsNotNone(match)

        with override_settings(SALUS_MATCH_THRESHOLD=1.0):
            match, _source, _scanned = find_best_match(organization, suspect, suspect_fp)
        self.assertIsNone(match)
