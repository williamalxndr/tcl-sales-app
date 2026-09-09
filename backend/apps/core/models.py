from django.conf import settings
from django.db import models


class AuditLog(models.Model):
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, on_delete=models.PROTECT
    )
    event = models.CharField(max_length=80)
    resource_id = models.CharField(max_length=64, blank=True)
    request_id = models.CharField(max_length=64)
    details = models.JSONField(default=dict)
    occurred_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["resource_id", "occurred_at"])]


class IdempotencyRecord(models.Model):
    scope = models.CharField(max_length=64, unique=True)
    request_hash = models.CharField(max_length=64)
    body = models.JSONField()
    status_code = models.PositiveSmallIntegerField()
    headers = models.JSONField(default=dict)
    expires_at = models.DateTimeField()


class RateLimitBucket(models.Model):
    key = models.CharField(max_length=64, primary_key=True)
    count = models.PositiveIntegerField(default=0)
    reset_at = models.DateTimeField()
