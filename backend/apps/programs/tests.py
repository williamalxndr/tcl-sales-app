import hashlib
import io
import tempfile
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from PIL import Image
from pypdf import PdfReader
from reportlab.pdfgen import canvas
from rest_framework.test import APIClient

from apps.accounts.models import AccountSignature, UserRole
from apps.core.models import AuditLog

from .models import (
    Attachment,
    Location,
    Program,
    ProgramType,
    ReviewerEligibility,
    ReviewTask,
    WorkflowPolicy,
)
from .uploads import scan_attachment


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class ProgramAPITests(TestCase):
    def setUp(self):
        self.files = tempfile.TemporaryDirectory()
        self.addCleanup(self.files.cleanup)
        self.media = override_settings(MEDIA_ROOT=self.files.name)
        self.media.enable()
        self.addCleanup(self.media.disable)
        self.policy = WorkflowPolicy.objects.create(
            within_stage_mode="sequential",
            rejection_ends_submission=True,
            require_signature=True,
            cancellation_states=[],
            require_type_and_cost=True,
        )
        self.owner = self.employee("owner", "submitter")
        self.checker = self.employee("checker", "checker")
        self.ack1 = self.employee("ack1", "acknowledger")
        self.ack2 = self.employee("ack2", "acknowledger")
        self.approver = self.employee("approver", "approver")
        self.outsider = self.employee("outsider", "submitter")
        self.owner.checker = self.checker
        self.owner.save()
        self.location = Location.objects.create(code="BSD", name="BSD")
        self.owner.locations.add(self.location)
        self.kind = ProgramType.objects.create(code="BUNDLING", name="Bundling")
        for reviewer, stage in [
            (self.ack1, "acknowledgement"),
            (self.ack2, "acknowledgement"),
            (self.approver, "approval"),
        ]:
            ReviewerEligibility.objects.create(
                employee=self.owner, reviewer=reviewer, stage=stage
            )
        self.client = self.client_for(self.owner)
        self.payload = {
            "programName": "September promotion",
            "programTypeId": self.kind.pk,
            "estimatedCost": {"currency": "IDR", "amount": "1500000.00"},
            "locationIds": [self.location.pk],
            "periodStart": "2026-09-15",
            "periodEnd": "2026-09-30",
            "acknowledgerIds": [self.ack1.pk, self.ack2.pk],
            "approverIds": [self.approver.pk],
        }

    def employee(self, name, role):
        user = get_user_model().objects.create_user(
            name + "@example.test",
            "test-password-for-tests",
            full_name=name,
            employee_number=name,
        )
        UserRole.objects.create(user=user, role=role)
        content = io.BytesIO()
        Image.new("RGB", (120, 30), "black").save(content, format="PNG")
        blob = content.getvalue()
        key = name + ".png"
        Path(self.files.name, key).write_bytes(blob)
        user.signature = AccountSignature.objects.create(
            user=user, storage_key=key, sha256=hashlib.sha256(blob).hexdigest()
        )
        user.save()
        return user

    def client_for(self, user):
        client = APIClient()
        response = client.post(
            "/api/v1/auth/login",
            {"email": user.email, "password": "test-password-for-tests"},
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.data)
        client.credentials(
            HTTP_AUTHORIZATION="Bearer " + response.data["data"]["accessToken"]
        )
        return client

    def headers(self, version=None, key=None):
        result = {"HTTP_IDEMPOTENCY_KEY": key or str(uuid4())}
        if version is not None:
            result["HTTP_IF_MATCH"] = f'"{version}"'
        return result

    def create(self, payload=None):
        response = self.client.post(
            "/api/v1/program-submissions",
            self.payload if payload is None else payload,
            format="json",
            **self.headers(),
        )
        self.assertEqual(response.status_code, 201, response.data)
        return response.data["data"]

    def submit(self, data):
        response = self.client.post(
            "/api/v1/program-submissions/" + data["id"] + "/submit",
            {},
            format="json",
            **self.headers(data["version"]),
        )
        self.assertEqual(response.status_code, 200, response.data)
        return response.data["data"]

    def decide(self, data, user, action="approve", expected=200, key=None):
        task = next(t for t in data["reviewTasks"] if t["reviewer"]["id"] == user.pk)
        response = self.client_for(user).post(
            "/api/v1/backoffice/program-submissions/"
            + data["id"]
            + "/review-tasks/"
            + task["id"]
            + "/"
            + action,
            {"note": "Reviewed by " + user.full_name},
            format="json",
            **self.headers(data["version"], key),
        )
        self.assertEqual(response.status_code, expected, response.data)
        return response.data.get("data", response.data)

    def test_sequential_workflow_and_history(self):
        data = self.submit(self.create())
        self.assertEqual(data["status"], "pendingChecker")
        self.assertEqual(
            [t["status"] for t in data["reviewTasks"]],
            ["ready", "waiting", "waiting", "waiting"],
        )
        self.decide(data, self.ack1, expected=404)
        data = self.decide(data, self.checker)
        self.assertEqual(data["status"], "pendingAcknowledgement")
        checker_client = self.client_for(self.checker)
        self.assertEqual(
            checker_client.get("/api/v1/backoffice/program-submissions").data["data"],
            [],
        )
        self.assertEqual(
            len(checker_client.get("/api/v1/backoffice/review-history").data["data"]), 1
        )
        self.assertEqual(
            checker_client.get(
                "/api/v1/backoffice/program-submissions/" + data["id"]
            ).status_code,
            200,
        )
        self.decide(data, self.ack2, expected=404)
        data = self.decide(data, self.ack1)
        self.assertEqual(data["status"], "pendingAcknowledgement")
        data = self.decide(data, self.ack2)
        self.assertEqual(data["status"], "pendingApproval")
        data = self.decide(data, self.approver)
        self.assertEqual(data["status"], "approved")
        self.assertIsNone(data["currentStage"])
        self.assertEqual([t["status"] for t in data["reviewTasks"]], ["approved"] * 4)
        self.assertEqual(
            Program.objects.get(pk=data["id"]).proposer_signature_id,
            self.owner.signature_id,
        )
        self.assertTrue(all(t.signature_id for t in ReviewTask.objects.all()))
        self.assertEqual(AuditLog.objects.filter(event="approved").count(), 4)
        self.decide(data, self.approver, expected=409)

    def test_rejection_is_terminal_and_history_preserves_notes(self):
        data = self.decide(self.submit(self.create()), self.checker, "reject")
        self.assertEqual(data["status"], "rejected")
        self.assertEqual(
            [t["status"] for t in data["reviewTasks"]],
            ["rejected", "voided", "voided", "voided"],
        )
        result = self.client.get("/api/v1/program-submissions/" + data["id"])
        self.assertEqual(
            result.data["data"]["reviewTasks"][0]["note"], "Reviewed by checker"
        )
        self.decide(data, self.checker, expected=409)
        self.assertEqual(AuditLog.objects.filter(event="rejected").count(), 1)

    def test_draft_idempotency_conflict_and_etag(self):
        key = str(uuid4())
        url = "/api/v1/program-submissions"
        first = self.client.post(
            url, self.payload, format="json", **self.headers(key=key)
        )
        replay = self.client.post(
            url, self.payload, format="json", **self.headers(key=key)
        )
        self.assertEqual(first.data["data"], replay.data["data"])
        self.assertEqual(Program.objects.count(), 1)
        self.assertEqual(
            self.client.post(
                url, {}, format="json", **self.headers(key=key)
            ).status_code,
            409,
        )
        detail_url = url + "/" + first.data["data"]["id"]
        self.assertEqual(
            self.client.patch(
                detail_url, {"programName": "Changed"}, format="json"
            ).status_code,
            428,
        )
        result = self.client.patch(
            detail_url, {"programName": "Changed"}, format="json", HTTP_IF_MATCH='"1"'
        )
        self.assertEqual(result.status_code, 200, result.data)
        self.assertEqual(result["ETag"], '"2"')
        self.assertEqual(
            self.client.patch(
                detail_url, {"programName": "Stale"}, format="json", HTTP_IF_MATCH='"1"'
            ).status_code,
            412,
        )
        self.assertEqual(
            self.client.patch(
                detail_url, {"status": "approved"}, format="json", HTTP_IF_MATCH='"2"'
            ).status_code,
            400,
        )

    def test_submit_retry_replays_original_success(self):
        data = self.create()
        url = "/api/v1/program-submissions/" + data["id"] + "/submit"
        headers = self.headers(data["version"])
        first = self.client.post(url, {}, format="json", **headers)
        replay = self.client.post(url, {}, format="json", **headers)
        self.assertEqual(first.status_code, 200, first.data)
        self.assertEqual(replay.data["data"], first.data["data"])
        self.assertEqual(ReviewTask.objects.count(), 4)
        self.assertEqual(
            self.client.patch(
                "/api/v1/program-submissions/" + data["id"],
                {"programName": "Changed"},
                format="json",
                HTTP_IF_MATCH='"2"',
            ).status_code,
            409,
        )

    def test_scopes_filters_and_server_owned_fields(self):
        data = self.create()
        outsider = self.client_for(self.outsider)
        self.assertEqual(
            outsider.get("/api/v1/program-submissions/" + data["id"]).status_code, 404
        )
        self.assertEqual(outsider.get("/api/v1/program-submissions").data["data"], [])
        self.assertEqual(
            self.client.get("/api/v1/backoffice/program-submissions").status_code, 403
        )
        self.assertEqual(
            self.client.get(
                "/api/v1/program-submissions?periodStartFrom=2026-10-01"
            ).data["data"],
            [],
        )
        self.assertEqual(
            self.client.get(
                "/api/v1/program-submissions?periodStartFrom=2026-09-01"
            ).data["meta"]["totalItems"],
            1,
        )
        for query in [
            "status=bogus",
            "pageSize=101",
            "sort=owner",
            "periodStartFrom=2026-10-01&periodStartTo=2026-09-01",
        ]:
            self.assertEqual(
                self.client.get("/api/v1/program-submissions?" + query).status_code, 422
            )
        self.assertEqual(
            self.client.get("/api/v1/program-submissions?unexpected=x").status_code, 400
        )
        self.assertEqual(
            self.client.post(
                "/api/v1/program-submissions",
                {"ownerId": self.outsider.pk},
                format="json",
                **self.headers(),
            ).status_code,
            400,
        )
        invalid = {**self.payload, "acknowledgerIds": [self.outsider.pk]}
        self.assertEqual(
            self.client.post(
                "/api/v1/program-submissions", invalid, format="json", **self.headers()
            ).status_code,
            422,
        )
        options = self.client.get(
            "/api/v1/program-submissions/"
            + data["id"]
            + "/reviewer-options?stage=acknowledgement"
        )
        self.assertEqual(options.data["meta"]["totalItems"], 2)

    def test_policy_and_signature_requirements_are_not_invented(self):
        self.policy.require_type_and_cost = None
        self.policy.save()
        draft = self.create({})
        response = self.client.post(
            "/api/v1/program-submissions/" + draft["id"] + "/submit",
            {},
            format="json",
            **self.headers(draft["version"]),
        )
        self.assertEqual(response.status_code, 409)
        data = self.create()
        self.owner.signature = None
        self.owner.save()
        response = self.client.post(
            "/api/v1/program-submissions/" + data["id"] + "/submit",
            {},
            format="json",
            **self.headers(data["version"]),
        )
        self.assertEqual(response.status_code, 422)
        self.assertIn("SIGNATURE_REQUIRED", str(response.data))

    def test_cancellation_is_enabled_for_in_progress_submissions_and_owner_only(self):
        self.policy.cancellation_states = [
            "draft",
            "pendingChecker",
            "pendingAcknowledgement",
            "pendingApproval",
        ]
        self.policy.save()
        data = self.submit(self.create())
        url = "/api/v1/program-submissions/" + data["id"] + "/cancel"
        self.assertEqual(
            self.client_for(self.outsider)
            .post(url, {"reason": "No"}, format="json", **self.headers(data["version"]))
            .status_code,
            404,
        )
        response = self.client.post(
            url,
            {"reason": "Execution changed"},
            format="json",
            **self.headers(data["version"]),
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["data"]["status"], "cancelled")
        self.assertFalse(ReviewTask.objects.exclude(status="voided").exists())
        self.assertEqual(
            self.client.post(
                url,
                {"reason": "Again"},
                format="json",
                **self.headers(response.data["data"]["version"]),
            ).status_code,
            409,
        )

    def test_ready_reviewer_can_delegate_to_same_role_with_audit(self):
        delegate = self.employee("delegate-checker", "checker")
        data = self.submit(self.create())
        task = ReviewTask.objects.get(program_id=data["id"], stage="checker")
        client = self.client_for(self.checker)
        response = client.post(
            f"/api/v1/backoffice/program-submissions/{data['id']}"
            f"/review-tasks/{task.pk}/delegate",
            {"reviewerId": delegate.pk},
            format="json",
            **self.headers(data["version"]),
        )
        self.assertEqual(response.status_code, 200, response.data)
        task.refresh_from_db()
        self.assertEqual(task.reviewer_id, delegate.pk)
        self.assertEqual(task.reviewer_snapshot["fullName"], delegate.full_name)
        log = AuditLog.objects.get(
            event="reviewTaskDelegated", resource_id=data["id"]
        )
        self.assertEqual(log.details["previousReviewerId"], self.checker.pk)
        self.assertEqual(log.details["reviewerId"], delegate.pk)

    def pdf_bytes(self):
        output = io.BytesIO()
        document = canvas.Canvas(output)
        document.drawString(30, 700, "Sales attachment")
        document.save()
        return output.getvalue()

    def upload(self, data, content=None, name="budget.pdf", headers=None):
        return self.client.post(
            "/api/v1/program-submissions/" + data["id"] + "/attachments",
            {
                "file": SimpleUploadedFile(
                    name, self.pdf_bytes() if content is None else content
                )
            },
            format="multipart",
            **(headers or self.headers(data["version"])),
        )

    def test_upload_scan_download_remove_and_isolation(self):
        data = self.create()
        body = self.pdf_bytes()
        headers = self.headers(data["version"])
        upload = self.upload(data, body, headers=headers)
        self.assertEqual(upload.status_code, 202, upload.data)
        replay = self.upload(data, body, headers=headers)
        self.assertEqual(upload.data["data"], replay.data["data"])
        self.assertEqual(Attachment.objects.count(), 1)
        attachment = upload.data["data"]["attachment"]
        url = (
            "/api/v1/program-submissions/"
            + data["id"]
            + "/attachments/"
            + attachment["id"]
        )
        self.assertEqual(self.client.get(url + "/content").status_code, 409)
        current = self.client.get("/api/v1/program-submissions/" + data["id"]).data[
            "data"
        ]
        blocked = self.client.post(
            "/api/v1/program-submissions/" + data["id"] + "/submit",
            {},
            format="json",
            **self.headers(current["version"]),
        )
        self.assertEqual(blocked.status_code, 422, blocked.data)
        with patch(
            "apps.programs.uploads.clamav_scan", side_effect=OSError("unavailable")
        ):
            with self.assertRaises(OSError):
                scan_attachment(attachment["id"])
        self.assertEqual(
            Attachment.objects.get(pk=attachment["id"]).scan_status, "pending"
        )
        with patch("apps.programs.uploads.clamav_scan", return_value=True):
            self.assertTrue(scan_attachment(attachment["id"]))
        download = self.client.get(url + "/content")
        self.assertEqual(download.status_code, 200)
        self.assertEqual(b"".join(download.streaming_content), body)
        self.assertEqual(
            self.client_for(self.outsider).get(url + "/content").status_code, 404
        )
        current = self.client.get("/api/v1/program-submissions/" + data["id"]).data[
            "data"
        ]
        remove_headers = self.headers(current["version"])
        self.assertEqual(self.client.delete(url, **remove_headers).status_code, 200)
        self.assertEqual(self.client.delete(url, **remove_headers).status_code, 200)
        self.assertEqual(self.client.get(url + "/content").status_code, 404)

    def test_invalid_uploads_and_malware_never_release(self):
        data = self.create()
        self.assertEqual(self.upload(data, b"fake", "fake.pdf").status_code, 415)
        self.assertEqual(self.upload(data, b"fake", "fake.exe").status_code, 415)
        self.assertEqual(
            self.upload(data, b"%PDF-" + b"x" * 10_000_000).status_code, 413
        )
        uploaded = self.upload(data)
        self.assertEqual(uploaded.status_code, 202, uploaded.data)
        aid = uploaded.data["data"]["attachment"]["id"]
        with patch("apps.programs.uploads.clamav_scan", return_value=False):
            scan_attachment(aid)
        self.assertEqual(Attachment.objects.get(pk=aid).scan_status, "rejected")
        self.assertEqual(
            self.client.get(
                "/api/v1/program-submissions/"
                + data["id"]
                + "/attachments/"
                + aid
                + "/content"
            ).status_code,
            409,
        )

    def test_pdf_is_private_and_uses_frozen_signature(self):
        data = self.decide(self.submit(self.create()), self.checker, "reject")
        old_signature = self.owner.signature_id
        self.owner.signature = None
        self.owner.save()
        url = "/api/v1/program-submissions/" + data["id"] + "/pdf"
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        blob = b"".join(response.streaming_content)
        self.assertTrue(blob.startswith(b"%PDF-"))
        text = "\n".join(
            page.extract_text() for page in PdfReader(io.BytesIO(blob)).pages
        )
        self.assertIn("rejected", text)
        self.assertIn("Reviewed by checker", text)
        self.assertEqual(
            Program.objects.get(pk=data["id"]).proposer_signature_id, old_signature
        )
        self.assertEqual(self.client_for(self.outsider).get(url).status_code, 404)

    def test_provisioning_creates_explicit_relations_and_private_signature(self):
        from django.core.management import call_command
        from django.core.management.base import CommandError

        output = io.StringIO()
        args = [
            "--email",
            "provisioned@example.test",
            "--name",
            "Provisioned Employee",
            "--employee-number",
            "NEW001",
            "--roles",
            "submitter",
            "--checker-email",
            self.checker.email,
            "--locations",
            "BSD",
            "--acknowledgers",
            self.ack1.email,
            "--approvers",
            self.approver.email,
            "--signature",
            str(Path(self.files.name, "owner.png")),
        ]
        with patch.dict(
            "os.environ", {"SALES_EMPLOYEE_PASSWORD": "test-password-for-tests"}
        ):
            call_command("provision_employee", *args, stdout=output)
            with self.assertRaises(CommandError):
                call_command("provision_employee", *args, stdout=output)
        employee = get_user_model().objects.get(email="provisioned@example.test")
        self.assertEqual(employee.checker_id, self.checker.pk)
        self.assertEqual(employee.locations.get().pk, self.location.pk)
        self.assertEqual(employee.signature.user_id, employee.pk)
        self.assertEqual(employee.reviewer_eligibilities.count(), 2)
        self.assertEqual(
            self.client_for(employee).get("/api/v1/users/me").status_code, 200
        )
        self.assertNotIn("test-password-for-tests", output.getvalue())

    def test_proposer_cannot_reject_even_with_a_ready_reviewer_task(self):
        UserRole.objects.create(user=self.owner, role="checker")
        self.owner.checker = self.owner
        self.owner.save()
        self.policy.allow_self_approval = True
        self.policy.save()
        data = self.submit(self.create())
        self.decide(data, self.owner, "reject", expected=403)
        self.assertEqual(Program.objects.get(pk=data["id"]).status, "pendingChecker")

    def test_money_rejects_floating_point_json_and_wrong_currency(self):
        for money in [
            {"currency": "IDR", "amount": 1.23},
            {"currency": "USD", "amount": "1.23"},
            {"currency": "IDR", "amount": "-1.00"},
        ]:
            response = self.client.post(
                "/api/v1/program-submissions",
                {**self.payload, "estimatedCost": money},
                format="json",
                **self.headers(),
            )
            self.assertEqual(response.status_code, 422, response.data)
        self.assertFalse(Program.objects.exists())

    def test_encrypted_pdf_stays_quarantined_and_excel_container_scans(self):
        import zipfile

        from pypdf import PdfWriter

        data = self.create()
        writer = PdfWriter()
        writer.add_blank_page(width=100, height=100)
        writer.encrypt("test-file-password")
        output = io.BytesIO()
        writer.write(output)
        upload = self.upload(data, output.getvalue())
        self.assertEqual(upload.status_code, 202, upload.data)
        aid = upload.data["data"]["attachment"]["id"]
        with patch("apps.programs.uploads.clamav_scan") as scanner:
            self.assertFalse(scan_attachment(aid))
            scanner.assert_not_called()
        self.assertEqual(Attachment.objects.get(pk=aid).scan_status, "pending")
        workbook = io.BytesIO()
        with zipfile.ZipFile(workbook, "w") as archive:
            archive.writestr(
                "[Content_Types].xml",
                '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
            )
            archive.writestr(
                "xl/workbook.xml",
                '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"/>',
            )
        data = self.client.get("/api/v1/program-submissions/" + data["id"]).data["data"]
        uploaded = self.upload(data, workbook.getvalue(), "budget.xlsm")
        self.assertEqual(uploaded.status_code, 202, uploaded.data)
        aid = uploaded.data["data"]["attachment"]["id"]
        with patch("apps.programs.uploads.clamav_scan", return_value=True):
            self.assertTrue(scan_attachment(aid))
        self.assertEqual(Attachment.objects.get(pk=aid).scan_status, "clean")

    def test_missing_or_corrupt_historical_signature_fails_closed(self):
        data = self.submit(self.create())
        Path(self.files.name, self.owner.signature.storage_key).write_bytes(
            b"corrupt image"
        )
        response = self.client.get("/api/v1/program-submissions/" + data["id"] + "/pdf")
        self.assertEqual(response.status_code, 503, response.data)
        self.assertEqual(response.data["error"]["code"], "SERVICE_UNAVAILABLE")


