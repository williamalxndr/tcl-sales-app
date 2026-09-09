import hashlib
import io
import socket
import struct
import zipfile
from pathlib import Path
from uuid import uuid4

from django.conf import settings
from django.db import transaction
from django.http import FileResponse
from django.utils import timezone
from rest_framework.exceptions import NotFound
from rest_framework.parsers import MultiPartParser

from apps.core.api import success
from apps.core.services import DomainError, audit, idempotent, version_match

from .models import Attachment, Program
from .selectors import check_query, get_program
from .services import attachment_data, draft_only
from .views import AuthenticatedView

MAX_BYTES = 10_000_000
ALLOWED_EXTENSIONS = {
    ".pdf": "application/pdf",
    ".xls": "application/vnd.ms-excel",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".xlsm": "application/vnd.ms-excel.sheet.macroEnabled.12",
    ".xlsb": "application/vnd.ms-excel.sheet.binary.macroEnabled.12",
    ".xlt": "application/vnd.ms-excel",
    ".xltx": "application/vnd.openxmlformats-officedocument.spreadsheetml.template",
    ".xltm": "application/vnd.ms-excel.template.macroEnabled.12",
    ".xla": "application/vnd.ms-excel",
    ".xlam": "application/vnd.ms-excel.addin.macroEnabled.12",
    ".xlw": "application/vnd.ms-excel",
    ".xlm": "application/vnd.ms-excel",
}
OLE = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"


def encrypted_legacy_excel(content):
    """Inspect the workbook stream without evaluating formulas or macros."""
    import olefile

    with olefile.OleFileIO(
        io.BytesIO(content), raise_defects=olefile.DEFECT_INCORRECT
    ) as document:
        if document.exists("EncryptedPackage"):
            return True
        name = next((n for n in ["Workbook", "Book"] if document.exists(n)), None)
        if name is None or document.get_size(name) > MAX_BYTES:
            raise ValueError("No bounded Excel workbook stream.")
        workbook = document.openstream(name).read()
        offset = 0
        while offset + 4 <= len(workbook):
            record, size = struct.unpack_from("<HH", workbook, offset)
            if record == 0x002F:  # FILEPASS: encrypted workbook (MS-XLS).
                return True
            offset += 4 + size
            if offset > len(workbook):
                raise ValueError("Invalid workbook record.")
        if offset != len(workbook):
            raise ValueError("Truncated workbook record.")
    return False


def private_path(key):
    root = Path(settings.MEDIA_ROOT).resolve()
    candidate = (root / key).resolve()
    if not candidate.is_relative_to(root):
        raise DomainError("NOT_FOUND", "File not found.", 404)
    return candidate


def validate_file(content, extension):
    if extension not in ALLOWED_EXTENSIONS:
        raise DomainError(
            "UNSUPPORTED_MEDIA_TYPE", "Upload a supported PDF or Excel document.", 415
        )
    if not content or len(content) > MAX_BYTES:
        raise DomainError(
            "PAYLOAD_TOO_LARGE", "File must contain 1 to 10,000,000 bytes.", 413
        )
    if extension == ".pdf":
        if not content.lstrip().startswith(b"%PDF-"):
            raise DomainError(
                "UNSUPPORTED_MEDIA_TYPE", "The file content does not match PDF.", 415
            )
    elif extension in [".xlsx", ".xlsm", ".xlsb", ".xltx", ".xltm", ".xlam"]:
        # Encrypted Office containers remain quarantined for an explicit policy.
        if content.startswith(OLE):
            return
        try:
            with zipfile.ZipFile(io.BytesIO(content)) as archive:
                entries = archive.infolist()
                if (
                    len(entries) > 10000
                    or sum(f.file_size for f in entries) > 100_000_000
                ):
                    raise DomainError(
                        "PAYLOAD_TOO_LARGE",
                        "Expanded workbook exceeds the processing limit.",
                        413,
                    )
                names = set(archive.namelist())
                workbook = (
                    "xl/workbook.bin" if extension == ".xlsb" else "xl/workbook.xml"
                )
                if "[Content_Types].xml" not in names or workbook not in names:
                    raise ValueError()
        except (zipfile.BadZipFile, ValueError):
            raise DomainError(
                "UNSUPPORTED_MEDIA_TYPE",
                "The file is not an Excel workbook container.",
                415,
            )
    elif not content.startswith(OLE):
        raise DomainError(
            "UNSUPPORTED_MEDIA_TYPE",
            "The file content does not match legacy Excel.",
            415,
        )


def clamav_scan(content):
    with socket.create_connection(
        (settings.CLAMAV_HOST, settings.CLAMAV_PORT), timeout=10
    ) as client:
        client.settimeout(60)
        client.sendall(b"zINSTREAM\0")
        for i in range(0, len(content), 65536):
            chunk = content[i : i + 65536]
            client.sendall(struct.pack("!I", len(chunk)) + chunk)
        client.sendall(struct.pack("!I", 0))
        response = b""
        while b"\0" not in response and len(response) < 8192:
            part = client.recv(1024)
            if not part:
                break
            response += part
    result = response.decode("utf-8", "replace").strip("\0\n ")
    if result.endswith(" FOUND"):
        return False
    if result.endswith(": OK"):
        return True
    raise OSError("Scanner did not return a definitive verdict.")


