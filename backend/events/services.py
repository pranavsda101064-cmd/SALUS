from django.utils import timezone

from common.timeutil import parse_timestamp, to_utc_iso
from events.models import Event

VALID_ACTIONS = {choice[0] for choice in Event.ACTION_CHOICES}
VALID_SOURCES = {choice[0] for choice in Event.SOURCE_CHOICES}


class EventError(ValueError):
    pass


def record_event(
    organization,
    event_id,
    actor_id,
    asset_id,
    action,
    source="SIMULATOR",
    destination="",
    timestamp=None,
    evidence=None,
    simulated=None,
):
    if action not in VALID_ACTIONS:
        raise EventError(f"Unknown action {action}")
    if source not in VALID_SOURCES:
        raise EventError(f"Unknown source {source}")
    if not event_id or not actor_id:
        raise EventError("event_id and actor_id are required")

    parsed = parse_timestamp(timestamp) if timestamp else timezone.now()
    if parsed is None:
        raise EventError("timestamp is not a valid ISO 8601 value")

    if simulated is None:
        simulated = source == "SIMULATOR"

    asset = None
    public_asset_id = asset_id or ""
    if asset_id:
        from assets.models import Asset

        asset = Asset.objects.filter(public_id=asset_id, organization=organization).first()
        if asset is None:
            raise EventError(f"Asset {asset_id} was not found in this organization")
        public_asset_id = asset.public_id

    from organizations.models import User

    actor = User.objects.filter(organization=organization, public_id=actor_id).first()
    if actor is None and source != "CONNECTOR":
        raise EventError(f"Actor {actor_id} was not found in this organization")

    if evidence is not None and not isinstance(evidence, dict):
        raise EventError("evidence must be a JSON object")

    event, created = Event.objects.get_or_create(
        organization=organization,
        event_id=event_id,
        defaults={
            "actor_id": actor_id,
            "actor_ref": actor,
            "asset_ref": asset,
            "asset_id": public_asset_id,
            "action": action,
            "source": source,
            "destination": destination or "",
            "timestamp": parsed,
            "evidence": evidence or {},
            "simulated": bool(simulated),
        },
    )
    return event, created


def record_many(organization, payloads):
    created = []
    skipped = []
    for payload in payloads:
        event, was_created = record_event(
            organization=organization,
            event_id=payload["event_id"],
            actor_id=payload["actor_id"],
            asset_id=payload.get("asset_id", ""),
            action=payload["action"],
            source=payload.get("source", "SIMULATOR"),
            destination=payload.get("destination", ""),
            timestamp=payload.get("timestamp"),
            evidence=payload.get("evidence", {}),
            simulated=payload.get("simulated"),
        )
        (created if was_created else skipped).append(event)
    return created, skipped


def serialize_event(event):
    return {
        "event_id": event.event_id,
        "organization_id": event.organization_id,
        "actor_id": event.actor_id,
        "asset_id": event.asset_id,
        "action": event.action,
        "source": event.source,
        "destination": event.destination,
        "timestamp": to_utc_iso(event.timestamp),
        "evidence": event.evidence,
        "simulated": event.simulated,
    }
