from django.db import models


class ScanResult(models.Model):
    asset = models.OneToOneField(
        "assets.Asset", on_delete=models.CASCADE, related_name="scan_result"
    )
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="scan_results"
    )
    pii_summary = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"scan {self.asset_id}"
