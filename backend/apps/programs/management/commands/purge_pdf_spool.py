from datetime import timedelta
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.core.models import AuditLog
from apps.core.retention import PDF_SPOOL_HOURS, RETENTION_BATCH_SIZE


class Command(BaseCommand):
    help = "Delete unexpected PDF spool files older than the approved 24-hour limit."

    def add_arguments(self, parser):
        parser.add_argument("--confirm", action="store_true")
        parser.add_argument(
            "--batch-size", type=int, default=RETENTION_BATCH_SIZE
        )

    def handle(self, *args, **options):
        size = options["batch_size"]
        if not 1 <= size <= 5000:
            from django.core.management.base import CommandError

            raise CommandError("Batch size must be between 1 and 5000.")
        root = Path(settings.MEDIA_ROOT).resolve()
        spool = (root / "pdf-spool").resolve()
        if not spool.is_relative_to(root) or not spool.exists():
            self.stdout.write("Dry run: 0 PDF spool file(s) eligible.")
            return
        cutoff = timezone.now() - timedelta(hours=PDF_SPOOL_HOURS)
        eligible = []
        for candidate in sorted(spool.rglob("*.pdf")):
            if len(eligible) >= size:
                break
            if (
                candidate.is_symlink()
                or not candidate.is_file()
                or not candidate.resolve().is_relative_to(spool)
            ):
                continue
            modified = timezone.datetime.fromtimestamp(
                candidate.stat().st_mtime, tz=timezone.get_current_timezone()
            )
            if modified < cutoff:
                eligible.append(candidate)
        if not options["confirm"]:
            self.stdout.write(
                f"Dry run: {len(eligible)} PDF spool file(s) eligible."
            )
            return
        for candidate in eligible:
            candidate.unlink(missing_ok=True)
        AuditLog.objects.create(
            event="pdfRetentionCompleted",
            resource_id="retention",
            request_id="management_command",
            details={"deleted": len(eligible)},
        )
        self.stdout.write(f"Deleted {len(eligible)} PDF spool file(s).")
