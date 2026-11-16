from django.db import models


class BehaviourModel(models.Model):
    organization = models.ForeignKey(
        "organizations.Organization", on_delete=models.CASCADE, related_name="behaviour_models"
    )
    actor_id = models.CharField(max_length=32)
    version = models.CharField(max_length=32, default="ae-v1")
    model_blob = models.BinaryField()
    baseline = models.JSONField(default=dict, blank=True)
    sample_count = models.IntegerField(default=0)
    trained_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["organization", "actor_id", "version"], name="uniq_actor_model_version"
            )
        ]

    def __str__(self):
        return f"{self.actor_id} {self.version}"
