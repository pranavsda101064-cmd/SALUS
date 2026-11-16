from django.conf import settings
from django.db import connection
from django.db.utils import DatabaseError
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from api.serializers import (
    serialize_asset,
    serialize_audit,
    serialize_event,
    serialize_incident,
    serialize_incident_bundle,
    serialize_investigation,
    serialize_report,
)
from assets.models import Asset
from common.files import FileParseError, extract_watermark, parse_uploaded_file
from common.ids import next_public_id
from common.permissions import IsDemoMode
from common.text import hash_bytes, sanitize_structure
from data_dna.service import prepare_asset
from demo.seed import seed_demo
from events.models import Event
from events.services import EventError
from incidents.models import Incident, Investigation
from incidents.services import create_investigation
from lineage.services import build_lineage
from organizations.audit import log_audit
from organizations.models import AuditLog, Organization, User
from risk_engine.policy import (
    BANDS,
    DESTINATION_TABLE,
    POLICY_VERSION,
    SEQUENCE_TABLE,
    WEIGHTS,
)
from simulator.services import run_ghost_copy_scenario

MAX_PAGE_LIMIT = 500


def bounded_int_param(request, name, default, maximum=MAX_PAGE_LIMIT, minimum=0):
    raw = request.query_params.get(name)
    if raw is None or raw == "":
        return default
    try:
        value = int(raw)
    except (TypeError, ValueError) as exc:
        raise ValidationError({name: "Must be an integer."}) from exc
    if value < minimum:
        raise ValidationError({name: f"Must be {minimum} or greater."})
    return min(value, maximum)


def page_payload(results, total, limit, offset):
    return {
        "results": results,
        "count": total,
        "limit": limit,
        "offset": offset,
    }


class HealthView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        database = "ok"
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        except DatabaseError:
            database = "unavailable"
        payload = {
            "status": "ok" if database == "ok" else "degraded",
            "service": "SALUS",
            "version": "1.0-demo",
            "server_time": timezone.now().isoformat(),
            "database": database,
            "demo_mode": bool(settings.DEMO_MODE),
            "report_provider": "GEMINI" if settings.GEMINI_API_KEY else "SALUS_TEMPLATE",
            "gemini_configured": bool(settings.GEMINI_API_KEY),
        }
        code = status.HTTP_200_OK if database == "ok" else status.HTTP_503_SERVICE_UNAVAILABLE
        return Response(payload, status=code)


