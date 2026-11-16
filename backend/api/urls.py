from django.urls import path

from api import views
from api.simulation import SimulationStoryboardView

urlpatterns = [
    path("health", views.HealthView.as_view(), name="health"),
    path("auth/demo-login", views.DemoLoginView.as_view(), name="demo-login"),
    path("organizations/me", views.MeView.as_view(), name="me"),
    path("overview", views.OverviewView.as_view(), name="overview"),
    path("assets", views.AssetListView.as_view(), name="assets"),
    path("assets/<str:asset_id>", views.AssetDetailView.as_view(), name="asset-detail"),
    path("assets/<str:asset_id>/events", views.AssetEventsView.as_view(), name="asset-events"),
    path("investigations", views.InvestigationView.as_view(), name="investigations"),
    path(
        "investigations/<str:investigation_id>",
        views.InvestigationDetailView.as_view(),
        name="investigation-detail",
    ),
    path("audit", views.AuditListView.as_view(), name="audit"),
    path("incidents", views.IncidentListView.as_view(), name="incidents"),
    path("incidents/<str:incident_id>", views.IncidentDetailView.as_view(), name="incident-detail"),
    path(
        "incidents/<str:incident_id>/lineage",
        views.IncidentLineageView.as_view(),
        name="incident-lineage",
    ),
    path(
        "incidents/<str:incident_id>/status",
        views.IncidentStatusView.as_view(),
        name="incident-status",
    ),
    path(
        "incidents/<str:incident_id>/report",
        views.IncidentReportView.as_view(),
        name="incident-report",
    ),
    path("events", views.EventListView.as_view(), name="events"),
    path("simulator/run", views.SimulatorRunView.as_view(), name="simulator-run"),
    path(
        "simulation/ghost-copy",
        SimulationStoryboardView.as_view(),
        name="simulation-ghost-copy",
    ),
    path("dev/seed", views.DevSeedView.as_view(), name="dev-seed"),
    path("risk/policy", views.RiskPolicyView.as_view(), name="risk-policy"),
]
