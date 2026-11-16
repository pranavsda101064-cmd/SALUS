from django.db import models


class CellFingerprint(models.Model):
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="fingerprints"
    )
    asset = models.ForeignKey(
        "assets.Asset", on_delete=models.CASCADE, related_name="fingerprints"
    )
    column_name = models.CharField(max_length=255)
    value_hash = models.CharField(max_length=64, db_index=True)
    weight = models.FloatField(default=1.0)
    count = models.IntegerField(default=1)
    pii_type = models.CharField(max_length=32, default="OTHER")

    class Meta:
        indexes = [
            models.Index(fields=["organization", "value_hash"]),
            models.Index(fields=["asset", "value_hash"]),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["asset", "column_name", "value_hash"], name="uniq_asset_column_value"
            )
        ]


class CanaryIssuance(models.Model):
    public_id = models.CharField(max_length=32, unique=True)
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="canary_issuances"
    )
    asset = models.ForeignKey(
        "assets.Asset", on_delete=models.CASCADE, related_name="canary_issuances"
    )
    recipient = models.CharField(max_length=255)
    token = models.CharField(max_length=64)
    value_hashes = models.JSONField(default=list, blank=True)
    row_labels = models.JSONField(default=list, blank=True)
    issued_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-issued_at"]


class MatchRecord(models.Model):
    public_id = models.CharField(max_length=32, unique=True)
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="matches"
    )
    query_asset = models.ForeignKey(
        "assets.Asset", on_delete=models.CASCADE, related_name="matches_as_query"
    )
    source_asset = models.ForeignKey(
        "assets.Asset", on_delete=models.CASCADE, related_name="matches_as_source"
    )
    method = models.CharField(max_length=64, default="CELL_HASH_WEIGHTED_V1")
    match_score = models.FloatField(default=0)
    containment = models.FloatField(default=0)
    recall_vs_original = models.FloatField(default=0)
    matched_rows = models.IntegerField(default=0)
    matched_cells = models.IntegerField(default=0)
    matched_columns = models.JSONField(default=list, blank=True)
    dropped_columns = models.JSONField(default=list, blank=True)
    canary = models.JSONField(default=dict, blank=True)
    evidence = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["organization", "match_score"]),
        ]

    def __str__(self):
        return f"{self.public_id} {self.match_score}"
