from datetime import datetime, timezone
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")

DESTINATION_TRUST = {
    "local_device": 25,
    "internal_drive": 10,
    "internal_share": 15,
    "known_partner": 35,
    "personal_email": 65,
    "external_domain.com": 85,
    "public_url": 95,
}

TRUST_UNKNOWN_EXTERNAL = 85
TRUST_INTERNAL = 12
TRUST_LOCAL = 25


def destination_risk(destination: str) -> int:
    if not destination:
        return TRUST_LOCAL
    key = destination.strip().lower()
    if key in DESTINATION_TRUST:
        return DESTINATION_TRUST[key]
    if any(token in key for token in ("internal", "drive.google.com", "sharepoint")):
        return TRUST_INTERNAL
    if key in {"local_device", "local", "download"} or key.startswith("local"):
        return TRUST_LOCAL
    if any(domain in key for domain in ("gmail.com", "yahoo.", "outlook.", "hotmail.")):
        return 70
    if "." in key:
        return TRUST_UNKNOWN_EXTERNAL
    return 50


def destination_trust_label(destination: str) -> str:
    if not destination:
        return "NO_DESTINATION"
    key = destination.strip().lower()
    if any(token in key for token in ("internal", "drive.google.com", "sharepoint")):
        return "INTERNAL"
    if key.startswith("local") or key == "download":
        return "LOCAL_DEVICE"
    return "UNKNOWN_EXTERNAL"


def parse_timestamp(value):
    if isinstance(value, datetime):
        dt = value
    else:
        text = str(value or "").strip()
        if not text:
            return None
        text = text.replace("Z", "+00:00")
        try:
            dt = datetime.fromisoformat(text)
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def to_utc_iso(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def ist_parts(dt: datetime):
    local = dt.astimezone(IST)
    return local, local.hour, local.weekday()
