"""Public read-only storyboard for the landing page simulation.

The payload is assembled from stored demo evidence only. Raw cell values are
never included; the page receives metadata, references, counts and hashes.
"""

from django.utils import timezone
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from anomaly_model.engine import FEATURE_NAMES, MODEL_VERSION
from api.serializers import serialize_incident_bundle
from common.permissions import IsDemoMode
from common.timeutil import to_utc_iso
from data_dna.models import CanaryIssuance
from incidents.models import Incident
from lineage.services import build_lineage
from organizations.models import Organization
from risk_engine.policy import (
    BANDS,
    DESTINATION_TABLE,
    POLICY_VERSION,
    SEQUENCE_TABLE,
    WEIGHTS,
)

DEMO_ORGANIZATION_ID = "ORG-01"
BEHAVIOUR_ARCHITECTURE = [10, 8, 4, 10]


def _demo_organization():
    return (
        Organization.objects.filter(id=DEMO_ORGANIZATION_ID).first()
        or Organization.objects.filter(is_demo=True).order_by("id").first()
    )


def _organization_payload(organization):
    if organization is None:
        return {}
    return {"organization_id": organization.id, "name": organization.name}


def _canary_payload(source_asset):
    if source_asset is None:
        return None
    issuance = (
        CanaryIssuance.objects.filter(asset=source_asset)
        .order_by("-issued_at")
        .first()
    )
    if issuance is None:
        return None
    return {
        "canary_id": issuance.public_id,
        "token": issuance.token,
        "recipient": issuance.recipient,
        "issued_at": to_utc_iso(issuance.issued_at),
        "row_labels": issuance.row_labels or [],
    }


def _dataset_payload(source_asset):
    if source_asset is None:
        return {}
    pii_types = []
    for column in source_asset.columns or []:
        pii_type = str(column.get("pii_type", "OTHER"))
        if pii_type != "OTHER" and pii_type not in pii_types:
            pii_types.append(pii_type)
    return {
        "asset_id": source_asset.public_id,
        "name": source_asset.name,
        "filename": source_asset.original_filename,
        "rows": source_asset.row_count,
        "columns": source_asset.column_count,
        "column_metadata": source_asset.columns or [],
        "sensitivity": source_asset.sensitivity_label,
        "sensitivity_score": source_asset.sensitivity_score,
        "watermark": source_asset.watermark,
        "dna": {
            "version": source_asset.dna_version,
            "cell_fingerprints": source_asset.cell_count,
            "unique_cells": source_asset.unique_cell_count,
            "canary_rows": source_asset.canary_rows,
        },
        "pii_types": pii_types,
        "canary": _canary_payload(source_asset),
    }


def _movement_payload(timeline):
    events = [
        event
        for event in timeline
        if event.get("action") in {"FILE_DOWNLOADED", "FILE_COPIED", "EXTERNAL_SHARE"}
    ]
    return {"events": events}


def _ghost_copy_payload(source_asset, suspect_asset, match):
    if source_asset is None or suspect_asset is None:
        return {}
    evidence = match.evidence or {} if match is not None else {}
    canary = match.canary or {} if match is not None else {}
    source_suffix = (source_asset.original_filename or "").rsplit(".", 1)[-1].upper()
    suspect_suffix = (suspect_asset.original_filename or "").rsplit(".", 1)[-1].upper()
    return {
        "renamed_from": source_asset.original_filename,
        "renamed_to": suspect_asset.original_filename,
        "format_change": f"{source_suffix} to {suspect_suffix}"
        if source_suffix and suspect_suffix and source_suffix != suspect_suffix
        else "unchanged",
        "original_rows": source_asset.row_count,
        "ghost_rows": suspect_asset.row_count,
        "rows_removed": max(0, source_asset.row_count - suspect_asset.row_count),
        "original_columns": source_asset.column_count,
        "ghost_columns": suspect_asset.column_count,
        "matched_columns": match.matched_columns or [] if match is not None else [],
        "dropped_columns": match.dropped_columns or [] if match is not None else [],
        "canary_rows_kept": int(canary.get("matched_rows") or 0),
        "canary_values_found": int(canary.get("matched_values") or 0),
        "watermark_on_source": evidence.get("watermark_on_source", source_asset.watermark),
        "watermark_on_query": evidence.get("watermark_on_query", suspect_asset.watermark),
        "watermark_stripped": bool(evidence.get("watermark_stripped")),
    }


