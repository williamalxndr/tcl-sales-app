import time

from django.core.management.base import BaseCommand

from apps.programs.models import Attachment
from apps.programs.uploads import scan_attachment


class Command(BaseCommand):
    help = "Scan quarantined files with ClamAV. Unavailable scanner or encrypted files stay pending."

    def add_arguments(self, parser):
        parser.add_argument("--watch", action="store_true")

    def handle(self, *args, **options):
        while True:
            ids = (
                Attachment.objects.filter(
                    scan_status="pending", removed_at__isnull=True
                )
                .order_by("uploaded_at", "id")
                .values_list("id", flat=True)
                .iterator(chunk_size=100)
            )
            for id in ids:
                try:
                    scan_attachment(id)
                except (OSError, TimeoutError):
                    self.stderr.write(
                        "Scanner/storage unavailable; file remains quarantined."
                    )
            if not options["watch"]:
                break
            time.sleep(10)
