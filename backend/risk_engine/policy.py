WEIGHTS = {"S": 0.35, "D": 0.30, "B": 0.20, "E": 0.15}
POLICY_VERSION = "risk-v1-demo"

BANDS = [
    ("CRITICAL", 75),
    ("HIGH", 55),
    ("MEDIUM", 30),
    ("LOW", 0),
]

DESTINATION_TABLE = [
    {"destination": "internal_drive", "score": 10, "label": "INTERNAL"},
    {"destination": "internal_share", "score": 15, "label": "INTERNAL"},
    {"destination": "local_device", "score": 25, "label": "LOCAL_DEVICE"},
    {"destination": "known_partner", "score": 35, "label": "KNOWN_PARTNER"},
    {"destination": "personal_email", "score": 65, "label": "PERSONAL_EMAIL"},
    {"destination": "external_domain.com", "score": 85, "label": "UNKNOWN_EXTERNAL"},
    {"destination": "public_url", "score": 95, "label": "PUBLIC"},
]

SEQUENCE_TABLE = [
    {"reason": "Base for any investigated match", "points": 10},
    {"reason": "AFTER_HOURS", "points": 25},
    {"reason": "DOWNLOAD_THEN_EXTERNAL_SHARE", "points": 25},
    {"reason": "CANARY_PRESENT", "points": 20},
    {"reason": "HIGH_MATCH_CONFIDENCE", "points": 15},
    {"reason": "BULK_VOLUME", "points": 15},
    {"reason": "REPEATED_ACCESS", "points": 10},
]

SENSITIVITY_VALUES = {
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
