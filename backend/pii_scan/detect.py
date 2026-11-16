import re

from common.text import is_empty
from pii_scan import gstin, verhoeff

EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$")
PAN_RE = re.compile(r"^[A-Z]{5}[0-9]{4}[A-Z]$")
GSTIN_RE = re.compile(r"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$")
UPI_RE = re.compile(r"^[A-Za-z0-9._\-]{2,}@[A-Za-z][A-Za-z0-9.\-]{1,}$")
IFSC_RE = re.compile(r"^[A-Z]{4}0[A-Z0-9]{6}$")
PHONE_RE = re.compile(r"^[6-9]\d{9}$")

SENSITIVITY_SCORE = {
    "AADHAAR": 100,
    "PAN": 95,
    "FINANCIAL_ACCOUNT": 92,
    "GSTIN": 85,
    "UPI_ID": 82,
    "EMAIL": 80,
    "PHONE": 78,
    "FINANCIAL_AMOUNT": 75,
    "IFSC": 70,
    "NAME": 55,
    "LOCATION": 35,
    "OTHER": 10,
}

SENSITIVITY_ORDER = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]

HEADER_HINTS = [
    (("aadhaar", "aadhar", "uidai", "uid_no"), "AADHAAR"),
    (("gstin", "gst_no", "gst_number", "gst"), "GSTIN"),
    (("pan_no", "pan_number", "pancard", " pan"), "PAN"),
    (("upi", "vpa", "handle"), "UPI_ID"),
    (("ifsc",), "IFSC"),
    (
        ("account", "acc_no", "account_no", "bank_acc", "card_no", "cibil", "loan"),
        "FINANCIAL_ACCOUNT",
    ),
    (
        ("income", "salary", "amount", "balance", "revenue", "fee", "billing"),
        "FINANCIAL_AMOUNT",
    ),
    (("email", "mail_id", "email_id"), "EMAIL"),
    (("phone", "mobile", "contact_no", "whatsapp", "telephone"), "PHONE"),
    (("city", "state", "address", "location", "pincode", "pin_code", "zip"), "LOCATION"),
    (("full_name", "customer_name", "first_name", "last_name", "employee_name"), "NAME"),
]


def sensitivity_label(score: int) -> str:
    if score >= 90:
        return "CRITICAL"
    if score >= 70:
        return "HIGH"
    if score >= 45:
        return "MEDIUM"
    return "LOW"


def sensitivity_for_pii(pii_type: str) -> str:
    return sensitivity_label(SENSITIVITY_SCORE.get(pii_type, 10))


def _header_type(header: str):
    normalized = " " + re.sub(r"[^a-z0-9]+", " ", header.lower()) + " "
    for tokens, pii_type in HEADER_HINTS:
        for token in tokens:
            needle = re.sub(r"[^a-z0-9]+", " ", token.lower()).strip()
            if needle and needle in normalized:
                return pii_type
    return None


def _clean(value):
    return str(value).strip()


def _match_ratio(values, predicate, limit=400):
    sample = values[:limit]
    if not sample:
        return 0.0
    return sum(1 for value in sample if predicate(value)) / len(sample)


def _aadhaar_like(value):
    compact = re.sub(r"\D", "", value)
    return len(compact) == 12 and bool(re.fullmatch(r"[\d\s\-]+", value))


def _phone_like(value):
    compact = re.sub(r"[\s\-\(\)]", "", value)
    if compact.startswith("+91"):
        compact = compact[3:]
    elif compact.startswith("91") and len(compact) == 12:
        compact = compact[2:]
    return bool(PHONE_RE.fullmatch(compact))


