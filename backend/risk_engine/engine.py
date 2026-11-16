from datetime import timedelta

from anomaly_model.engine import score_event
from common.ids import next_public_id
from common.timeutil import destination_risk, ist_parts
from events.models import Event
from risk_engine.models import RiskAssessment
from risk_engine.policy import POLICY_VERSION, WEIGHTS


def _band(total):
    if total >= 75:
        return "CRITICAL"
    if total >= 55:
        return "HIGH"
    if total >= 30:
        return "MEDIUM"
    return "LOW"


def _s_factor(query_asset, match):
    matched_names = set(match.matched_columns or [])
    matched = [col for col in query_asset.columns if col["name"] in matched_names]
    if not matched:
        matched = [
            col for col in query_asset.columns if col.get("sensitivity_score", 0) >= 55
        ][:3]
    if not matched:
        return {"score": max(10, query_asset.sensitivity_score), "basis": "No sensitive column was matched."}

    values = [int(col.get("sensitivity_score", 10)) for col in matched]
    highest = max(values)
    average = sum(values) / len(values)
    score = int(round(0.6 * highest + 0.4 * average))
    strong = [col for col in matched if col.get("sensitivity_score", 0) >= 70]
    types = sorted({col.get("pii_type", "OTHER") for col in strong})
    basis = f"{len(matched)} matched columns, {len(strong)} of them identity, contact or financial"
    if types:
        basis += f": {', '.join(types)}"
    return {"score": min(100, score), "basis": basis, "matched_columns": sorted(matched_names)}


def _d_factor(share_events, download_event):
    if share_events:
        event = max(share_events, key=lambda item: destination_risk(item.destination))
        return {
            "score": destination_risk(event.destination),
            "destination": event.destination,
            "trust": "UNKNOWN_EXTERNAL" if destination_risk(event.destination) >= 60 else "INFERRED_FROM_EVENT",
            "event_id": event.event_id,
            "basis": f"Recorded {event.action} to {event.destination}.",
        }
    if download_event is not None:
        return {
            "score": destination_risk(download_event.destination),
            "destination": download_event.destination or "unknown",
            "trust": "LOCAL_DEVICE",
            "event_id": download_event.event_id,
            "basis": "Only a local download was recorded. No external destination event exists.",
        }
    return {
        "score": 20,
        "destination": "unknown",
        "trust": "NO_EVIDENCE",
        "event_id": "",
        "basis": "No destination event was recorded. This is a match only.",
    }


def _e_factor(organization, download_event, share_events, match):
    score = 10
    reasons = ["MATCH_FOUND"]
    details = ["Match exists between the uploaded file and a stored dataset."]

    if download_event is not None:
        local, hour, weekday = ist_parts(download_event.timestamp)
        if hour < 8 or hour >= 20 or weekday >= 5:
            score += 25
            reasons.append("AFTER_HOURS")
            details.append(f"Download recorded at {local.strftime('%H:%M')} IST.")
        if share_events:
            earliest = min(event.timestamp for event in share_events)
            if earliest - download_event.timestamp <= timedelta(hours=24):
                score += 25
                reasons.append("DOWNLOAD_THEN_EXTERNAL_SHARE")
                details.append("An external share follows the download within 24 hours.")
        try:
            rows = int((download_event.evidence or {}).get("rows") or 0)
        except (TypeError, ValueError):
            rows = 0
        if rows >= 500:
            score += 15
            reasons.append("BULK_VOLUME")
            details.append(f"Download covered {rows} rows.")
        recent = Event.objects.filter(
            organization=organization,
            actor_id=download_event.actor_id,
            asset_id=download_event.asset_id,
            action__in=["FILE_DOWNLOADED", "FILE_COPIED"],
            timestamp__gte=download_event.timestamp - timedelta(days=7),
            timestamp__lte=download_event.timestamp,
        ).count()
        if recent >= 3:
            score += 10
            reasons.append("REPEATED_ACCESS")
            details.append(f"{recent} download or copy events in the preceding 7 days.")
    elif share_events:
        score += 15
        reasons.append("EXTERNAL_SHARE_ONLY")
        details.append("An external share was recorded without a download or copy event.")

    canary = match.canary or {}
    if canary.get("found"):
        score += 20
        reasons.append("CANARY_PRESENT")
        details.append(f"Canary record {canary.get('canary_id')} was found in the copy.")
    if match.match_score >= 0.8:
        score += 15
        reasons.append("HIGH_MATCH_CONFIDENCE")
        details.append(f"Match score is {match.match_score}.")
    return {"score": min(100, score), "reasons": reasons, "details": details}


def compute_risk(organization, query_asset, source_asset, match, download_event, share_events):
    s_factor = _s_factor(query_asset, match)
    d_factor = _d_factor(share_events, download_event)
    if download_event is not None:
        behaviour = score_event(organization, download_event)
    else:
        behaviour = {
            "score": 50,
            "percentile": 50,
            "top_features": [],
            "basis": "No download event exists, so there is no behaviour to compare.",
        }
    e_factor = _e_factor(organization, download_event, share_events, match)

    total = int(
        round(
            WEIGHTS["S"] * s_factor["score"]
            + WEIGHTS["D"] * d_factor["score"]
            + WEIGHTS["B"] * behaviour["score"]
            + WEIGHTS["E"] * e_factor["score"]
        )
    )
    return {
        "risk_id": next_public_id(RiskAssessment, "public_id", "RS", floor=3001),
        "total": total,
        "band": _band(total),
        "weights": WEIGHTS,
        "policy_version": POLICY_VERSION,
        "factors": {
            "S": s_factor,
            "D": d_factor,
            "B": behaviour,
            "E": e_factor,
        },
    }


def persist_risk(organization, incident, risk):
    return RiskAssessment.objects.create(
        public_id=risk["risk_id"],
        organization=organization,
        incident=incident,
        total=risk["total"],
        band=risk["band"],
        factors=risk["factors"],
        weights=risk["weights"],
        policy_version=risk["policy_version"],
    )
