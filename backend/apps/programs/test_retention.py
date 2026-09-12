import tempfile
import os
from datetime import timedelta
from pathlib import Path

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone

from .models import Attachment, Program


class AttachmentRetentionTests(TestCase):
    def setUp(self):
        self.files = tempfile.TemporaryDirectory()
        self.addCleanup(self.files.cleanup)
        self.media = override_settings(MEDIA_ROOT=self.files.name)
        self.media.enable()
        self.addCleanup(self.media.disable)
        owner = get_user_model().objects.create_user("retention@example.test")
        program = Program.objects.create(owner=owner, program_number="PRG-RET-0001")
        self.attachment = Attachment.objects.create(
            program=program,
            uploaded_by=owner,
            file_name="expired.pdf",
            storage_key="attachments/expired.pdf",
            content_type="application/pdf",
            size_bytes=5,
            sha256="0" * 64,
            scan_status="clean",
        )
        Attachment.objects.filter(pk=self.attachment.pk).update(
            removed_at=timezone.now() - timedelta(days=31)
        )
        target = Path(self.files.name, self.attachment.storage_key)
        target.parent.mkdir(parents=True)
        target.write_bytes(b"bytes")

    def test_command_is_dry_run_by_default_and_deletes_when_confirmed(self):
        call_command("purge_attachments")
        self.assertTrue(Attachment.objects.filter(pk=self.attachment.pk).exists())
        call_command("purge_attachments", confirm=True)
        self.assertFalse(Attachment.objects.filter(pk=self.attachment.pk).exists())
        self.assertFalse(
            Path(self.files.name, self.attachment.storage_key).exists()
        )


class PdfRetentionTests(TestCase):
    def setUp(self):
        self.files = tempfile.TemporaryDirectory()
        self.addCleanup(self.files.cleanup)
        self.media = override_settings(MEDIA_ROOT=self.files.name)
        self.media.enable()
        self.addCleanup(self.media.disable)

    def test_only_expired_pdf_spool_files_are_deleted_after_confirmation(self):
        spool = Path(self.files.name, "pdf-spool")
        spool.mkdir()
        expired = spool / "expired.pdf"
        recent = spool / "recent.pdf"
        expired.write_bytes(b"expired")
        recent.write_bytes(b"recent")
        old = (timezone.now() - timedelta(hours=25)).timestamp()
        os.utime(expired, (old, old))

        call_command("purge_pdf_spool")
        self.assertTrue(expired.exists())
        call_command("purge_pdf_spool", confirm=True)
        self.assertFalse(expired.exists())
        self.assertTrue(recent.exists())
