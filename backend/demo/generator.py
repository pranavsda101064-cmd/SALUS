"""Deterministic synthetic customer dataset for the Ghost Copy demo.

Every value is invented. No real personal data is used anywhere.
The same seed always produces the same file, so the seeded asset and
the ghost copy script stay in sync.
"""

import csv
import io
import random
from datetime import datetime, timezone

from openpyxl import Workbook

from pii_scan import gstin, verhoeff

COLUMNS = [
    "customer_ref",
    "full_name",
    "email",
    "phone",
    "aadhaar",
    "pan",
    "gstin",
    "upi_id",
    "city",
    "account_no",
    "monthly_income",
]

GHOST_DROP_COLUMNS = ["customer_ref", "city", "account_no"]
WATERMARK = "SALUS-WM-0727"
CANARY_TOKEN = "CN-007"
CANARY_RECIPIENT = "vendor.acme@external.test"
CANARY_ROW_COUNT = 5
ROW_COUNT = 1000

FIRST_NAMES = [
    "Aarav", "Aditi", "Advait", "Akash", "Ananya", "Anika", "Arjun", "Aryan",
    "Avni", "Bhavna", "Chetan", "Dhruv", "Diya", "Esha", "Farhan", "Gaurav",
    "Gitanjali", "Harsh", "Ibrahim", "Ira", "Ishaan", "Jaya", "Kabir", "Kavya",
    "Kiran", "Krishna", "Lakshmi", "Madhav", "Meera", "Mihir", "Naina", "Naveen",
    "Neha", "Nikhil", "Nisha", "Omkar", "Pallavi", "Pranav", "Priya", "Rahul",
    "Riya", "Rohan", "Saanvi", "Sahil", "Sara", "Shreya", "Siddharth", "Tanvi",
    "Uday", "Veda", "Vihaan", "Vikram", "Yash", "Zara", "Aisha", "Dev",
    "Ishita", "Manav", "Riya", "Tara",
]

LAST_NAMES = [
    "Agarwal", "Ahuja", "Bansal", "Bhat", "Bose", "Chandra", "Chawla", "Das",
    "Desai", "Dutta", "Gandhi", "Gill", "Gupta", "Iyer", "Jain", "Joshi",
    "Kapoor", "Khanna", "Kohli", "Kumar", "Mehta", "Menon", "Mishra", "Nair",
    "Nanda", "Patel", "Pillai", "Rao", "Reddy", "Roy", "Saini", "Saxena",
    "Sen", "Shah", "Sharma", "Singh", "Sinha", "Soni", "Srinivasan", "Varma",
]

CITIES = [
    "Mumbai", "Pune", "Nagpur", "Nashik", "Delhi", "Gurugram", "Noida",
    "Bengaluru", "Mysuru", "Mangaluru", "Hyderabad", "Warangal", "Chennai",
    "Coimbatore", "Madurai", "Kolkata", "Howrah", "Ahmedabad", "Surat",
    "Vadodara", "Jaipur", "Udaipur", "Lucknow", "Kanpur", "Indore", "Bhopal",
]

CANARY_ROWS = [
    {
        "customer_ref": "CN-007-A",
        "full_name": "Canary Recipient Alpha",
        "email": "canary.cn007.a@salus-canary.test",
        "phone": "+919000000107",
        "upi_id": "canary.cn007.a@okcanary",
        "city": "Canary Nagar",
    },
    {
        "customer_ref": "CN-007-B",
        "full_name": "Canary Recipient Beta",
        "email": "canary.cn007.b@salus-canary.test",
        "phone": "+919000000108",
        "upi_id": "canary.cn007.b@okcanary",
        "city": "Canary Nagar",
    },
    {
        "customer_ref": "CN-007-C",
        "full_name": "Canary Recipient Gamma",
        "email": "canary.cn007.c@salus-canary.test",
        "phone": "+919000000109",
        "upi_id": "canary.cn007.c@okcanary",
        "city": "Canary Nagar",
    },
    {
        "customer_ref": "CN-007-D",
        "full_name": "Canary Recipient Delta",
        "email": "canary.cn007.d@salus-canary.test",
        "phone": "+919000000110",
        "upi_id": "canary.cn007.d@okcanary",
        "city": "Canary Nagar",
    },
    {
        "customer_ref": "CN-007-E",
        "full_name": "Canary Recipient Epsilon",
        "email": "canary.cn007.e@salus-canary.test",
        "phone": "+919000000111",
        "upi_id": "canary.cn007.e@okcanary",
        "city": "Canary Nagar",
    },
]


def _pan(rng):
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    return (
        "".join(rng.choice(letters) for _ in range(5))
        + "".join(str(rng.randint(0, 9)) for _ in range(4))
        + rng.choice(letters)
    )


