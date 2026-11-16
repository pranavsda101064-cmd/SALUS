import hashlib
import json
import logging
import re
import time

import httpx
from django.conf import settings

from common.ids import next_public_id
from common.text import sanitize_structure
from common.timeutil import parse_timestamp, to_utc_iso

logger = logging.getLogger(__name__)

LIMITATIONS = [
    "SALUS cannot see USB copies, screenshots, or retyped data.",
    "A match is a lead, not proof of intent.",
    "Only events from connected or simulated sources are visible.",
]

REQUIRED_KEYS = [
    "summary",
    "what_left",
    "who_moved_it",
    "why_flagged",
    "recommended_actions",
    "limitations",
]

CONFIDENCE_LEVELS = {"HIGH", "MEDIUM", "LOW"}
RISK_FACTORS = {"S", "D", "B", "E"}
REF_PATTERN = re.compile(r"\b(?:EV|MT|RS|INC|RP|SL|USER|ORG|INV|CN)-[A-Z0-9]+\b")


def _is_text(value):
    return isinstance(value, str) and bool(value.strip())


def _is_text_list(value):
    return isinstance(value, list) and all(_is_text(item) for item in value)


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _valid_field(key, value):
    if key == "summary":
        return _is_text(value)
    if key in {"what_left", "limitations"}:
        return _is_text_list(value)
    if key == "who_moved_it":
        return (
            isinstance(value, dict)
            and _is_text(value.get("assessment"))
            and value.get("confidence") in CONFIDENCE_LEVELS
            and _is_text_list(value.get("basis"))
        )
    if key == "why_flagged":
        return isinstance(value, list) and all(
            isinstance(item, dict)
            and item.get("factor") in RISK_FACTORS
            and _is_text(item.get("reason"))
            and _is_number(item.get("points"))
            for item in value
        )
    if key == "recommended_actions":
        return isinstance(value, list) and all(
            isinstance(item, dict)
            and isinstance(item.get("priority"), int)
            and not isinstance(item.get("priority"), bool)
            and _is_text(item.get("action"))
            and _is_text(item.get("why"))
            for item in value
        )
    return False


def _refs(incident):
    evidence = incident.evidence or {}
    refs = []
    match = getattr(incident, "match", None)
    if getattr(incident, "match_id", None) and match is not None:
        refs.append(match.public_id)
    risk = getattr(incident, "risk", None)
    if risk is not None:
        refs.append(risk.public_id)
    for event in evidence.get("timeline_events", []):
        refs.append(event.get("event_id"))
    return [ref for ref in refs if ref]


def _allowed_refs(incident):
    refs = set(_refs(incident))
    refs.add(incident.public_id)
    if incident.source_asset is not None:
        refs.add(incident.source_asset.public_id)
    if incident.suspect_asset is not None:
        refs.add(incident.suspect_asset.public_id)
    match = getattr(incident, "match", None)
    if match is not None:
        canary = match.canary or {}
        if canary.get("canary_id"):
            refs.add(canary["canary_id"])
    investigation = getattr(incident, "investigation", None)
    if investigation is not None:
        refs.add(investigation.public_id)
    for event in (incident.evidence or {}).get("timeline_events", []):
        if event.get("event_id"):
            refs.add(event["event_id"])
        if event.get("actor_id"):
            refs.add(event["actor_id"])
    return {ref for ref in refs if ref}


def _iter_strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _iter_strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from _iter_strings(item)


def _cited_refs(payload):
    found = set()
    for text in _iter_strings(payload):
        found.update(REF_PATTERN.findall(text))
    return found


