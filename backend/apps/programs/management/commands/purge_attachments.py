from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from apps.core.models import AuditLog
from apps.core.retention import (
    CLOSED_ATTACHMENT_DAYS,
    REMOVED_ATTACHMENT_DAYS,
    RETENTION_BATCH_SIZE,
)
from apps.programs.models import Attachment
from apps.programs.uploads import private_path

TERMINAL_STATUSES = ["approved", "rejected", "cancelled"]


def eligible_query(now):
    removed_before = now - timedelta(days=REMOVED_ATTACHMENT_DAYS)
    closed_before = now - timedelta(days=CLOSED_ATTACHMENT_DAYS)
    return Q(removed_at__lt=removed_before) | Q(
        program__status__in=TERMINAL_STATUSES,
        program__closed_at__lt=closed_before,
    )


class Command(BaseCommand):
    help = "Delete attachment bytes and metadata after the approved retention period."

    def add_arguments(self, parser):
        parser.add_argument("--confirm", action="store_true")
        parser.add_argument(
            "--batch-size", type=int, default=RETENTION_BATCH_SIZE
        )

    def handle(self, *args, **options):
        size = options["batch_size"]
        if not 1 <= size <= 5000:
            raise CommandError("Batch size must be between 1 and 5000.")
        now = timezone.now()
        ids = list(
            Attachment.objects.filter(eligible_query(now))
            .order_by("uploaded_at", "id")
            .values_list("id", flat=True)[:size]
        )
        if not options["confirm"]:
            self.stdout.write(f"Dry run: {len(ids)} attachment(s) eligible.")
            return
        deleted = 0
        for attachment_id in ids:
            with transaction.atomic():
                item = (
                    Attachment.objects.select_for_update()
                    .filter(pk=attachment_id)
                    .filter(eligible_query(now))
                    .first()
                )
                if item is None:
                    continue
                private_path(item.storage_key).unlink(missing_ok=True)
                item.delete()
                deleted += 1
        AuditLog.objects.create(
            event="attachmentRetentionCompleted",
            resource_id="retention",
            request_id="management_command",
            details={"deleted": deleted, "eligible": len(ids)},
        )
        self.stdout.write(f"Deleted {deleted} retained attachment(s).")