def _gstin(rng, pan):
    state = rng.choice(["07", "27", "29", "33", "36"])
    return gstin.generate(state, pan, entity="1")


def _aadhaar(rng):
    first = str(rng.randint(2, 9))
    middle = "".join(str(rng.randint(0, 9)) for _ in range(10))
    prefix = first + middle
    return prefix + verhoeff.generate_check_digit(prefix)


def generate_rows(seed=42):
    rng = random.Random(seed)
    rows = []
    used_names = set()
    used_emails = set()
    used_phones = set()
    used_aadhaar = set()
    used_pan = set()
    used_accounts = set()

    while len(rows) < ROW_COUNT - CANARY_ROW_COUNT:
        first = rng.choice(FIRST_NAMES)
        last = rng.choice(LAST_NAMES)
        full_name = f"{first} {last}"
        email = f"{first.lower()}.{last.lower()}{len(rows)}@example.test"
        if full_name in used_names or email in used_emails:
            continue

        phone_digits = "9" + "".join(str(rng.randint(0, 9)) for _ in range(9))
        if phone_digits in used_phones:
            continue

        aadhaar = _aadhaar(rng)
        if aadhaar in used_aadhaar:
            continue

        pan = _pan(rng)
        if pan in used_pan:
            continue

        account = "5" + "".join(str(rng.randint(0, 9)) for _ in range(11))
        if account in used_accounts:
            continue

        index = len(rows) + 1
        used_names.add(full_name)
        used_emails.add(email)
        used_phones.add(phone_digits)
        used_aadhaar.add(aadhaar)
        used_pan.add(pan)
        used_accounts.add(account)

        rows.append(
            {
                "customer_ref": f"CUST-{index:05d}",
                "full_name": full_name,
                "email": email,
                "phone": "+91" + phone_digits,
                "aadhaar": aadhaar,
                "pan": pan,
                "gstin": _gstin(rng, pan),
                "upi_id": f"{first.lower()}.{last.lower()}{index}@okhdfcbank",
                "city": rng.choice(CITIES),
                "account_no": account,
                "monthly_income": str(rng.randrange(25000, 250001, 500)),
            }
        )

    invalid_targets = set(rng.sample(range(len(rows)), 13))
    for index in invalid_targets:
        aadhaar = rows[index]["aadhaar"]
        corrupted = aadhaar[:-1] + str((int(aadhaar[-1]) + 1) % 10)
        rows[index]["aadhaar"] = corrupted

    canary_rows = []
    for offset, canary in enumerate(CANARY_ROWS):
        pan = _pan(rng)
        aadhaar = _aadhaar(rng)
        canary_rows.append(
            {
                "customer_ref": canary["customer_ref"],
                "full_name": canary["full_name"],
                "email": canary["email"],
                "phone": canary["phone"],
                "aadhaar": aadhaar,
                "pan": pan,
                "gstin": _gstin(rng, pan),
                "upi_id": canary["upi_id"],
                "city": canary["city"],
                "account_no": "7" + "".join(str(rng.randint(0, 9)) for _ in range(11)),
                "monthly_income": str(rng.randrange(25000, 250001, 500)),
            }
        )

    rows.extend(canary_rows)
    return rows


def manifest(rows, seed=42):
    canary_values = []
    for canary in CANARY_ROWS:
        canary_values.append(
            {
                "customer_ref": canary["customer_ref"],
                "full_name": canary["full_name"],
                "email": canary["email"],
                "phone": canary["phone"],
                "upi_id": canary["upi_id"],
            }
        )
    return {
        "dataset": "customer_master_v1",
        "seed": seed,
        "row_count": len(rows),
        "columns": COLUMNS,
        "watermark": WATERMARK,
        "canary": {
            "token": CANARY_TOKEN,
            "recipient": CANARY_RECIPIENT,
            "row_count": CANARY_ROW_COUNT,
            "rows": canary_values,
        },
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
    }


def to_xlsx_bytes(rows, columns=None, watermark=WATERMARK):
    columns = columns or COLUMNS
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "customers"
    sheet.append(columns)
    for row in rows:
        sheet.append([row.get(column, "") for column in columns])
    workbook.properties.title = "SALUS synthetic customer master"
    workbook.properties.description = f"Synthetic demo data. Watermark {watermark}."
    workbook.properties.keywords = watermark
    buffer = io.BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


def to_csv_bytes(rows, columns=None):
    columns = columns or COLUMNS
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()
    for row in rows:
        writer.writerow({column: row.get(column, "") for column in columns})
    return buffer.getvalue().encode("utf-8")


def read_xlsx_bytes(data):
    import pandas as pd

    return pd.read_excel(io.BytesIO(data), dtype=str, keep_default_na=False, engine="openpyxl")
