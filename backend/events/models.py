from django.db import models


class Event(models.Model):
    ACTION_CHOICES = [
        ("FILE_VIEWED", "File viewed"),
        ("FILE_DOWNLOADED", "File downloaded"),
        ("FILE_COPIED", "File copied"),
        ("EXTERNAL_SHARE", "External share"),
        ("SUSPECT_UPLOAD", "Suspect upload"),
    ]
    SOURCE_CHOICES = [
        ("SIMULATOR", "Simulator"),
        ("INTAKE", "Intake"),
        ("CONNECTOR", "Connector"),
        ("MANUAL", "Manual"),
    ]

    event_id = models.CharField(max_length=32)
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="events"
    )
    actor_id = models.CharField(max_length=32)
    actor_ref = models.ForeignKey(
        "organizations.User",
        on_delete=models.SET_NULL,
        related_name="events",
        null=True,
        blank=True,
    )
    asset_ref = models.ForeignKey(
        "assets.Asset", on_delete=models.SET_NULL, related_name="events", null=True, blank=True
    )
    asset_id = models.CharField(max_length=32, blank=True)
    action = models.CharField(max_length=32, choices=ACTION_CHOICES)
    source = models.CharField(max_length=16, choices=SOURCE_CHOICES, default="SIMULATOR")
    destination = models.CharField(max_length=255, blank=True)
    timestamp = models.DateTimeField(db_index=True)
    evidence = models.JSONField(default=dict, blank=True)
    simulated = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["timestamp"]
        constraints = [
            models.UniqueConstraint(
                fields=["organization", "event_id"], name="uniq_org_event_id"
            )
        ]
        indexes = [
            models.Index(fields=["organization", "asset_id", "timestamp"]),
            models.Index(fields=["organization", "actor_id", "timestamp"]),
        ]

    def __str__(self):
        return f"{self.event_id} {self.action}"
