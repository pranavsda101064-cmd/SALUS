from django.db import models


class Asset(models.Model):
    KIND_CHOICES = [
        ("ORIGINAL", "Original"),
        ("DERIVED", "Derived"),
        ("SUSPECT", "Suspect"),
    ]

    public_id = models.CharField(max_length=32, unique=True)
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="assets"
    )
    name = models.CharField(max_length=255)
    original_filename = models.CharField(max_length=255, blank=True)
    kind = models.CharField(max_length=16, choices=KIND_CHOICES, default="ORIGINAL")
    row_count = models.IntegerField(default=0)
    column_count = models.IntegerField(default=0)
    columns = models.JSONField(default=list, blank=True)
    sensitivity_score = models.IntegerField(default=0)
    sensitivity_label = models.CharField(max_length=16, default="LOW")
    exact_sha256 = models.CharField(max_length=64, blank=True)
    dna_version = models.CharField(max_length=32, default="dna-v1")
    cell_count = models.IntegerField(default=0)
    unique_cell_count = models.IntegerField(default=0)
    canary_rows = models.IntegerField(default=0)
    watermark = models.CharField(max_length=64, blank=True)
    is_baseline = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["organization", "kind", "is_baseline"]),
            models.Index(fields=["organization", "created_at"]),
        ]

    def __str__(self):
        return f"{self.public_id} {self.name}"
