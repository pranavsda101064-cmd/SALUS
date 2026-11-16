from datetime import datetime, timezone

from django.conf import settings
from django.db import transaction

from anomaly_model.engine import train_models
from assets.models import Asset
from common.text import cell_hash, hash_bytes, normalize_value
from data_dna.models import CanaryIssuance
from data_dna.service import prepare_asset
from demo.generator import (
    CANARY_RECIPIENT,
    CANARY_ROW_COUNT,
    CANARY_TOKEN,
    COLUMNS,
    WATERMARK,
    generate_rows,
    manifest,
    to_xlsx_bytes,
)
from events.services import record_many
from organizations.models import Organization, User
from pii_scan.detect import aggregate_sensitivity
from simulator.services import baseline_events, run_ghost_copy_scenario

ORG_ID = "ORG-01"
SOURCE_ASSET_ID = "SL-9281"
BASELINE_ASSET_IDS = ["SL-9290", "SL-9291"]


def _baseline_columns():
    roster = [
        {"name": "employee_name", "pii_type": "NAME", "sensitivity": "MEDIUM", "sensitivity_score": 55, "non_empty": 60, "unique_count": 60, "valid_count": 60, "invalid_count": 0},
        {"name": "work_email", "pii_type": "EMAIL", "sensitivity": "HIGH", "sensitivity_score": 80, "non_empty": 60, "unique_count": 60, "valid_count": 60, "invalid_count": 0},
        {"name": "mobile", "pii_type": "PHONE", "sensitivity": "HIGH", "sensitivity_score": 78, "non_empty": 60, "unique_count": 60, "valid_count": 60, "invalid_count": 0},
        {"name": "department", "pii_type": "OTHER", "sensitivity": "LOW", "sensitivity_score": 10, "non_empty": 60, "unique_count": 6, "valid_count": 60, "invalid_count": 0},
    ]
    leads = [
        {"name": "company_name", "pii_type": "OTHER", "sensitivity": "LOW", "sensitivity_score": 10, "non_empty": 80, "unique_count": 80, "valid_count": 80, "invalid_count": 0},
        {"name": "contact_phone", "pii_type": "PHONE", "sensitivity": "HIGH", "sensitivity_score": 78, "non_empty": 80, "unique_count": 80, "valid_count": 80, "invalid_count": 0},
        {"name": "city", "pii_type": "LOCATION", "sensitivity": "LOW", "sensitivity_score": 35, "non_empty": 80, "unique_count": 12, "valid_count": 80, "invalid_count": 0},
    ]
    return roster, leads


def _create_baseline_assets(organization):
    roster_columns, leads_columns = _baseline_columns()
    roster_score, roster_label = aggregate_sensitivity(roster_columns)
    leads_score, leads_label = aggregate_sensitivity(leads_columns)
    roster = Asset.objects.create(
        public_id=BASELINE_ASSET_IDS[0],
        organization=organization,
        name="employee_roster",
        original_filename="employee_roster.xlsx",
        kind="ORIGINAL",
        row_count=60,
        column_count=4,
        columns=roster_columns,
        sensitivity_score=roster_score,
        sensitivity_label=roster_label,
        is_baseline=True,
        watermark="",
    )
    leads = Asset.objects.create(
        public_id=BASELINE_ASSET_IDS[1],
        organization=organization,
        name="sales_leads",
        original_filename="sales_leads.csv",
        kind="ORIGINAL",
        row_count=80,
        column_count=3,
        columns=leads_columns,
        sensitivity_score=leads_score,
        sensitivity_label=leads_label,
        is_baseline=True,
        watermark="",
    )
    return [roster, leads]


CANARY_ID_COLUMNS = ["email", "phone", "aadhaar", "pan", "gstin", "upi_id"]


def _canary_hashes(rows):
    canary_rows = [row for row in rows if row["customer_ref"].startswith("CN-007")]
    hashes = []
    for row in canary_rows:
        for column in CANARY_ID_COLUMNS:
            normalized = normalize_value(row[column])
            if normalized:
                hashes.append(cell_hash(settings.SALUS_HASH_SALT, normalized))
    return canary_rows, hashes