def _evidence_hash(incident):
    payload = json.dumps(
        incident.evidence or {},
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
        default=str,
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _actor_label(actor_id):
    from organizations.models import User

    user = User.objects.filter(public_id=actor_id).first()
    if user:
        return user.name
    return actor_id


def _pii_phrase(match):
    names = match.matched_columns or []
    if not names:
        return "no sensitive columns were confirmed"
    return ", ".join(names[:6])


def build_deterministic(incident):
    evidence = incident.evidence or {}
    match = incident.match
    risk = getattr(incident, "risk", None)
    source = incident.source_asset
    suspect = incident.suspect_asset
    timeline = evidence.get("timeline_events", [])
    correlation = evidence.get("correlation", {})

    download_event = next(
        (event for event in timeline if event.get("action") in {"FILE_DOWNLOADED", "FILE_COPIED"}),
        None,
    )
    share_event = next(
        (event for event in timeline if event.get("action") == "EXTERNAL_SHARE"), None
    )
    canary = (match.canary if match else {}) or {}
    percent = int(round((match.recall_vs_original if match else 0) * 100))
    matched_rows = match.matched_rows if match else 0

    summary = (
        f"The uploaded file reuses {matched_rows} of {source.row_count} records "
        f"({percent} percent) from {source.name}."
    )
    if match and match.matched_columns:
        summary += f" Matched columns include {_pii_phrase(match)}."
    if canary.get("found"):
        summary += (
            f" Canary record {canary.get('canary_id')} was issued to "
            f"{canary.get('recipient')} and appears in the copy."
        )
    if not timeline:
        summary += " No download or share event was found, so the copy is linked by the match only."

    what_left = [
        f"{matched_rows} customer records",
        f"{len(match.matched_columns) if match else 0} columns corroborated in the copy",
    ]
    if match and match.dropped_columns:
        what_left.append("Columns not present: " + ", ".join(match.dropped_columns))
    if canary.get("found"):
        what_left.append(f"Canary values from issuance {canary.get('canary_id')}")

    if download_event and share_event:
        download_time = parse_timestamp(download_event.get("timestamp"))
        share_time = parse_timestamp(share_event.get("timestamp"))
        gap = ""
        if download_time and share_time:
            minutes = int((share_time - download_time).total_seconds() // 60)
            gap = f" about {minutes} minutes later"
        assessment = (
            f"{_actor_label(download_event.get('actor_id'))} was recorded downloading "
            f"{source.name} and an external share to "
            f"{share_event.get('destination')} followed{gap}."
        )
        confidence = "HIGH"
    elif share_event:
        assessment = (
            f"An external share to {share_event.get('destination')} was recorded for "
            f"{source.name}. No download or copy event was found."
        )
        confidence = "MEDIUM"
    elif download_event:
        assessment = (
            f"{_actor_label(download_event.get('actor_id'))} was recorded downloading "
            f"{source.name}. No external destination event was stored."
        )
        confidence = "MEDIUM"
    else:
        assessment = (
            "No download or share event was found in connected or simulated sources. "
            "The copy is linked to the source by the stored match only."
        )
        confidence = "LOW"

    why_flagged = []
    if risk is not None:
        weights = risk.weights or {}
        for factor in ["S", "D", "B", "E"]:
            data = (risk.factors or {}).get(factor, {})
            points = round(float(weights.get(factor, 0)) * float(data.get("score", 0)), 1)
            if factor == "S":
                reason = data.get("basis") or "Sensitivity of the matched columns."
            elif factor == "D":
                reason = data.get("basis") or "Destination risk from recorded events."
            elif factor == "B":
                reason = data.get("basis") or "Unusual behaviour compared with the baseline."
            else:
                reason = ", ".join(data.get("reasons", [])) or "Event sequence severity."
            why_flagged.append({"factor": factor, "reason": reason, "points": points})

    actions = []
    if share_event:
        actions.append(
            {
                "priority": 1,
                "action": "Revoke outside access and confirm whether the recipient still holds the file.",
                "why": f"A recorded share names {share_event.get('destination')}.",
            }
        )
    if canary.get("found"):
        actions.append(
            {
                "priority": len(actions) + 1,
                "action": "Contact the canary recipient and ask whether the copy was forwarded.",
                "why": f"Canary {canary.get('canary_id')} links this copy to one issuance.",
            }
        )
    high_sensitivity = bool(
        match
        and any(
            column.get("sensitivity") in {"HIGH", "CRITICAL"}
            for column in (suspect.columns if suspect else [])
            if column.get("name") in set(match.matched_columns or [])
        )
    )
    if high_sensitivity:
        actions.append(
            {
                "priority": len(actions) + 1,
                "action": "Review whether affected customers must be notified.",
                "why": "Identity, contact or financial columns are present in the corroborated rows.",
            }
        )
    actions.append(
        {
            "priority": len(actions) + 1,
            "action": f"Restrict downloads on {source.name} and alert on future exports.",
            "why": "The source dataset has no download control in this demo.",
        }
    )

    return {
        "provider": "SALUS_TEMPLATE",
        "model": "",
        "grounding_refs": _refs(incident),
        "summary": summary,
        "what_left": what_left,
        "who_moved_it": {
            "assessment": assessment,
            "confidence": confidence,
            "basis": [
                event.get("event_id")
                for event in timeline
                if event.get("event_id") and event.get("action") != "SUSPECT_UPLOAD"
            ],
        },
        "why_flagged": why_flagged,
        "recommended_actions": actions,
        "limitations": LIMITATIONS,
        "correlation_basis": correlation.get("basis", ""),
        "generated_at": to_utc_iso(incident.created_at),
    }


def _gemini_prompt(incident, deterministic):
    evidence = incident.evidence or {}
    payload = {
        "incident": {
            "incident_id": incident.public_id,
            "title": incident.title,
            "severity": incident.severity,
        },
        "source_asset": {
            "asset_id": incident.source_asset.public_id if incident.source_asset else None,
            "name": incident.source_asset.name if incident.source_asset else None,
            "row_count": incident.source_asset.row_count if incident.source_asset else None,
        },
        "suspect_asset": {
            "asset_id": incident.suspect_asset.public_id if incident.suspect_asset else None,
            "name": incident.suspect_asset.name if incident.suspect_asset else None,
            "row_count": incident.suspect_asset.row_count if incident.suspect_asset else None,
        },
        "match": evidence.get("match"),
        "risk": evidence.get("risk"),
        "timeline": evidence.get("timeline_events", []),
        "correlation": evidence.get("correlation", {}),
        "limits": LIMITATIONS,
    }
    system = (
        "You are SALUS, a data investigation assistant for small businesses in India. "
        "Use ONLY the structured evidence in the user message. Never invent events, people, "
        "destinations, or numbers. A match is a lead, not proof of intent. Do not claim to see "
        "USB copies, screenshots, or retyped data. Reply with JSON only, no markdown. "
        "Never use em dashes. Keep the report practical and short."
    )
    schema = {
        "summary": "string, 2 sentences",
        "what_left": ["string"],
        "who_moved_it": {
            "assessment": "string",
            "confidence": "HIGH or MEDIUM or LOW",
            "basis": ["event or match ids"],
        },
        "why_flagged": [{"factor": "S or D or B or E", "reason": "string", "points": 0.0}],
        "recommended_actions": [{"priority": 1, "action": "string", "why": "string"}],
        "limitations": ["string"],
    }
    user = (
        "Evidence:\n"
        + json.dumps(payload, ensure_ascii=True, default=str)
        + "\n\nReturn JSON with this schema:\n"
        + json.dumps(schema)
        + "\nUse only ids that appear in the evidence."
    )
    return system, user


def _call_gemini(incident, deterministic):
    if not settings.GEMINI_API_KEY:
        return None, "No GEMINI_API_KEY is configured"
    system, user = _gemini_prompt(incident, deterministic)
    model = settings.GEMINI_MODEL
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model}:generateContent"
    )
    body = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": [{"text": user}]}],
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.2},
    }
    timeout = float(getattr(settings, "GEMINI_TIMEOUT", 8.0))
    attempts = max(1, int(getattr(settings, "GEMINI_RETRIES", 1)) + 1)
    last_error = None
    for attempt in range(attempts):
        try:
            response = httpx.post(
                url,
                headers={"x-goog-api-key": settings.GEMINI_API_KEY},
                json=body,
                timeout=timeout,
            )
            response.raise_for_status()
            data = response.json()
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            text = text.strip()
            if text.startswith("```"):
                text = text.strip("`")
                if text.startswith("json"):
                    text = text[4:]
            parsed = json.loads(text)
            if not isinstance(parsed, dict):
                raise ValueError("Gemini did not return a JSON object")
            invalid = [key for key in REQUIRED_KEYS if not _valid_field(key, parsed.get(key))]
            if invalid:
                raise ValueError(
                    "Gemini response failed schema validation: " + ", ".join(sorted(invalid))
                )
            allowed_refs = _allowed_refs(incident)
            cited = _cited_refs({key: parsed.get(key) for key in REQUIRED_KEYS})
            unknown = sorted(cited - allowed_refs)
            if unknown:
                raise ValueError(
                    "Gemini cited refs that are not in the evidence: " + ", ".join(unknown)
                )
            merged = dict(deterministic)
            for key in REQUIRED_KEYS:
                if key in {"why_flagged", "limitations"}:
                    continue
                merged[key] = parsed[key]
            merged["why_flagged"] = deterministic["why_flagged"]
            merged["limitations"] = deterministic["limitations"]
            merged["grounding_refs"] = deterministic["grounding_refs"]
            merged["provider"] = "GEMINI"
            merged["model"] = model
            return merged, ""
        except httpx.HTTPStatusError as exc:
            last_error = exc
            if exc.response is not None and exc.response.status_code < 500:
                break
        except Exception as exc:
            last_error = exc
        if attempt + 1 < attempts:
            time.sleep(0.25 * (attempt + 1))
    logger.warning("Gemini report failed, using fallback: %s", last_error)
    if isinstance(last_error, ValueError):
        return None, f"Gemini response rejected: {last_error}"
    return None, f"Gemini call failed: {last_error.__class__.__name__}"


