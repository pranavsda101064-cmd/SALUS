from datetime import timedelta

from django.db import transaction

from ai_reports.composer import LIMITATIONS, generate_report
from api.serializers import serialize_event, serialize_match
from common.files import extract_watermark, parse_uploaded_file
from common.ids import next_public_id
from common.text import hash_bytes
from common.timeutil import destination_risk, to_utc_iso
from data_dna.matcher import find_best_match
from data_dna.service import prepare_asset
from events.models import Event
from events.services import record_event
from incidents.models import Incident, Investigation
from organizations.audit import log_audit
from risk_engine.engine import compute_risk, persist_risk

CORRELATION_DAYS = 180


def _dedupe_shares(events):
    by_destination = {}
    for event in events:
        current = by_destination.get(event.destination)
        if current is None or (event.timestamp, event.event_id) > (
            current.timestamp,
            current.event_id,
        ):
            by_destination[event.destination] = event
    return sorted(by_destination.values(), key=lambda item: item.timestamp)


def correlate(organization, source_asset, upload_time):
    candidates = list(
        Event.objects.filter(
            organization=organization,
            asset_id=source_asset.public_id,
            action__in=["FILE_DOWNLOADED", "FILE_COPIED"],
            timestamp__lte=upload_time,
            timestamp__gte=upload_time - timedelta(days=CORRELATION_DAYS),
        ).order_by("-timestamp")[:10]
    )
    if not candidates:
        shares = list(
            Event.objects.filter(
                organization=organization,
                asset_id=source_asset.public_id,
                action="EXTERNAL_SHARE",
                timestamp__lte=upload_time,
                timestamp__gte=upload_time - timedelta(days=CORRELATION_DAYS),
            ).order_by("-timestamp")[:10]
        )
        external = [event for event in shares if destination_risk(event.destination) >= 60]
        if external:
            chosen_shares = _dedupe_shares(external)
            return {
                "download_event": None,
                "share_events": chosen_shares,
                "basis": (
                    f"Correlated {len(chosen_shares)} external share event(s) with no download "
                    "or copy event for the source dataset."
                ),
                "found_activity": True,
                "share_only": True,
            }
        return {
            "download_event": None,
            "share_events": [],
            "basis": (
                "No download, copy or external share event was recorded for the source "
                f"dataset in the last {CORRELATION_DAYS} days."
            ),
            "found_activity": False,
            "share_only": False,
        }

    chosen = None
    chosen_shares = []
    for candidate in candidates:
        shares = list(
            Event.objects.filter(
                organization=organization,
                actor_id=candidate.actor_id,
                action="EXTERNAL_SHARE",
                timestamp__gte=candidate.timestamp,
                timestamp__lte=candidate.timestamp + timedelta(hours=48),
            ).order_by("timestamp")
        )
        external = [event for event in shares if destination_risk(event.destination) >= 60]
        if external:
            chosen = candidate
            chosen_shares = _dedupe_shares(external)
            break

    if chosen is None:
        chosen = candidates[0]
        chosen_shares = []

    basis = (
        f"Correlated download {chosen.event_id} by {chosen.actor_id} with "
        f"{len(chosen_shares)} external share event(s)."
        if chosen_shares
        else f"Correlated download {chosen.event_id} by {chosen.actor_id}. No external share was recorded."
    )
    return {
        "download_event": chosen,
        "share_events": chosen_shares,
        "basis": basis,
        "found_activity": True,
        "share_only": False,
    }


def _existing_result(investigation):
    return {
        "matched": investigation.incident_id is not None,
        "duplicate": True,
        "suspect_asset": investigation.suspect_asset,
        "source_asset": investigation.source_asset,
        "match": investigation.match,
        "investigation": investigation,
        "incident": investigation.incident,
        "scanned_sources": 0,
    }