from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

from django.db import close_old_connections
from django.test import TransactionTestCase


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class ConcurrentWorkflowTests(TransactionTestCase):
    setUp = ProgramAPITests.setUp
    employee = ProgramAPITests.employee
    client_for = ProgramAPITests.client_for
    headers = ProgramAPITests.headers
    create = ProgramAPITests.create
    submit = ProgramAPITests.submit

    def race(self, calls):
        barrier = Barrier(len(calls))

        def run(call):
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                return call()
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=len(calls)) as pool:
            return list(pool.map(run, calls))

    def test_concurrent_duplicate_creates_share_one_result(self):
        clients = [self.client_for(self.owner), self.client_for(self.owner)]
        headers = self.headers()

        def call(client):
            return lambda: client.post(
                "/api/v1/program-submissions", self.payload, format="json", **headers
            )

        responses = self.race([call(c) for c in clients])
        self.assertEqual(
            [r.status_code for r in responses], [201, 201], [r.data for r in responses]
        )
        self.assertEqual(
            responses[0].data["data"]["id"], responses[1].data["data"]["id"]
        )
        self.assertEqual(Program.objects.count(), 1)

    def test_concurrent_approve_and_reject_cannot_both_commit(self):
        data = self.submit(self.create())
        task = next(t for t in data["reviewTasks"] if t["stage"] == "checker")
        clients = [self.client_for(self.checker), self.client_for(self.checker)]

        def call(client, action):
            return lambda: client.post(
                "/api/v1/backoffice/program-submissions/"
                + data["id"]
                + "/review-tasks/"
                + task["id"]
                + "/"
                + action,
                {},
                format="json",
                **self.headers(data["version"]),
            )

        responses = self.race([call(clients[0], "approve"), call(clients[1], "reject")])
        self.assertEqual(
            sorted(r.status_code for r in responses),
            [200, 412],
            [r.data for r in responses],
        )
        self.assertEqual(
            Program.objects.get(pk=data["id"]).version, data["version"] + 1
        )
        self.assertEqual(
            AuditLog.objects.filter(event__in=["approved", "rejected"]).count(), 1
        )
