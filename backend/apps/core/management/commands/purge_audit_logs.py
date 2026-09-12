from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.core.models import AuditLog
from apps.core.retention import AUDIT_LOG_DAYS, RETENTION_BATCH_SIZE


class Command(BaseCommand):
    help = "Delete audit rows older than the approved seven-year retention period."

    def add_arguments(self, parser):
        parser.add_argument("--confirm", action="store_true")
        parser.add_argument(
            "--batch-size", type=int, default=RETENTION_BATCH_SIZE
        )

    def handle(self, *args, **options):
        size = options["batch_size"]
        if not 1 <= size <= 5000:
            raise CommandError("Batch size must be between 1 and 5000.")
        cutoff = timezone.now() - timedelta(days=AUDIT_LOG_DAYS)
        ids = list(
            AuditLog.objects.filter(occurred_at__lt=cutoff)
            .order_by("occurred_at", "id")
            .values_list("id", flat=True)[:size]
        )
        if not options["confirm"]:
            self.stdout.write(f"Dry run: {len(ids)} audit log(s) eligible.")
            return
        with transaction.atomic():
            deleted, _ = AuditLog.objects.filter(pk__in=ids).delete()
            AuditLog.objects.create(
                event="auditRetentionCompleted",
                resource_id="retention",
                request_id="management_command",
                details={"deleted": deleted, "cutoff": cutoff.isoformat()},
            )
        self.stdout.write(f"Deleted {deleted} retained audit log(s).")