@transaction.atomic
def create_investigation(organization, user, uploaded_file):
    uploaded_file.seek(0)
    raw_bytes = uploaded_file.read()
    uploaded_file.seek(0)
    exact_sha = hash_bytes(raw_bytes)
    filename = uploaded_file.name or "upload"

    existing = (
        Investigation.objects.filter(organization=organization, input_sha256=exact_sha)
        .select_related("match", "incident", "source_asset", "suspect_asset")
        .first()
    )
    if existing is not None:
        log_audit(
            organization,
            user,
            "INVESTIGATION_DUPLICATE",
            "INVESTIGATION",
            existing.public_id,
            {"sha256": exact_sha},
        )
        return _existing_result(existing)

    df, raw_bytes, filename = parse_uploaded_file(uploaded_file)
    exact_sha = hash_bytes(raw_bytes)
    watermark = extract_watermark(raw_bytes, filename)
    name = filename.rsplit(".", 1)[0][:200]

    suspect_asset, fingerprints = prepare_asset(
        organization=organization,
        name=name,
        filename=filename,
        df=df,
        kind="SUSPECT",
        exact_sha256=exact_sha,
        watermark=watermark,
        id_floor=9310,
    )

    match, source_asset, scanned = find_best_match(organization, suspect_asset, fingerprints)
    if match is None:
        investigation = Investigation.objects.create(
            public_id=next_public_id(Investigation, "public_id", "INV", floor=6001),
            organization=organization,
            created_by=user,
            source_asset=None,
            suspect_asset=suspect_asset,
            match=None,
            incident=None,
            input_filename=filename,
            input_sha256=exact_sha,
            input_rows=len(df),
            input_columns=len(df.columns),
            status="NO_MATCH",
        )
        log_audit(
            organization,
            user,
            "INVESTIGATION_CREATED",
            "INVESTIGATION",
            investigation.public_id,
            {
                "status": "NO_MATCH",
                "rows": len(df),
                "columns": len(df.columns),
                "sha256": exact_sha,
            },
        )
        return {
            "matched": False,
            "duplicate": False,
            "suspect_asset": suspect_asset,
            "source_asset": None,
            "match": None,
            "investigation": investigation,
            "incident": None,
            "scanned_sources": scanned,
        }

    upload_event, _ = record_event(
        organization=organization,
        event_id=next_public_id(Event, "event_id", "EV", floor=10100),
        actor_id=user.public_id,
        asset_id=suspect_asset.public_id,
        action="SUSPECT_UPLOAD",
        source="INTAKE",
        destination="investigation_intake",
        timestamp=None,
        evidence={
            "filename": filename,
            "rows": len(df),
            "bytes": len(raw_bytes),
            "simulated": False,
        },
        simulated=False,
    )

    upload_time = upload_event.timestamp
    correlation = correlate(organization, source_asset, upload_time)
    download_event = correlation["download_event"]
    share_events = correlation["share_events"]

    timeline = list(share_events) + ([download_event] if download_event else []) + [upload_event]
    timeline.sort(key=lambda event: event.timestamp)
    timeline_payload = [serialize_event(event) for event in timeline]

    risk = compute_risk(
        organization, suspect_asset, source_asset, match, download_event, share_events
    )
    match_payload = serialize_match(match)
    match_payload["created_at"] = to_utc_iso(match.created_at)

    incident = Incident.objects.create(
        public_id=next_public_id(Incident, "public_id", "INC", floor=4001),
        organization=organization,
        title=f"Ghost copy of {source_asset.name} found outside the organization",
        status="OPEN",
        severity=risk["band"],
        suspect_asset=suspect_asset,
        source_asset=source_asset,
        match=match,
        evidence={
            "match": match_payload,
            "risk": risk,
            "timeline_events": timeline_payload,
            "correlation": {
                "basis": correlation["basis"],
                "found_activity": correlation["found_activity"],
                "share_only": correlation["share_only"],
                "download_event_id": download_event.event_id if download_event else "",
                "share_event_ids": [event.event_id for event in share_events],
                "actor_id": download_event.actor_id if download_event else "",
            },
            "limits": LIMITATIONS,
        },
    )
    persist_risk(organization, incident, risk)
    generate_report(incident)

    investigation = Investigation.objects.create(
        public_id=next_public_id(Investigation, "public_id", "INV", floor=6001),
        organization=organization,
        created_by=user,
        source_asset=source_asset,
        suspect_asset=suspect_asset,
        match=match,
        incident=incident,
        input_filename=filename,
        input_sha256=exact_sha,
        input_rows=len(df),
        input_columns=len(df.columns),
        status="OPEN",
    )
    log_audit(
        organization,
        user,
        "INVESTIGATION_CREATED",
        "INCIDENT",
        incident.public_id,
        {
            "investigation_id": investigation.public_id,
            "match_id": match.public_id,
            "risk_id": risk["risk_id"],
            "rows": len(df),
            "columns": len(df.columns),
            "sha256": exact_sha,
        },
    )

    return {
        "matched": True,
        "duplicate": False,
        "suspect_asset": suspect_asset,
        "source_asset": source_asset,
        "match": match,
        "risk": risk,
        "incident": incident,
        "investigation": investigation,
        "scanned_sources": scanned,
    }
