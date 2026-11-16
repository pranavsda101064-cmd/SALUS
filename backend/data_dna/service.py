from django.conf import settings
from django.db import transaction

from assets.models import Asset
from common.ids import next_public_id
from data_dna.engine import fingerprint_dataframe
from pii_scan.detect import aggregate_sensitivity, detect_columns, pii_summary
from pii_scan.models import ScanResult


@transaction.atomic
def prepare_asset(
    organization,
    name,
    filename,
    df,
    kind="ORIGINAL",
    exact_sha256="",
    watermark="",
    is_baseline=False,
    canary_rows=0,
    id_floor=9300,
    precomputed=None,
    columns=None,
):
    columns = columns or detect_columns(df)
    sensitivity_score, sensitivity_label = aggregate_sensitivity(columns)
    fingerprints = precomputed or fingerprint_dataframe(df, columns, settings.SALUS_HASH_SALT)

    asset_id = next_public_id(Asset, "public_id", "SL", floor=id_floor)
    asset = Asset.objects.create(
        public_id=asset_id,
        organization=organization,
        name=name,
        original_filename=filename,
        kind=kind,
        row_count=len(df),
        column_count=len(df.columns),
        columns=columns,
        sensitivity_score=sensitivity_score,
        sensitivity_label=sensitivity_label,
        exact_sha256=exact_sha256,
        cell_count=fingerprints["cell_count"],
        unique_cell_count=fingerprints["unique_cell_count"],
        canary_rows=canary_rows,
        watermark=watermark,
        is_baseline=is_baseline,
    )

    ScanResult.objects.create(
        asset=asset,
        organization=organization,
        pii_summary=pii_summary(columns),
    )

    from data_dna.models import CellFingerprint

    CellFingerprint.objects.bulk_create(
        [
            CellFingerprint(
                organization=organization,
                asset=asset,
                column_name=cell["column_name"],
                value_hash=cell["value_hash"],
                weight=cell["weight"],
                count=cell["count"],
                pii_type=cell["pii_type"],
            )
            for cell in fingerprints["cells"]
        ],
        batch_size=1000,
    )
    return asset, fingerprints
