"""Deterministic event simulator.

Every event created here carries source SIMULATOR and simulated true, and
the UI labels it. The simulator never writes derived matches or risk
scores; those are computed later from stored events and stored matches.
"""

import random
from datetime import datetime, timedelta, timezone as dt_timezone

from django.utils import timezone

from common.ids import next_public_id
from common.timeutil import IST
from events.models import Event
from events.services import record_event


def _at_ist(day_offset, hour, minute, base=None):
    base = base or timezone.now()
    local_day = base.astimezone(IST).date() + timedelta(days=day_offset)
    local = datetime(local_day.year, local_day.month, local_day.day, hour, minute, tzinfo=IST)
    return local.astimezone(dt_timezone.utc)


def _fresh_event_ids():
    first = next_public_id(Event, "event_id", "EV", floor=10200)
    number = int(first.split("-")[-1])
    return [f"EV-{number}", f"EV-{number + 1}"]


def ghost_copy_events(organization, source_asset, actor_id, fresh=False):
    download_time = _at_ist(-1, 23 if fresh else 22, 5 if fresh else 40)
    share_time = download_time + timedelta(minutes=4)
    event_ids = _fresh_event_ids() if fresh else ["EV-10021", "EV-10027"]
    events = [
        {
            "event_id": event_ids[0],
            "actor_id": actor_id,
            "asset_id": source_asset.public_id,
            "action": "FILE_DOWNLOADED",
            "source": "SIMULATOR",
            "destination": "local_device",
            "timestamp": download_time,
            "evidence": {
                "rows": source_asset.row_count,
                "bytes": 184320,
                "device": "Windows laptop",
                "simulated": True,
            },
        },
        {
            "event_id": event_ids[1],
            "actor_id": actor_id,
            "asset_id": source_asset.public_id,
            "action": "EXTERNAL_SHARE",
            "source": "SIMULATOR",
            "destination": "external_domain.com",
            "timestamp": share_time,
            "evidence": {
                "channel": "email",
                "recipient": "vendor.acme@external.test",
                "rows": 300,
                "simulated": True,
            },
        },
    ]
    return events


def run_ghost_copy_scenario(organization, source_asset, actor_id, fresh=False):
    payloads = ghost_copy_events(organization, source_asset, actor_id, fresh=fresh)
    created = []
    existing = []
    for payload in payloads:
        event, was_created = record_event(organization=organization, **payload)
        (created if was_created else existing).append(event)
    return created, existing


def baseline_events(organization, users, assets, per_user=140, seed=7):
    rng = random.Random(seed)
    payloads = []
    counter = 11000
    action_weights = [
        ("FILE_VIEWED", 0.52, 4),
        ("FILE_DOWNLOADED", 0.28, 12),
        ("FILE_COPIED", 0.12, 8),
        ("EXTERNAL_SHARE", 0.08, 2),
    ]
    actions = [item[0] for item in action_weights]
    weights = [item[1] for item in action_weights]

    for user in users:
        for _ in range(per_user):
            counter += 1
            day_offset = -rng.randint(2, 60)
            hour = rng.choice([10, 11, 12, 14, 15, 16, 17, 18])
            minute = rng.randint(0, 59)
            timestamp = _at_ist(day_offset, hour, minute)
            action = rng.choices(actions, weights=weights, k=1)[0]
            asset = rng.choice(assets)
            if action == "EXTERNAL_SHARE":
                destination = rng.choice(["known_partner", "internal_share"])
            elif action == "FILE_COPIED":
                destination = "internal_drive"
            elif action == "FILE_DOWNLOADED":
                destination = "local_device"
            else:
                destination = "internal_share"
            payloads.append(
                {
                    "event_id": f"EV-{counter}",
                    "actor_id": user.public_id,
                    "asset_id": asset.public_id,
                    "action": action,
                    "source": "SIMULATOR",
                    "destination": destination,
                    "timestamp": timestamp,
                    "evidence": {
                        "rows": rng.randint(1, 80),
                        "simulated": True,
                        "note": "Synthetic baseline event for the behaviour model.",
                    },
                }
            )
    return payloads