def scan_attachment(attachment_id):
    item = Attachment.objects.filter(
        pk=attachment_id, removed_at__isnull=True, scan_status="pending"
    ).first()
    if not item:
        return False
    content = private_path(item.storage_key).read_bytes()
    extension = Path(item.file_name).suffix.lower()
    reason = ""
    # Password-protected containers never bypass inspection or silently release.
    if extension in [
        ".xlsx",
        ".xlsm",
        ".xlsb",
        ".xltx",
        ".xltm",
        ".xlam",
    ] and content.startswith(OLE):
        return False
    if extension == ".pdf":
        from pypdf import PdfReader

        try:
            if PdfReader(io.BytesIO(content)).is_encrypted:
                return False
        except Exception:
            reason = "INVALID_PDF"
    elif content.startswith(OLE):
        try:
            if encrypted_legacy_excel(content):
                return False
        except (OSError, ValueError, struct.error):
            reason = "INVALID_EXCEL"
    if hashlib.sha256(content).hexdigest() != item.sha256:
        reason = "CHECKSUM_MISMATCH"
    clean = False if reason else clamav_scan(content)
    with transaction.atomic():
        program = Program.objects.select_for_update().get(pk=item.program_id)
        item = Attachment.objects.select_for_update().get(pk=item.pk)
        if item.removed_at or item.scan_status != "pending":
            return False
        item.scan_status = "clean" if clean else "rejected"
        item.scan_reason = reason or ("" if clean else "MALWARE_DETECTED")
        item.scanned_at = timezone.now()
        item.save()
        program.version += 1
        program.save()
        from apps.core.models import AuditLog

        AuditLog.objects.create(
            event="attachmentScanned",
            resource_id=item.pk,
            request_id="system_scanner",
            details={
                "scanStatus": item.scan_status,
                "submissionVersion": program.version,
            },
        )
    return True


class UploadView(AuthenticatedView):
    parser_classes = [MultiPartParser]

    def post(self, request, submissionId):
        check_query(request, [])
        get_program(request.user, submissionId)
        if set(request.data) != {"file"} or len(request.FILES.getlist("file")) != 1:
            raise DomainError("BAD_REQUEST", "Provide exactly one file part.", 400)
        file = request.FILES["file"]
        name = Path(file.name.replace("\\", "/")).name
        if len(name) > 255 or any(ord(c) < 32 for c in name):
            raise DomainError("VALIDATION_FAILED", "Invalid filename.", 422)
        content = file.read(MAX_BYTES + 1)
        extension = Path(name).suffix.lower()
        validate_file(content, extension)
        sha = hashlib.sha256(content).hexdigest()
        written = []

        def change():
            program = get_program(request.user, submissionId, lock=True)
            version_match(request, program)
            draft_only(program)
            key = "attachments/" + uuid4().hex + extension
            path = private_path(key)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
            written.append(path)
            item = Attachment.objects.create(
                program=program,
                uploaded_by=request.user,
                file_name=name,
                storage_key=key,
                content_type=ALLOWED_EXTENSIONS[extension],
                size_bytes=len(content),
                sha256=sha,
            )
            program.version += 1
            program.save()
            audit(request, "attachmentUploaded", item.pk, submissionId=program.pk)
            response = success(
                request,
                {
                    "attachment": attachment_data(item),
                    "submissionVersion": program.version,
                },
                202,
            )
            response["ETag"] = f'"{program.version}"'
            response["Location"] = (
                f"/api/v1/program-submissions/{program.pk}/attachments/{item.pk}"
            )
            return response

        try:
            return idempotent(
                request,
                {
                    "fileName": name,
                    "sha256": sha,
                    "contentType": ALLOWED_EXTENSIONS[extension],
                },
                change,
            )
        except Exception:
            for path in written:
                path.unlink(missing_ok=True)
            raise


class AttachmentView(AuthenticatedView):
    def get(self, request, submissionId, attachmentId):
        check_query(request, [])
        program = get_program(request.user, submissionId)
        item = program.attachments.filter(
            pk=attachmentId, removed_at__isnull=True
        ).first()
        if not item:
            raise NotFound()
        return success(request, attachment_data(item))

    def delete(self, request, submissionId, attachmentId):
        check_query(request, [])
        if request.body:
            raise DomainError("BAD_REQUEST", "No request body is accepted.", 400)
        get_program(request.user, submissionId)

        def change():
            program = get_program(request.user, submissionId, lock=True)
            version_match(request, program)
            draft_only(program)
            item = program.attachments.filter(
                pk=attachmentId, removed_at__isnull=True
            ).first()
            if not item:
                raise NotFound()
            item.removed_at = timezone.now()
            item.save(update_fields=["removed_at"])
            program.version += 1
            program.save()
            audit(request, "attachmentRemoved", item.pk, submissionId=program.pk)
            response = success(
                request,
                {
                    "attachmentId": item.pk,
                    "removed": True,
                    "submissionVersion": program.version,
                },
            )
            response["ETag"] = f'"{program.version}"'
            return response

        return idempotent(request, {}, change)


class AttachmentContentView(AuthenticatedView):
    scope = "own"

    def get(self, request, submissionId, attachmentId):
        check_query(request, [])
        program = get_program(request.user, submissionId, self.scope)
        item = program.attachments.filter(
            pk=attachmentId, removed_at__isnull=True
        ).first()
        if not item:
            raise NotFound()
        if item.scan_status != "clean":
            raise DomainError(
                "ATTACHMENT_NOT_READY", "The attachment has not passed scanning."
            )
        path = private_path(item.storage_key)
        if not path.is_file():
            raise DomainError(
                "SERVICE_UNAVAILABLE", "File storage is temporarily unavailable.", 503
            )
        audit(request, "attachmentDownloaded", item.pk)
        response = FileResponse(
            path.open("rb"),
            as_attachment=True,
            filename=item.file_name,
            content_type=item.content_type,
        )
        response["X-Content-Type-Options"] = "nosniff"
        return response


class BackofficeAttachmentContentView(AttachmentContentView):
    scope = "visible"
