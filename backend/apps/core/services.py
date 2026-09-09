import hashlib
import json
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import APIException
from rest_framework.response import Response

from .models import AuditLog, IdempotencyRecord, RateLimitBucket


class DomainError(APIException):
    def __init__(self, code, message, status=409, details=None):
        self.status_code = status
        self.code = code
        self.message = message
        self.details = details or []
        super().__init__(message, code)


def audit(request, event, resource_id="", **details):
    user = request.user if request.user.is_authenticated else None
    AuditLog.objects.create(
        actor=user,
        event=event,
        resource_id=resource_id,
        request_id=request.request_id,
        details=details,
    )


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def rate_limit(key, limit, seconds=60):
    now = timezone.now()
    with transaction.atomic():
        bucket, _ = RateLimitBucket.objects.get_or_create(
            key=digest(key), defaults={"reset_at": now + timedelta(seconds=seconds)}
        )
        bucket = RateLimitBucket.objects.select_for_update().get(pk=bucket.pk)
        if bucket.reset_at <= now:
            bucket.count, bucket.reset_at = 0, now + timedelta(seconds=seconds)
        bucket.count += 1
        bucket.save()
        blocked = bucket.count > limit
    if blocked:
        from rest_framework.exceptions import Throttled

        raise Throttled(wait=seconds)


def version_match(request, program):
    header = request.headers.get("If-Match")
    if not header:
        raise DomainError("PRECONDITION_REQUIRED", "If-Match is required.", 428)
    if header != f'"{program.version}"':
        raise DomainError(
            "VERSION_CONFLICT",
            "Fetch the current submission version before retrying.",
            412,
        )


def idempotent(request, payload, callback):
    key = request.headers.get("Idempotency-Key", "")
    if not 16 <= len(key) <= 128:
        raise DomainError(
            "BAD_REQUEST", "Idempotency-Key must have 16 to 128 characters.", 400
        )
    scope = digest(f"{request.user.pk}:{request.method}:{request.path}:{key}")
    fingerprint = digest(
        json.dumps(
            {"body": payload, "ifMatch": request.headers.get("If-Match")},
            sort_keys=True,
            default=str,
        )
    )
    with transaction.atomic():
        # Serialize this actor's writes; the target program is locked separately.
        get_user_model().objects.select_for_update().get(pk=request.user.pk)
        record = IdempotencyRecord.objects.filter(scope=scope).first()
        if record and record.expires_at <= timezone.now():
            record.delete()
            record = None
        if record:
            if record.request_hash != fingerprint:
                raise DomainError(
                    "IDEMPOTENCY_KEY_REUSED",
                    "This key was used for a different request.",
                )
            body = dict(record.body)
            body["meta"] = {**body["meta"], "requestId": request.request_id}
            return Response(body, status=record.status_code, headers=record.headers)
        response = callback()
        headers = {k: response[k] for k in ["ETag", "Location"] if k in response}
        IdempotencyRecord.objects.create(
            scope=scope,
            request_hash=fingerprint,
            body=response.data,
            status_code=response.status_code,
            headers=headers,
            expires_at=timezone.now() + timedelta(hours=24),
        )
        return response
