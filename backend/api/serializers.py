from common.timeutil import to_utc_iso
from events.services import serialize_event


def serialize_asset(asset):
    if asset is None:
        return None
    return {
        "asset_id": asset.public_id,
        "organization_id": asset.organization_id,
        "name": asset.name,
        "original_filename": asset.original_filename,
        "kind": asset.kind,
        "row_count": asset.row_count,
        "column_count": asset.column_count,
        "columns": asset.columns,
        "sensitivity_score": asset.sensitivity_score,
        "sensitivity_label": asset.sensitivity_label,
        "exact_sha256": asset.exact_sha256,
        "dna": {
            "version": asset.dna_version,
            "cell_fingerprints": asset.cell_count,
            "unique_cells": asset.unique_cell_count,
            "canary_rows": asset.canary_rows,
        },
        "watermark": asset.watermark,
        "is_baseline": asset.is_baseline,
        "created_at": to_utc_iso(asset.created_at),
    }


def serialize_match(match):
    if match is None:
        return None
    return {
        "match_id": match.public_id,
        "query_asset_id": match.query_asset.public_id,
        "source_asset_id": match.source_asset.public_id,
        "method": match.method,
        "match_score": match.match_score,
        "containment": match.containment,
        "recall_vs_original": match.recall_vs_original,
        "matched_rows": match.matched_rows,
        "matched_cells": match.matched_cells,
        "matched_columns": match.matched_columns,
        "dropped_columns": match.dropped_columns,
        "canary": match.canary,
        "evidence": match.evidence,
        "created_at": to_utc_iso(match.created_at),
    }


def serialize_risk(risk):
    if risk is None:
        return None
    if hasattr(risk, "factors"):
        return {
            "risk_id": risk.public_id,
            "incident_id": risk.incident.public_id,
            "total": risk.total,
            "band": risk.band,
            "weights": risk.weights,
            "factors": risk.factors,
            "policy_version": risk.policy_version,
            "computed_at": to_utc_iso(risk.computed_at),
        }
    return risk


def serialize_report(report):
    if report is None:
        return None
    content = dict(report.content or {})
    content.update(
        {
            "report_id": report.public_id,
            "incident_id": report.incident.public_id,
            "provider": report.provider,
            "model": report.model,
            "grounding_refs": report.grounding_refs,
            "evidence_hash": report.evidence_hash,
            "generated_at": to_utc_iso(report.created_at),
        }
    )
    return content


def serialize_investigation(investigation):
    if investigation is None:
        return None
    return {
        "investigation_id": investigation.public_id,
        "organization_id": investigation.organization_id,
        "status": investigation.status,
        "created_by": investigation.created_by.public_id
        if investigation.created_by
        else None,
        "source_asset_id": investigation.source_asset.public_id
        if investigation.source_asset
        else None,
        "suspect_asset_id": investigation.suspect_asset.public_id
        if investigation.suspect_asset
        else None,
        "match_id": investigation.match.public_id if investigation.match else None,
        "incident_id": investigation.incident.public_id if investigation.incident else None,
        "input": {
            "filename": investigation.input_filename,
            "sha256": investigation.input_sha256,
            "rows": investigation.input_rows,
            "columns": investigation.input_columns,
        },
        "created_at": to_utc_iso(investigation.created_at),
    }


def serialize_audit(log):
    return {
        "audit_id": log.id,
        "action": log.action,
        "actor_id": log.actor.public_id if log.actor else None,
        "entity_type": log.entity_type,
        "entity_id": log.entity_id,
        "detail": log.detail,
        "created_at": to_utc_iso(log.created_at),
    }


def serialize_incident(incident):
    evidence = incident.evidence or {}
    investigation = getattr(incident, "investigation", None)
    return {
        "incident_id": incident.public_id,
        "organization_id": incident.organization_id,
        "title": incident.title,
        "status": incident.status,
        "severity": incident.severity,
        "suspect_asset_id": incident.suspect_asset.public_id if incident.suspect_asset else None,
        "source_asset_id": incident.source_asset.public_id if incident.source_asset else None,
        "match_id": incident.match.public_id if incident.match else None,
        "investigation_id": investigation.public_id if investigation else None,
        "created_at": to_utc_iso(incident.created_at),
        "correlation": evidence.get("correlation", {}),
    }


def serialize_incident_bundle(incident, lineage=None):
    from ai_reports.models import Report
    from organizations.models import AuditLog
    from risk_engine.models import RiskAssessment

    risk = getattr(incident, "risk", None)
    if risk is None:
        risk = RiskAssessment.objects.filter(incident=incident).first()
    report = Report.objects.filter(incident=incident).first()
    investigation = getattr(incident, "investigation", None)
    audit_trail = [
        serialize_audit(log)
        for log in AuditLog.objects.filter(
            organization=incident.organization,
            entity_type="INCIDENT",
            entity_id=incident.public_id,
        )[:20]
    ]
    timeline = []
    for event in incident.evidence.get("timeline_events", []):
        timeline.append(event)
    return {
        "incident": serialize_incident(incident),
        "investigation": serialize_investigation(investigation),
        "source_asset": serialize_asset(incident.source_asset),
        "suspect_asset": serialize_asset(incident.suspect_asset),
        "match": serialize_match(incident.match),
        "risk": serialize_risk(risk),
        "timeline": timeline,
        "lineage": lineage,
        "report": serialize_report(report),
        "audit_trail": audit_trail,
        "limits": (incident.evidence or {}).get("limits", []),
    }


__all__ = [
    "serialize_asset",
    "serialize_audit",
    "serialize_event",
    "serialize_incident",
    "serialize_incident_bundle",
    "serialize_investigation",
    "serialize_match",
    "serialize_report",
    "serialize_risk",
]
