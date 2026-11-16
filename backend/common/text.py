import hashlib
import math
import re
import unicodedata


EMPTY_TOKENS = {"", "nan", "none", "null", "na", "n/a", "-"}


def is_empty(value) -> bool:
    if value is None:
        return True
    if isinstance(value, float) and math.isnan(value):
        return True
    text = str(value).strip()
    return text.lower() in EMPTY_TOKENS


def normalize_value(value) -> str:
    """Normalize a single cell before hashing.

    We intentionally do not include the column name in the hash, so a
    copy with renamed headers or dropped columns still matches. Column
    names are kept only for reporting.
    """
    if is_empty(value):
        return ""
    text = unicodedata.normalize("NFKC", str(value)).strip()
    text = re.sub(r"\s+", " ", text)
    digits = re.sub(r"\D", "", text)
    if digits and re.fullmatch(r"[\d\s\-\+\(\)\.]+", text) and 10 <= len(digits) <= 16:
        return digits
    return text.lower()


def cell_hash(salt: str, normalized_value: str) -> str:
    payload = f"{salt}|{normalized_value}".encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def rarity_weight(row_count: int, frequency: int) -> float:
    """Rare values carry more evidence than common ones.

    A city repeated 900 times in a 1000 row file gets a weight near 0.1,
    while an email that appears once gets a weight near 6.9.
    """
    n = max(int(row_count), 1)
    freq = max(int(frequency), 1)
    return round(math.log(1 + n / freq), 6)


def sanitize_text(value):
    if not isinstance(value, str):
        return value
    cleaned = value.replace("\u2014", ",").replace("\u2013", "-")
    cleaned = re.sub(r"[\u2018\u2019]", "'", cleaned)
    cleaned = re.sub(r"[\u201c\u201d]", '"', cleaned)
    cleaned = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", " ", cleaned)
    return re.sub(r"[ \t]+", " ", cleaned).strip()


def sanitize_structure(value):
    if isinstance(value, str):
        return sanitize_text(value)
    if isinstance(value, list):
        return [sanitize_structure(item) for item in value]
    if isinstance(value, dict):
        return {sanitize_text(str(k)): sanitize_structure(v) for k, v in value.items()}
    return value


def parse_bool(value, default=False):
    if value is None:
        return default
    return str(value).strip().lower() in {"1", "true", "yes", "on"}
