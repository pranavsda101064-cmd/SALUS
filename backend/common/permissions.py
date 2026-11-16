from django.conf import settings
from rest_framework.permissions import BasePermission


class IsSameOrganization(BasePermission):
    message = "This object belongs to another organization."

    def has_object_permission(self, request, view, obj):
        org_id = getattr(request.user, "organization_id", None)
        obj_org_id = getattr(obj, "organization_id", None)
        return bool(org_id and obj_org_id and org_id == obj_org_id)


class IsDemoMode(BasePermission):
    message = "This endpoint is only available in demo mode."

    def has_permission(self, request, view):
        return bool(settings.DEMO_MODE)
