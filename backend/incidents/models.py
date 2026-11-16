from django.db import models


class Incident(models.Model):
    STATUS_CHOICES = [
        ("OPEN", "Open"),
        ("TRIAGED", "Triaged"),
        ("CONTAINED", "Contained"),
        ("CLOSED", "Closed"),
    ]
    public_id = models.CharField(max_length=32, unique=True)
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="incidents"
    )
    title = models.CharField(max_length=255)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default="OPEN")
    severity = models.CharField(max_length=16, default="LOW")
    suspect_asset = models.ForeignKey(
        "assets.Asset", on_delete=models.SET_NULL, null=True, related_name="incidents_as_suspect"
    )
    source_asset = models.ForeignKey(
        "assets.Asset", on_delete=models.SET_NULL, null=True, related_name="incidents_as_source"
    )
    match = models.ForeignKey(
        "data_dna.MatchRecord", on_delete=models.SET_NULL, null=True, related_name="incidents"
    )
    evidence = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["organization", "status", "created_at"]),
            models.Index(fields=["organization", "severity"]),
        ]

    def __str__(self):
        return f"{self.public_id} {self.title}"


class Investigation(models.Model):
    STATUS_CHOICES = [
        ("OPEN", "Open"),
        ("CLOSED", "Closed"),
        ("NO_MATCH", "No match"),
    ]

    public_id = models.CharField(max_length=32, unique=True)
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="investigations"
    )
    created_by = models.ForeignKey(
        "organizations.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="investigations",
    )
    source_asset = models.ForeignKey(
        "assets.Asset",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="investigations_as_source",
    )
    suspect_asset = models.ForeignKey(
        "assets.Asset",
        on_delete=models.CASCADE,
        related_name="investigations_as_suspect",
    )
    match = models.OneToOneField(
        "data_dna.MatchRecord",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="investigation",
    )
    incident = models.OneToOneField(
        "incidents.Incident",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="investigation",
    )
    input_filename = models.CharField(max_length=255, blank=True)
    input_sha256 = models.CharField(max_length=64, db_index=True)
    input_rows = models.IntegerField(default=0)
    input_columns = models.IntegerField(default=0)
    status = models.CharField(max_length=16, choices=STATUS_CHOICES, default="OPEN")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["organization", "input_sha256"], name="uniq_org_investigation_input"
            )
        ]

    def __str__(self):
        return f"{self.public_id} {self.input_filename}"
