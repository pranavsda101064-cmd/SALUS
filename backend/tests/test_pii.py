import pandas as pd
from django.test import SimpleTestCase

from common.text import normalize_value, rarity_weight, sanitize_text
from pii_scan import verhoeff
from pii_scan.detect import aggregate_sensitivity, detect_columns
from pii_scan.gstin import checksum_char, is_valid_gstin


class VerhoeffTests(SimpleTestCase):
    def test_known_vector(self):
        self.assertTrue(verhoeff.validate("2363"))

    def test_generated_aadhaar_is_valid(self):
        prefix = "23456789012"
        number = prefix + verhoeff.generate_check_digit(prefix)
        self.assertEqual(len(number), 12)
        self.assertTrue(verhoeff.is_valid_aadhaar(number))

    def test_single_digit_corruption_is_invalid(self):
        prefix = "23456789012"
        number = prefix + verhoeff.generate_check_digit(prefix)
        broken = number[:-1] + str((int(number[-1]) + 1) % 10)
        self.assertFalse(verhoeff.is_valid_aadhaar(broken))

    def test_first_digit_zero_or_one_is_invalid(self):
        for first in ["0", "1"]:
            prefix = first + "2345678901"
            number = prefix + verhoeff.generate_check_digit(prefix)
            self.assertFalse(verhoeff.is_valid_aadhaar(number))

    def test_wrong_length_is_invalid(self):
        self.assertFalse(verhoeff.is_valid_aadhaar("12345678901"))


class PiiDetectionTests(SimpleTestCase):
    def _aadhaar(self, valid=True):
        prefix = "23456789012"
        number = prefix + verhoeff.generate_check_digit(prefix)
        if not valid:
            number = number[:-1] + str((int(number[-1]) + 1) % 10)
        return number

    def test_india_pii_columns(self):
        df = pd.DataFrame(
            {
                "aadhaar": [self._aadhaar() for _ in range(9)] + [self._aadhaar(False)],
                "pan": ["ABCDE1234F"] * 10,
                "gstin": ["27ABCDE1234F1Z5"] * 10,
                "email": ["priya@example.test"] * 10,
                "phone": ["+919000000107"] * 10,
                "upi": ["priya@okhdfcbank"] * 10,
                "full_name": ["Priya Sharma"] * 10,
                "city": ["Mumbai"] * 10,
                "account_no": ["512345678901"] * 10,
            }
        )
        columns = {column["name"]: column for column in detect_columns(df)}
        self.assertEqual(columns["aadhaar"]["pii_type"], "AADHAAR")
        self.assertEqual(columns["aadhaar"]["invalid_count"], 1)
        self.assertEqual(columns["pan"]["pii_type"], "PAN")
        self.assertEqual(columns["gstin"]["pii_type"], "GSTIN")
        self.assertEqual(columns["email"]["pii_type"], "EMAIL")
        self.assertEqual(columns["phone"]["pii_type"], "PHONE")
        self.assertEqual(columns["upi"]["pii_type"], "UPI_ID")
        self.assertEqual(columns["full_name"]["pii_type"], "NAME")
        self.assertEqual(columns["city"]["pii_type"], "LOCATION")
        self.assertEqual(columns["account_no"]["pii_type"], "FINANCIAL_ACCOUNT")
        score, label = aggregate_sensitivity(list(columns.values()))
        self.assertEqual(label, "CRITICAL")
        self.assertGreaterEqual(score, 90)

    def test_ordinary_column_stays_low(self):
        df = pd.DataFrame({"notes": ["hello", "call back", "n/a"]})
        column = detect_columns(df)[0]
        self.assertEqual(column["pii_type"], "OTHER")
        self.assertEqual(column["sensitivity"], "LOW")

    def test_real_gstin_checksum_column(self):
        gstin = "27AAPFU0939F1ZV"
        self.assertTrue(is_valid_gstin(gstin))
        column = detect_columns(pd.DataFrame({"gstin": [gstin] * 10}))[0]
        self.assertEqual(column["pii_type"], "GSTIN")
        self.assertEqual(column["valid_count"], 10)
        self.assertEqual(column["invalid_count"], 0)


class GstinChecksumTests(SimpleTestCase):
    def test_known_vectors(self):
        self.assertEqual(checksum_char("27AAPFU0939F1Z"), "V")
        self.assertEqual(checksum_char("29AAGCB7383J1Z"), "4")
        self.assertTrue(is_valid_gstin("27AAPFU0939F1ZV"))
        self.assertTrue(is_valid_gstin("29AAGCB7383J1Z4"))

    def test_wrong_check_digit_is_invalid(self):
        self.assertFalse(is_valid_gstin("27AAPFU0939F1Z5"))
        self.assertFalse(is_valid_gstin("27ABCDE1234F1Z5"))

    def test_bad_shape_is_invalid(self):
        self.assertFalse(is_valid_gstin("27AAPFU0939F1Z"))
        self.assertFalse(is_valid_gstin(""))
        self.assertFalse(is_valid_gstin(None))


class NormalizationTests(SimpleTestCase):
    def test_phone_separators_are_removed(self):
        self.assertEqual(normalize_value("+91 90000 00107"), "919000000107")

    def test_whitespace_and_case_are_normalized(self):
        self.assertEqual(normalize_value("  Priya   Sharma "), "priya sharma")

    def test_rare_weight_beats_common_weight(self):
        rare = rarity_weight(1000, 1)
        common = rarity_weight(1000, 900)
        self.assertGreater(rare, common * 4)

    def test_no_em_dash_survives(self):
        self.assertNotIn("\u2014", sanitize_text("left \u2014 right"))