def generate_report(incident):
    from ai_reports.models import Report

    deterministic = build_deterministic(incident)
    content, fallback_reason = _call_gemini(incident, deterministic)
    if content is None:
        content = deterministic
        if fallback_reason:
            if "No GEMINI_API_KEY" in fallback_reason:
                content["engine_note"] = (
                    "Gemini is not configured in this build. "
                    "The deterministic composer produced this report."
                )
            else:
                content["engine_note"] = (
                    "Gemini was unavailable. The deterministic composer produced this report."
                )
    content = sanitize_structure(content)
    content["generated_at"] = to_utc_iso(incident.created_at)
    evidence_hash = _evidence_hash(incident)
    content["evidence_hash"] = evidence_hash

    report = Report.objects.filter(incident=incident).first()
    if report is None:
        report = Report.objects.create(
            public_id=next_public_id(Report, "public_id", "RP", floor=5001),
            organization=incident.organization,
            incident=incident,
            provider=content.get("provider", "SALUS_TEMPLATE"),
            model=content.get("model", ""),
            grounding_refs=content.get("grounding_refs", []),
            evidence_hash=evidence_hash,
            content=content,
        )
    else:
        report.provider = content.get("provider", "SALUS_TEMPLATE")
        report.model = content.get("model", "")
        report.grounding_refs = content.get("grounding_refs", [])
        report.evidence_hash = evidence_hash
        report.content = content
        report.save(
            update_fields=[
                "provider",
                "model",
                "grounding_refs",
                "evidence_hash",
                "content",
            ]
        )
    return report