class DemoLoginView(APIView):
    permission_classes = [AllowAny, IsDemoMode]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"

    def post(self, request):
        email = str(request.data.get("email", "")).strip()
        if not email:
            return Response({"detail": "email is required"}, status=status.HTTP_400_BAD_REQUEST)
        user = (
            User.objects.filter(email__iexact=email).first()
            or User.objects.filter(username__iexact=email).first()
        )
        if user is None:
            return Response(
                {"detail": "No demo user with that email. Run the seed first."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if user.organization is None:
            return Response(
                {"detail": "This user has no organization."}, status=status.HTTP_400_BAD_REQUEST
            )
        token, _ = Token.objects.get_or_create(user=user)
        seeded = Asset.objects.filter(
            organization=user.organization, kind="ORIGINAL", is_baseline=False
        ).exists()
        return Response(
            {
                "token": token.key,
                "user": {
                    "user_id": user.public_id,
                    "name": user.name,
                    "email": user.email,
                    "role": user.role,
                },
                "organization": {
                    "organization_id": user.organization.id,
                    "name": user.organization.name,
                },
                "demo_seeded": seeded,
            },
            headers={"Cache-Control": "no-store"},
        )


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response(
            {
                "user": {
                    "user_id": user.public_id,
                    "name": user.name,
                    "email": user.email,
                    "role": user.role,
                },
                "organization": {
                    "organization_id": user.organization_id,
                    "name": user.organization.name if user.organization else "",
                },
            }
        )


class OverviewView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        organization = request.user.organization
        assets = Asset.objects.filter(organization=organization, is_baseline=False)
        incidents = Incident.objects.filter(organization=organization)
        open_incidents = incidents.exclude(status="CLOSED")
        events = Event.objects.filter(organization=organization)
        latest = incidents.select_related("risk", "investigation").order_by("-created_at").first()
        latest_payload = None
        if latest is not None:
            latest_payload = {
                "incident_id": latest.public_id,
                "title": latest.title,
                "severity": latest.severity,
                "status": latest.status,
                "risk_total": latest.risk.total if hasattr(latest, "risk") else None,
                "created_at": latest.created_at.isoformat(),
            }
        return Response(
            {
                "organization": {
                    "organization_id": organization.id,
                    "name": organization.name,
                },
                "assets": assets.count(),
                "sensitive_assets": assets.filter(
                    sensitivity_label__in=["HIGH", "CRITICAL"]
                ).count(),
                "critical_assets": assets.filter(sensitivity_label="CRITICAL").count(),
                "open_incidents": open_incidents.count(),
                "critical_incidents": open_incidents.filter(severity="CRITICAL").count(),
                "investigations": Investigation.objects.filter(
                    organization=organization
                ).count(),
                "events": events.count(),
                "simulated_events": events.filter(simulated=True).count(),
                "latest_incident": latest_payload,
                "report_provider": "GEMINI" if settings.GEMINI_API_KEY else "SALUS_TEMPLATE",
                "limits": [
                    "Cannot see USB copies, screenshots, or retyped data.",
                    "A match is a lead, not proof of intent.",
                ],
            }
        )


class AssetListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        organization = request.user.organization
        include_baseline = request.query_params.get("include_baseline") == "1"
        queryset = Asset.objects.filter(organization=organization)
        if not include_baseline:
            queryset = queryset.filter(is_baseline=False)
        kind = request.query_params.get("kind")
        if kind:
            queryset = queryset.filter(kind=kind)
        search = request.query_params.get("q")
        if search:
            queryset = queryset.filter(name__icontains=search)
        limit = bounded_int_param(request, "limit", 200, minimum=1)
        offset = bounded_int_param(request, "offset", 0)
        total = queryset.count()
        results = [serialize_asset(asset) for asset in queryset[offset : offset + limit]]
        return Response(page_payload(results, total, limit, offset))

    def post(self, request):
        organization = request.user.organization
        uploaded = request.FILES.get("file")
        if uploaded is None:
            return Response({"detail": "file is required"}, status=status.HTTP_400_BAD_REQUEST)
        kind = str(request.data.get("kind", "ORIGINAL")).strip().upper()
        if kind not in {"ORIGINAL", "DERIVED"}:
            return Response(
                {"detail": "kind must be ORIGINAL or DERIVED"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            df, raw_bytes, filename = parse_uploaded_file(uploaded)
        except FileParseError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        watermark = extract_watermark(raw_bytes, filename)
        name = filename.rsplit(".", 1)[0][:200]
        asset, _fingerprints = prepare_asset(
            organization=organization,
            name=name,
            filename=filename,
            df=df,
            kind=kind,
            exact_sha256=hash_bytes(raw_bytes),
            watermark=watermark,
            id_floor=9320,
        )
        return Response({"asset": serialize_asset(asset)}, status=status.HTTP_201_CREATED)


class AssetDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, asset_id):
        asset = get_object_or_404(
            Asset, public_id=asset_id, organization=request.user.organization
        )
        return Response({"asset": serialize_asset(asset)})


class AssetEventsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, asset_id):
        asset = get_object_or_404(
            Asset, public_id=asset_id, organization=request.user.organization
        )
        queryset = Event.objects.filter(
            organization=request.user.organization, asset_id=asset.public_id
        ).order_by("-timestamp")
        limit = bounded_int_param(request, "limit", 200, minimum=1)
        offset = bounded_int_param(request, "offset", 0)
        total = queryset.count()
        events = queryset[offset : offset + limit]
        return Response(
            page_payload([serialize_event(event) for event in events], total, limit, offset)
        )


class InvestigationView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "upload"

    def get(self, request):
        organization = request.user.organization
        queryset = Investigation.objects.filter(organization=organization).select_related(
            "created_by",
            "source_asset",
            "suspect_asset",
            "match",
            "incident",
            "incident__risk",
            "incident__report",
        )
        status_filter = request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        limit = bounded_int_param(request, "limit", 100, minimum=1)
        offset = bounded_int_param(request, "offset", 0)
        total = queryset.count()
        results = []
        for investigation in queryset[offset : offset + limit]:
            item = serialize_investigation(investigation)
            incident = investigation.incident
            risk = getattr(incident, "risk", None) if incident else None
            item.update(
                {
                    "risk_total": risk.total if risk else None,
                    "risk_band": risk.band if risk else None,
                    "match_score": investigation.match.match_score
                    if investigation.match
                    else None,
                }
            )
            results.append(item)
        return Response(page_payload(results, total, limit, offset))

    def post(self, request):
        uploaded = request.FILES.get("file")
        if uploaded is None:
            return Response({"detail": "file is required"}, status=status.HTTP_400_BAD_REQUEST)
        try:
            result = create_investigation(request.user.organization, request.user, uploaded)
        except FileParseError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)
        except EventError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        investigation = result["investigation"]
        investigation_payload = serialize_investigation(investigation)

        if result.get("duplicate"):
            if result["matched"]:
                incident = result["incident"]
                lineage = build_lineage(incident)
                bundle = serialize_incident_bundle(incident, lineage=lineage)
                bundle["scanned_sources"] = 0
                return Response(
                    {
                        "matched": True,
                        "duplicate": True,
                        "investigation": investigation_payload,
                        "bundle": bundle,
                    }
                )
            return Response(
                {
                    "matched": False,
                    "duplicate": True,
                    "scanned_sources": 0,
                    "investigation": investigation_payload,
                    "suspect_asset": serialize_asset(result["suspect_asset"]),
                    "message": (
                        "This file was already investigated and no meaningful match was found."
                    ),
                }
            )

        if not result["matched"]:
            return Response(
                {
                    "matched": False,
                    "duplicate": False,
                    "scanned_sources": result["scanned_sources"],
                    "investigation": investigation_payload,
                    "suspect_asset": serialize_asset(result["suspect_asset"]),
                    "message": "No meaningful match was found. The file is stored as metadata only.",
                }
            )

        incident = result["incident"]
        lineage = build_lineage(incident)
        bundle = serialize_incident_bundle(incident, lineage=lineage)
        bundle["scanned_sources"] = result["scanned_sources"]
        return Response(
            {
                "matched": True,
                "duplicate": False,
                "investigation": investigation_payload,
                "bundle": bundle,
            }
        )


class InvestigationDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, investigation_id):
        investigation = get_object_or_404(
            Investigation.objects.select_related(
                "created_by",
                "source_asset",
                "suspect_asset",
                "match",
                "incident",
            ),
            public_id=investigation_id,
            organization=request.user.organization,
        )
        if investigation.incident is not None:
            incident = investigation.incident
            lineage = build_lineage(incident)
            return Response(serialize_incident_bundle(incident, lineage=lineage))
        return Response(
            {
                "investigation": serialize_investigation(investigation),
                "suspect_asset": serialize_asset(investigation.suspect_asset),
                "matched": False,
                "message": "No meaningful match was found for this investigation.",
            }
        )


class IncidentListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        organization = request.user.organization
        queryset = (
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
        )
        status_filter = request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        limit = bounded_int_param(request, "limit", 100, minimum=1)
        offset = bounded_int_param(request, "offset", 0)
        total = queryset.count()
        results = []
        for incident in queryset[offset : offset + limit]:
            risk = getattr(incident, "risk", None)
            report = getattr(incident, "report", None)
            results.append(
                {
                    **serialize_incident(incident),
                    "risk_total": risk.total if risk else None,
                    "risk_band": risk.band if risk else incident.severity,
                    "match_score": incident.match.match_score if incident.match else None,
                    "report_provider": report.provider if report else None,
                }
            )
        return Response(page_payload(results, total, limit, offset))


class IncidentDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, incident_id):
        incident = get_object_or_404(
            Incident.objects.select_related(
                "risk",
                "report",
                "match",
                "match__query_asset",
                "match__source_asset",
                "source_asset",
                "suspect_asset",
                "investigation",
            ),
            public_id=incident_id,
            organization=request.user.organization,
        )
        lineage = build_lineage(incident)
        return Response(serialize_incident_bundle(incident, lineage=lineage))


class IncidentLineageView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, incident_id):
        incident = get_object_or_404(
            Incident.objects.select_related(
                "match", "match__query_asset", "match__source_asset", "source_asset", "suspect_asset"
            ),
            public_id=incident_id,
            organization=request.user.organization,
        )
        return Response(build_lineage(incident))


class IncidentStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, incident_id):
        incident = get_object_or_404(
            Incident, public_id=incident_id, organization=request.user.organization
        )
        new_status = str(request.data.get("status", "")).upper()
        allowed = {choice[0] for choice in Incident.STATUS_CHOICES}
        if new_status not in allowed:
            return Response(
                {"detail": f"status must be one of {sorted(allowed)}"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        previous_status = incident.status
        incident.status = new_status
        incident.save(update_fields=["status", "updated_at"])
        log_audit(
            request.user.organization,
            request.user,
            "INCIDENT_STATUS_CHANGED",
            "INCIDENT",
            incident.public_id,
            {"from": previous_status, "to": new_status},
        )
        return Response({"incident": serialize_incident(incident)})


class IncidentReportView(APIView):
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "report"

    def post(self, request, incident_id):
        from ai_reports.composer import generate_report

        incident = get_object_or_404(
            Incident, public_id=incident_id, organization=request.user.organization
        )
        report = generate_report(incident)
        log_audit(
            request.user.organization,
            request.user,
            "REPORT_REGENERATED",
            "INCIDENT",
            incident.public_id,
            {
                "report_id": report.public_id,
                "provider": report.provider,
                "evidence_hash": report.evidence_hash,
            },
        )
        return Response({"report": serialize_report(report)})


class EventListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        organization = request.user.organization
        queryset = Event.objects.filter(organization=organization)
        for field in ["asset_id", "actor_id", "action", "source"]:
            value = request.query_params.get(field)
            if value:
                queryset = queryset.filter(**{field: value})
        if request.query_params.get("simulated") in {"0", "1"}:
            queryset = queryset.filter(simulated=request.query_params.get("simulated") == "1")
        limit = bounded_int_param(request, "limit", 100, minimum=1)
        offset = bounded_int_param(request, "offset", 0)
        total = queryset.count()
        events = queryset.order_by("-timestamp")[offset : offset + limit]
        return Response(
            page_payload([serialize_event(event) for event in events], total, limit, offset)
        )


class AuditListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        organization = request.user.organization
        queryset = AuditLog.objects.filter(organization=organization).select_related("actor")
        entity_type = request.query_params.get("entity_type")
        entity_id = request.query_params.get("entity_id")
        if entity_type:
            queryset = queryset.filter(entity_type=entity_type)
        if entity_id:
            queryset = queryset.filter(entity_id=entity_id)
        limit = bounded_int_param(request, "limit", 100, minimum=1)
        offset = bounded_int_param(request, "offset", 0)
        total = queryset.count()
        results = [serialize_audit(log) for log in queryset[offset : offset + limit]]
        return Response(page_payload(results, total, limit, offset))


class SimulatorRunView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        organization = request.user.organization
        scenario = request.data.get("scenario", "ghost_copy")
        if scenario != "ghost_copy":
            return Response(
                {"detail": "Only the ghost_copy scenario is implemented."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        source = (
            Asset.objects.filter(organization=organization, kind="ORIGINAL", is_baseline=False)
            .order_by("created_at")
            .first()
        )
        if source is None:
            return Response(
                {"detail": "No source dataset exists. Run the demo seed first."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        actor_id = str(request.data.get("actor_id") or "USER-104")
        actor = User.objects.filter(
            organization=organization, public_id=actor_id
        ).first()
        if actor is None:
            return Response(
                {"detail": "actor_id must belong to this organization."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        created, existing = run_ghost_copy_scenario(
            organization, source, actor.public_id, fresh=True
        )
        return Response(
            {
                "scenario": scenario,
                "created": [serialize_event(event) for event in created],
                "existing": [serialize_event(event) for event in existing],
                "simulated": True,
            }
        )


class DevSeedView(APIView):
    permission_classes = [AllowAny, IsDemoMode]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "seed"

    def post(self, request):
        result = seed_demo(reset=bool(request.data.get("reset", False)))
        result.pop("manifest", None)
        return Response(sanitize_structure(result), headers={"Cache-Control": "no-store"})


class RiskPolicyView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        return Response(
            {
                "formula": "R = 0.35*S + 0.30*D + 0.20*B + 0.15*E",
                "weights": WEIGHTS,
                "bands": [{"band": band, "min": minimum} for band, minimum in BANDS],
                "destination_table": DESTINATION_TABLE,
                "sequence_table": SEQUENCE_TABLE,
                "policy_version": POLICY_VERSION,
                "disclaimer": "These are demo policy values, not validated standards. The engine is deterministic; the LLM only explains.",
            }
        )
