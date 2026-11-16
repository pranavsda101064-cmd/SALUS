import json
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from django.test import SimpleTestCase, override_settings

from ai_reports.composer import _call_gemini, build_deterministic

FIXTURES = Path(__file__).resolve().parents[2] / "contract" / "fixtures"


def _load(name):
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def _namespace(value):
    return SimpleNamespace(**value)


def _fixture_incident():
    bundle = _load("incident_bundle.json")
    payload = bundle["incident"]
    created_at = datetime.fromisoformat(payload["created_at"].replace("Z", "+00:00"))
    match = dict(bundle["match"])
    match["public_id"] = match["match_id"]
    risk = dict(bundle["risk"])
    risk["public_id"] = risk["risk_id"]
    return SimpleNamespace(
        public_id=payload["incident_id"],
        title=payload["title"],
        severity=payload["severity"],
        match_id=payload["match_id"],
        created_at=created_at,
        evidence={
            "match": bundle["match"],
            "risk": bundle["risk"],
            "timeline_events": bundle["timeline"],
            "correlation": payload["correlation"],
            "limits": bundle["limits"],
        },
        source_asset=_namespace(bundle["source_asset"]),
        suspect_asset=_namespace(bundle["suspect_asset"]),
        match=_namespace(match),
        risk=_namespace(risk),
    )


def _gemini_response(payload):
    body = {"candidates": [{"content": {"parts": [{"text": json.dumps(payload)}]}}]}
    return SimpleNamespace(raise_for_status=lambda: None, json=lambda: body)


def _deterministic():
    return {
        "provider": "SALUS_TEMPLATE",
        "model": "",
        "grounding_refs": [],
        "summary": "fallback",
        "what_left": [],
        "who_moved_it": {"assessment": "", "confidence": "LOW", "basis": []},
        "why_flagged": [],
        "recommended_actions": [],
        "limitations": [],
    }


def _valid_gemini_payload():
    return {
        "summary": "Gemini summary.",
        "what_left": ["300 records"],
        "who_moved_it": {
            "assessment": "A user shared the file.",
            "confidence": "HIGH",
            "basis": ["EV-10021"],
        },
        "why_flagged": [{"factor": "S", "reason": "Identity columns.", "points": 32.2}],
        "recommended_actions": [
            {"priority": 1, "action": "Revoke access.", "why": "Share was external."}
        ],
        "limitations": ["A match is a lead."],
    }


class DeterministicReportTests(SimpleTestCase):
    def test_matches_contract_fixture(self):
        incident = _fixture_incident()
        expected = _load("report.json")
        with patch("ai_reports.composer._actor_label", return_value="Priya Sharma"):
            content = build_deterministic(incident)

        keys = [
            "provider",
            "model",
            "grounding_refs",
            "summary",
            "what_left",
            "who_moved_it",
            "why_flagged",
            "recommended_actions",
            "limitations",
            "correlation_basis",
            "generated_at",
        ]
        for key in keys:
            self.assertEqual(content[key], expected[key], key)


class GeminiFallbackTests(SimpleTestCase):
    @override_settings(GEMINI_API_KEY="fake-key", GEMINI_MODEL="gemini-test")
    def test_network_failure_returns_none_and_reason(self):
        incident = SimpleNamespace(
            public_id="INC-T1",
            title="Test incident",
            severity="HIGH",
            evidence={"match": {}, "risk": {}, "timeline_events": [], "correlation": {}},
            source_asset=None,
            suspect_asset=None,
        )
        with patch("ai_reports.composer.httpx.post", side_effect=RuntimeError("network down")):
            content, reason = _call_gemini(incident, _deterministic())
        self.assertIsNone(content)
        self.assertIn("Gemini call failed", reason)

    @override_settings(GEMINI_API_KEY="")
    def test_missing_key_skips_call(self):
        incident = SimpleNamespace(public_id="INC-T2", evidence={})
        content, reason = _call_gemini(incident, {})
        self.assertIsNone(content)
        self.assertIn("No GEMINI_API_KEY", reason)


class GeminiValidationTests(SimpleTestCase):
    @override_settings(GEMINI_API_KEY="fake-key", GEMINI_MODEL="gemini-test")
    def test_valid_payload_is_merged(self):
        incident = SimpleNamespace(evidence={}, public_id="INC-T3", title="t", severity="HIGH", source_asset=None, suspect_asset=None)
        with patch(
            "ai_reports.composer.httpx.post",
            return_value=_gemini_response(_valid_gemini_payload()),
        ):
            content, reason = _call_gemini(incident, _deterministic())
        self.assertEqual(reason, "")
        self.assertEqual(content["provider"], "GEMINI")
        self.assertEqual(content["model"], "gemini-test")
        self.assertEqual(content["summary"], "Gemini summary.")
        self.assertEqual(content["what_left"], ["300 records"])

    @override_settings(GEMINI_API_KEY="fake-key")
    def test_malformed_payload_falls_back(self):
        incident = SimpleNamespace(evidence={}, public_id="INC-T4", title="t", severity="HIGH", source_asset=None, suspect_asset=None)
        malformed = {
            "summary": 42,
            "what_left": "not a list",
            "who_moved_it": {"assessment": "x"},
            "why_flagged": ["not a dict"],
            "recommended_actions": [{"action": "x"}],
            "limitations": [1, 2],
        }
        with patch(
            "ai_reports.composer.httpx.post", return_value=_gemini_response(malformed)
        ):
            content, reason = _call_gemini(incident, _deterministic())
        self.assertIsNone(content)
        self.assertIn("schema validation", reason)

    @override_settings(GEMINI_API_KEY="fake-key")
    def test_missing_required_key_falls_back(self):
        incident = SimpleNamespace(evidence={}, public_id="INC-T5", title="t", severity="HIGH", source_asset=None, suspect_asset=None)
        payload = _valid_gemini_payload()
        payload.pop("limitations")
        with patch(
            "ai_reports.composer.httpx.post", return_value=_gemini_response(payload)
        ):
            content, reason = _call_gemini(incident, _deterministic())
        self.assertIsNone(content)
        self.assertIn("limitations", reason)
