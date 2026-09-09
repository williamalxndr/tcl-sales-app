import hashlib
import io
from xml.sax.saxutils import escape

from django.db import transaction
from django.http import FileResponse
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import Image, KeepTogether, Paragraph, SimpleDocTemplate, Spacer

from apps.core.services import DomainError, audit

from .selectors import check_query, get_program
from .services import detail
from .uploads import private_path
from .views import AuthenticatedView


def render_pdf(program, user):
    data = detail(program, user)
    output = io.BytesIO()
    doc = SimpleDocTemplate(
        output,
        pagesize=(210 * mm, 297 * mm),
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=20 * mm,
        bottomMargin=20 * mm,
    )
    styles = getSampleStyleSheet()
    story = []

    def text(value, style="BodyText"):
        return Paragraph(escape(str(value or "—")), styles[style])

    story += [
        text("PT TOTAL CHEMINDO LOKA", "Title"),
        text("FORMULIR PENGAJUAN PROGRAM", "Heading2"),
        text(data["programNumber"]),
        Spacer(1, 8 * mm),
    ]
    fields = [
        ("Status", data["status"]),
        ("Nama Program", data["programName"]),
        ("Jenis Program", data["programType"]["name"] if data["programType"] else None),
        ("Lokasi", ", ".join(l["name"] for l in data["locations"])),
        ("Periode", f"{data['periodStart'] or '—'} — {data['periodEnd'] or '—'}"),
        (
            "Estimasi Biaya",
            (
                "Rp "
                + format(program.estimated_cost, ",.2f")
                .replace(",", "_")
                .replace(".", ",")
                .replace("_", ".")
            )
            if program.estimated_cost is not None
            else None,
        ),
        ("Tanggal Pengajuan", data["submittedAt"]),
    ]
    for label, value in fields:
        story.append(text(f"{label}: {value or '—'}"))
    story += [Spacer(1, 6 * mm), text("Lampiran", "Heading2")]
    for a in data["attachments"]:
        story.append(text(a["fileName"]))
    if not data["attachments"]:
        story.append(text("Tidak ada lampiran"))
    story += [
        Spacer(1, 6 * mm),
        text("Tanda tangan dan riwayat persetujuan", "Heading2"),
    ]
    signers = [
        (
            "Diajukan oleh",
            data["owner"],
            program.proposer_signature,
            data["submittedAt"],
            None,
        )
    ]
    for task in sorted(
        program.review_tasks.select_related("signature"),
        key=lambda t: (
            {"checker": 0, "acknowledgement": 1, "approval": 2}[t.stage],
            t.position,
        ),
    ):
        signers.append(
            (
                task.get_stage_display() + " — " + task.status,
                task.reviewer_snapshot,
                task.signature,
                task.decided_at,
                task.note,
            )
        )
    for label, who, signature, when, note in signers:
        block = [
            text(label, "Heading3"),
            text(who["fullName"]),
            text(who.get("jobTitle")),
        ]
        if signature:
            path = private_path(signature.storage_key)
            if (
                not path.is_file()
                or hashlib.sha256(path.read_bytes()).hexdigest() != signature.sha256
            ):
                raise DomainError(
                    "SERVICE_UNAVAILABLE",
                    "Signature storage is temporarily unavailable.",
                    503,
                )
            image = Image(str(path))
            image._restrictSize(45 * mm, 20 * mm)
            block.append(image)
        block.append(text(str(when) if when else "Belum ditandatangani"))
        if note:
            block.append(text("Catatan: " + note))
        block.append(Spacer(1, 4 * mm))
        story.append(KeepTogether(block))
    doc.build(story)
    output.seek(0)
    return output


class PdfView(AuthenticatedView):
    scope = "own"

    def get(self, request, submissionId):
        check_query(request, [])
        with transaction.atomic():
            program = get_program(request.user, submissionId, self.scope, lock=True)
            output = render_pdf(program, request.user)
            audit(request, "pdfDownloaded", program.pk, version=program.version)
        return FileResponse(
            output,
            as_attachment=True,
            filename=program.program_number + ".pdf",
            content_type="application/pdf",
        )


class BackofficePdfView(PdfView):
    scope = "visible"
