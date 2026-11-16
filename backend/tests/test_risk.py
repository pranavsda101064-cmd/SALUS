from django.test import SimpleTestCase

from common.timeutil import destination_risk
from risk_engine.policy import WEIGHTS
from risk_engine.engine import _band


class RiskPolicyTests(SimpleTestCase):
    def test_weights_sum_to_one(self):
        self.assertAlmostEqual(sum(WEIGHTS.values()), 1.0, places=6)

    def test_band_thresholds(self):
        self.assertEqual(_band(10), "LOW")
        self.assertEqual(_band(30), "MEDIUM")
        self.assertEqual(_band(54), "MEDIUM")
        self.assertEqual(_band(55), "HIGH")
        self.assertEqual(_band(74), "HIGH")
        self.assertEqual(_band(75), "CRITICAL")

    def test_destination_risk(self):
        self.assertLess(destination_risk("internal_drive"), destination_risk("local_device"))
        self.assertLess(destination_risk("local_device"), destination_risk("external_domain.com"))
        self.assertEqual(destination_risk("gmail.com"), 70)
        self.assertGreaterEqual(destination_risk("public_url"), 90)