@transaction.atomic
def seed_demo(reset=False):
    existing = Organization.objects.filter(id=ORG_ID).first()
    if existing is not None and not reset:
        source = Asset.objects.filter(organization=existing, public_id=SOURCE_ASSET_ID).first()
        if source is not None:
            return {
                "created": False,
                "reason": "Demo organization already exists.",
                "organization_id": existing.id,
                "source_asset_id": source.public_id,
                "login_email": "meera@acmetraders.test",
            }
    if existing is not None:
        existing.delete()

    organization = Organization.objects.create(
        id=ORG_ID,
        name="Acme Traders",
        slug="acme-traders",
        industry="Distribution and retail",
        is_demo=True,
    )
    meera = User.objects.create_user(
        username="meera@acmetraders.test",
        email="meera@acmetraders.test",
        password="salus-demo",
        public_id="USER-100",
        organization=organization,
        display_name="Meera Nair",
        role="OWNER",
    )
    priya = User.objects.create_user(
        username="priya@acmetraders.test",
        email="priya@acmetraders.test",
        password="salus-demo",
        public_id="USER-104",
        organization=organization,
        display_name="Priya Sharma",
        role="SALES",
    )
    arjun = User.objects.create_user(
        username="arjun@acmetraders.test",
        email="arjun@acmetraders.test",
        password="salus-demo",
        public_id="USER-105",
        organization=organization,
        display_name="Arjun Mehta",
        role="ANALYST",
    )

    rows = generate_rows(seed=42)
    xlsx_bytes = to_xlsx_bytes(rows)
    source_asset, _fingerprints = prepare_asset(
        organization=organization,
        name="customer_master_v1",
        filename="customer_master_v1.xlsx",
        df=_rows_to_dataframe(rows),
        kind="ORIGINAL",
        exact_sha256=hash_bytes(xlsx_bytes),
        watermark=WATERMARK,
        canary_rows=CANARY_ROW_COUNT,
        id_floor=9281,
    )

    canary_rows, canary_hashes = _canary_hashes(rows)
    CanaryIssuance.objects.create(
        public_id="CN-007",
        organization=organization,
        asset=source_asset,
        recipient=CANARY_RECIPIENT,
        token=CANARY_TOKEN,
        value_hashes=canary_hashes,
        row_labels=[row["customer_ref"] for row in canary_rows],
        issued_at=datetime(2026, 11, 1, 9, 0, tzinfo=timezone.utc),
    )

    baseline_assets = _create_baseline_assets(organization)
    payloads = baseline_events(organization, [priya, arjun], baseline_assets)
    created, _skipped = record_many(organization, payloads)
    train_models(organization)

    download_events, existing_events = run_ghost_copy_scenario(
        organization, source_asset, priya.public_id
    )

    from organizations.audit import log_audit

    log_audit(
        organization,
        None,
        "DEMO_SEEDED",
        "ORGANIZATION",
        organization.id,
        {
            "reset": bool(reset),
            "source_asset_id": source_asset.public_id,
            "row_count": len(rows),
            "canary_id": "CN-007",
        },
    )

    return {
        "created": True,
        "organization_id": organization.id,
        "organization_name": organization.name,
        "source_asset_id": source_asset.public_id,
        "login_email": meera.email,
        "users": [meera.public_id, priya.public_id, arjun.public_id],
        "baseline_events": len(created),
        "demo_events": [event.event_id for event in download_events]
        or [event.event_id for event in existing_events],
        "canary_id": "CN-007",
        "watermark": WATERMARK,
        "next_step": "Run scripts/generate_dataset.py then scripts/ghost_copy.py, then upload the ghost CSV in the investigation screen.",
        "manifest": manifest(rows),
    }


def _rows_to_dataframe(rows):
    import pandas as pd

    return pd.DataFrame(rows, columns=COLUMNS)