def detect_column(name, values):
    non_empty = [_clean(value) for value in values if not is_empty(value)]
    total = len(non_empty)
    if total == 0:
        return _column(name, "OTHER", 0, 0, 0, 0)

    header_type = _header_type(name)
    pii_type = None
    valid = 0
    invalid = 0
    unique = len({re.sub(r"\s+", " ", value.lower()) for value in non_empty})

    if header_type == "AADHAAR":
        pii_type = "AADHAAR"
        valid = sum(1 for value in non_empty if verhoeff.is_valid_aadhaar(value))
        invalid = total - valid
    elif header_type in {"PAN", "GSTIN", "EMAIL", "UPI_ID", "IFSC"}:
        pii_type = header_type
        regex = {
            "PAN": PAN_RE,
            "GSTIN": GSTIN_RE,
            "EMAIL": EMAIL_RE,
            "UPI_ID": UPI_RE,
            "IFSC": IFSC_RE,
        }[pii_type]
        if pii_type == "GSTIN":
            valid = sum(
                1
                for value in non_empty
                if GSTIN_RE.fullmatch(value.strip().upper()) and gstin.validate(value)
            )
        else:
            valid = sum(
                1
                for value in non_empty
                if regex.fullmatch(
                    value.strip().upper() if pii_type in {"PAN", "IFSC"} else value.strip()
                )
            )
        invalid = total - valid
    elif header_type == "PHONE":
        pii_type = "PHONE"
        valid = sum(1 for value in non_empty if _phone_like(value))
        invalid = total - valid
    elif header_type in {"FINANCIAL_ACCOUNT", "FINANCIAL_AMOUNT", "NAME", "LOCATION"}:
        pii_type = header_type
        valid = total
    else:
        aadhaar_ratio = _match_ratio(non_empty, _aadhaar_like)
        if aadhaar_ratio >= 0.8:
            pii_type = "AADHAAR"
            valid = sum(1 for value in non_empty if verhoeff.is_valid_aadhaar(value))
            invalid = total - valid
        elif _match_ratio(non_empty, lambda v: bool(GSTIN_RE.fullmatch(v.strip().upper()))) >= 0.7:
            pii_type = "GSTIN"
            valid = sum(
                1
                for value in non_empty
                if GSTIN_RE.fullmatch(value.strip().upper()) and gstin.validate(value)
            )
            invalid = total - valid
        elif _match_ratio(non_empty, lambda v: bool(PAN_RE.fullmatch(v.strip().upper()))) >= 0.7:
            pii_type = "PAN"
            valid = sum(1 for value in non_empty if PAN_RE.fullmatch(value.strip().upper()))
            invalid = total - valid
        elif _match_ratio(non_empty, lambda v: bool(EMAIL_RE.fullmatch(v.strip()))) >= 0.7:
            pii_type = "EMAIL"
            valid = sum(1 for value in non_empty if EMAIL_RE.fullmatch(value.strip()))
            invalid = total - valid
        elif _match_ratio(non_empty, lambda v: bool(UPI_RE.fullmatch(v.strip())) and not EMAIL_RE.fullmatch(v.strip())) >= 0.7:
            pii_type = "UPI_ID"
            valid = sum(1 for value in non_empty if UPI_RE.fullmatch(value.strip()))
            invalid = total - valid
        elif _match_ratio(non_empty, _phone_like) >= 0.7:
            pii_type = "PHONE"
            valid = sum(1 for value in non_empty if _phone_like(value))
            invalid = total - valid
        else:
            pii_type = "OTHER"
            valid = total

    return _column(name, pii_type, total, unique, valid, invalid)


def _column(name, pii_type, total, unique, valid, invalid):
    score = SENSITIVITY_SCORE.get(pii_type, 10)
    return {
        "name": str(name),
        "pii_type": pii_type,
        "sensitivity": sensitivity_label(score),
        "sensitivity_score": score,
        "non_empty": total,
        "unique_count": unique,
        "valid_count": valid,
        "invalid_count": invalid,
    }


def detect_columns(df):
    columns = []
    for name in df.columns:
        columns.append(detect_column(name, df[name].tolist()))
    return columns


def aggregate_sensitivity(columns):
    if not columns:
        return 0, "LOW"
    scores = [int(col.get("sensitivity_score", 10)) for col in columns]
    highest = max(scores)
    average = sum(scores) / len(scores)
    score = int(round(0.7 * highest + 0.3 * average))
    strong_columns = sum(1 for value in scores if value >= 70)
    score = min(100, score + max(0, strong_columns - 1) * 2)
    return score, sensitivity_label(score)


def pii_summary(columns):
    summary = []
    for col in columns:
        if col["pii_type"] == "OTHER":
            continue
        summary.append(
            {
                "type": col["pii_type"],
                "column": col["name"],
                "valid": col["valid_count"],
                "invalid": col["invalid_count"],
                "sensitivity": col["sensitivity"],
            }
        )
    return summary
