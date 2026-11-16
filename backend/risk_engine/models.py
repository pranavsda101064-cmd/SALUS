from django.db import models


class RiskAssessment(models.Model):
    public_id = models.CharField(max_length=32, unique=True)
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="risk_assessments"
    )
    incident = models.OneToOneField(
        "incidents.Incident", on_delete=models.CASCADE, related_name="risk"
    )
    total = models.IntegerField(default=0)
    band = models.CharField(max_length=16, default="LOW")
    factors = models.JSONField(default=dict, blank=True)
    weights = models.JSONField(default=dict, blank=True)
    policy_version = models.CharField(max_length=32, default="risk-v1-demo")
    computed_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.public_id} {self.total}"
