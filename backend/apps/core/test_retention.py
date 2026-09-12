from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone

from .models import AuditLog


class AuditRetentionTests(TestCase):
    def test_command_is_dry_run_then_deletes_only_expired_rows(self):
        expired = AuditLog.objects.create(
            event="expired",
            request_id="test",
            resource_id="old",
        )
        recent = AuditLog.objects.create(
            event="recent",
            request_id="test",
            resource_id="new",
        )
        AuditLog.objects.filter(pk=expired.pk).update(
            occurred_at=timezone.now() - timedelta(days=2558)
        )

        call_command("purge_audit_logs")
        self.assertTrue(AuditLog.objects.filter(pk=expired.pk).exists())
        call_command("purge_audit_logs", confirm=True)
        self.assertFalse(AuditLog.objects.filter(pk=expired.pk).exists())
        self.assertTrue(AuditLog.objects.filter(pk=recent.pk).exists())
        self.assertTrue(
            AuditLog.objects.filter(event="auditRetentionCompleted").exists()
        )
