def log_audit(organization, actor, action, entity_type, entity_id, detail=None):
    from organizations.models import AuditLog

    safe_actor = None
    if actor is not None and getattr(actor, "organization_id", None) == organization.id:
        safe_actor = actor

    return AuditLog.objects.create(
        organization=organization,
        actor=safe_actor,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id or "",
        detail=detail or {},
    )