def _intake_payload(investigation, suspect_asset):
    if investigation is None:
        return {}
    return {
        "investigation_id": investigation.get("investigation_id"),
        "filename": investigation.get("input", {}).get("filename", ""),
        "sha256": investigation.get("input", {}).get("sha256", ""),
        "rows": investigation.get("input", {}).get("rows", 0),
        "columns": investigation.get("input", {}).get("columns", 0),
        "status": investigation.get("status", ""),
        "suspect_asset_id": suspect_asset.public_id if suspect_asset else None,
        "raw_rows_stored": False,
        "note": "Parsed in memory. Only hashes, labels and metadata are retained.",
    }


def _behaviour_payload(risk):
    factors = risk.factors or {} if risk is not None else {}
    behaviour = factors.get("B", {}) if isinstance(factors, dict) else {}
    return {
        "architecture": BEHAVIOUR_ARCHITECTURE,
        "feature_names": FEATURE_NAMES,
        "model_version": MODEL_VERSION,
        "score": behaviour.get("score", 0),
        "percentile": behaviour.get("percentile", 50),
        "top_features": behaviour.get("top_features", []),
        "samples": behaviour.get("samples", 0),
        "error": behaviour.get("error"),
        "baseline_p95": behaviour.get("baseline_p95"),
        "basis": behaviour.get("basis", ""),
        "note": (
            "Illustration of the stored autoencoder architecture. "
            "The score, percentile and top features are computed by the model."
        ),
    }


def _policy_payload():
    return {
        "formula": "R = 0.35*S + 0.30*D + 0.20*B + 0.15*E",
        "weights": WEIGHTS,
        "bands": [{"band": band, "min": minimum} for band, minimum in BANDS],
        "destination_table": DESTINATION_TABLE,
        "sequence_table": SEQUENCE_TABLE,
        "policy_version": POLICY_VERSION,
        "disclaimer": (
            "Demo policy values, not validated standards. "
            "The engine is deterministic; the language model only explains."
        ),
    }


def build_storyboard(organization):
    incidents = (
        Incident.objects.filter(organization=organization)
        .select_related(
            "risk",
            "report",
            "match",
            "match__query_asset",
            "match__source_asset",
            "source_asset",
            "suspect_asset",
            "investigation",
        )
        .order_by("-created_at")
    )
    incident = incidents.first()
    if incident is None:
        return {
            "available": False,
            "mode": "NO_INCIDENT",
            "generated_at": timezone.now().isoformat().replace("+00:00", "Z"),
            "organization": _organization_payload(organization),
            "reason": (
                "No investigation incident exists for the demo workspace yet. "
                "Run the replay and upload the ghost copy to generate live evidence."
            ),
        }

    lineage = build_lineage(incident)
    bundle = serialize_incident_bundle(incident, lineage=lineage)
    investigation = bundle.get("investigation") or {}
    source_asset = incident.source_asset
    suspect_asset = incident.suspect_asset
    match = incident.match
    risk = getattr(incident, "risk", None)

    payload = {
        **bundle,
        "available": True,
        "mode": "LIVE_DEMO",
        "generated_at": timezone.now().isoformat().replace("+00:00", "Z"),
        "organization": _organization_payload(organization),
        "dataset": _dataset_payload(source_asset),
        "movement": _movement_payload(bundle.get("timeline") or []),
        "ghost_copy": _ghost_copy_payload(source_asset, suspect_asset, match),
        "intake": _intake_payload(investigation, suspect_asset),
        "tracking": {
            "lineage": lineage,
            "timeline": bundle.get("timeline") or [],
            "audit_trail": bundle.get("audit_trail") or [],
        },
        "behaviour": _behaviour_payload(risk),
        "policy": _policy_payload(),
    }
    return payload


class SimulationStoryboardView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny, IsDemoMode]

    def get(self, request):
        organization = _demo_organization()
        if organization is None:
            return Response(
                {
                    "available": False,
                    "mode": "NO_DEMO_WORKSPACE",
                    "generated_at": timezone.now().isoformat().replace("+00:00", "Z"),
                    "reason": "The demo workspace has not been seeded.",
                },
                headers={"Cache-Control": "no-store"},
            )
        return Response(
            build_storyboard(organization),
            headers={"Cache-Control": "no-store"},
        )
