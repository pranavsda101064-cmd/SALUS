from django.db import models


class Report(models.Model):
    public_id = models.CharField(max_length=32, unique=True)
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="reports"
    )
    incident = models.OneToOneField(
        "incidents.Incident", on_delete=models.CASCADE, related_name="report"
    )
    provider = models.CharField(max_length=32, default="SALUS_TEMPLATE")
    model = models.CharField(max_length=64, blank=True)
    grounding_refs = models.JSONField(default=list, blank=True)
    evidence_hash = models.CharField(max_length=64, blank=True)
    content = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.public_id} {self.provider}"
