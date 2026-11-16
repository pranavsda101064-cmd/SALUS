from uuid import uuid4

from django.contrib.auth.models import AbstractUser
from django.db import models


def new_public_id(prefix):
    return f"{prefix}-{uuid4().hex[:6].upper()}"


def new_user_public_id():
    return new_public_id("USER")


class Organization(models.Model):
    id = models.CharField(primary_key=True, max_length=32)
    name = models.CharField(max_length=200)
    slug = models.SlugField(max_length=80, unique=True)
    industry = models.CharField(max_length=120, blank=True)
    is_demo = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return f"{self.id} {self.name}"


class User(AbstractUser):
    public_id = models.CharField(max_length=32, unique=True, default=new_user_public_id)
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="users", null=True, blank=True
    )
    role = models.CharField(max_length=40, default="OWNER")
    display_name = models.CharField(max_length=160, blank=True)

    @property
    def name(self):
        return self.display_name or self.get_full_name() or self.username

    def __str__(self):
        return f"{self.public_id} {self.name}"


class AuditLog(models.Model):
    organization = models.ForeignKey(
        Organization, on_delete=models.CASCADE, related_name="audit_logs"
    )
    actor = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name="audit_logs"
    )
    action = models.CharField(max_length=64)
    entity_type = models.CharField(max_length=32)
    entity_id = models.CharField(max_length=32)
    detail = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["organization", "entity_type", "entity_id"]),
            models.Index(fields=["organization", "created_at"]),
        ]

    def __str__(self):
        return f"{self.action} {self.entity_type} {self.entity_id}"
