from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
import io
from tempfile import TemporaryDirectory

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image


class UserTests(TestCase):
    def test_identity_normalization_and_password_hashing(self):
        user = get_user_model().objects.create_user(
            " Rizky@EXAMPLE.com ",
            "a-test-password-for-this-suite",
            employee_number=" B001 ",
        )
        user.refresh_from_db()
        self.assertEqual(user.email, "rizky@example.com")
        self.assertEqual(user.employee_number, "B001")
        self.assertTrue(user.id.startswith("usr_"))
        self.assertTrue(user.check_password("a-test-password-for-this-suite"))
        self.assertTrue(user.password.startswith("argon2$"))

    def test_mysql_rejects_duplicate_employee_identity(self):
        users = get_user_model().objects
        users.create_user("first@example.com", employee_number="B001")
        with self.assertRaises(IntegrityError), transaction.atomic():
            users.create_user("second@example.com", employee_number="B001")

    def test_unprovisioned_accounts_do_not_collide_on_empty_employee_number(self):
        users = get_user_model().objects
        first = users.create_user("first@example.com", employee_number="")
        second = users.create_user("second@example.com")
        self.assertIsNone(first.employee_number)
        self.assertIsNone(second.employee_number)
        self.assertFalse(first.has_usable_password())


from django.test import override_settings
from rest_framework.test import APIClient

from apps.core.models import AuditLog
from apps.programs.models import Location

from .models import AccountSignature, AuthSession, UserRole


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class AuthenticationAPITests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            "employee@example.test",
            "a-strong-test-password",
            full_name="Employee",
            employee_number="EMP001",
        )
        self.client = APIClient()
        self.credentials = {
            "email": self.user.email,
            "password": "a-strong-test-password",
        }

    def login(self):
        response = self.client.post(
            "/api/v1/auth/login", self.credentials, format="json"
        )
        self.assertEqual(response.status_code, 200, response.data)
        return response.data["data"]

    def test_native_login_refresh_rotation_reuse_and_logout(self):
        session = self.login()
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + session["accessToken"])
        self.assertEqual(self.client.get("/api/v1/users/me").status_code, 200)
        refreshed = self.client.post(
            "/api/v1/auth/refresh",
            {"refreshToken": session["refreshToken"]},
            format="json",
        )
        self.assertEqual(refreshed.status_code, 200, refreshed.data)
        self.assertEqual(self.client.get("/api/v1/users/me").status_code, 401)
        current = refreshed.data["data"]
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + current["accessToken"])
        self.assertEqual(self.client.get("/api/v1/users/me").status_code, 200)
        reused = self.client.post(
            "/api/v1/auth/refresh",
            {"refreshToken": session["refreshToken"]},
            format="json",
        )
        self.assertEqual(reused.status_code, 401, reused.data)
        self.assertIsNotNone(
            AuthSession.objects.get(pk=session["sessionId"]).revoked_at
        )
        self.assertEqual(self.client.get("/api/v1/users/me").status_code, 401)
        fresh = self.login()
        self.client.credentials(HTTP_AUTHORIZATION="Bearer " + fresh["accessToken"])
        self.assertEqual(
            self.client.post(
                "/api/v1/auth/logout",
                {"refreshToken": fresh["refreshToken"]},
                format="json",
            ).status_code,
            200,
        )
        self.assertEqual(self.client.get("/api/v1/users/me").status_code, 401)

    def test_invalid_credentials_are_uniform_and_inputs_strict(self):
        for body in [
            {**self.credentials, "password": "wrong-password"},
            {**self.credentials, "email": "missing@example.test"},
        ]:
            response = self.client.post("/api/v1/auth/login", body, format="json")
            self.assertEqual(response.status_code, 401, response.data)
            self.assertEqual(response.data["error"]["code"], "UNAUTHENTICATED")
        self.user.is_active = False
        self.user.save()
        self.assertEqual(
            self.client.post(
                "/api/v1/auth/login", self.credentials, format="json"
            ).status_code,
            401,
        )
        self.assertEqual(
            self.client.post(
                "/api/v1/auth/login",
                {**self.credentials, "roles": ["approver"]},
                format="json",
            ).status_code,
            400,
        )
        self.assertEqual(
            self.client.get("/api/v1/program-submissions").status_code, 401
        )

    def test_login_rate_limit_persists_failed_attempts(self):
        for _ in range(10):
            response = self.client.post(
                "/api/v1/auth/login",
                {**self.credentials, "password": "wrong"},
                format="json",
            )
            self.assertEqual(response.status_code, 401)
        response = self.client.post(
            "/api/v1/auth/login", self.credentials, format="json"
        )
        self.assertEqual(response.status_code, 429, response.data)
        self.assertIn("Retry-After", response)

    @override_settings(CSRF_TRUSTED_ORIGINS=["http://localhost:3000"])
    def test_web_cookie_transport_requires_csrf_and_hides_refresh_token(self):
        client = APIClient(enforce_csrf_checks=True)
        origin = {"HTTP_ORIGIN": "http://localhost:3000"}
        body = {**self.credentials, "clientType": "web"}
        self.assertEqual(
            client.post(
                "/api/v1/auth/login", body, format="json", **origin
            ).status_code,
            403,
        )
        bootstrap = client.get("/api/v1/auth/csrf", **origin)
        csrf = bootstrap.data["data"]["csrfToken"]
        login = client.post(
            "/api/v1/auth/login", body, format="json", HTTP_X_CSRFTOKEN=csrf, **origin
        )
        self.assertEqual(login.status_code, 200, login.data)
        self.assertNotIn("refreshToken", login.data["data"])
        self.assertTrue(login.cookies["sales_refresh"]["httponly"])
        self.assertEqual(client.get("/api/v1/users/me").status_code, 401)
        self.assertEqual(
            client.post(
                "/api/v1/auth/refresh", {}, format="json", **origin
            ).status_code,
            403,
        )
        rotated_csrf = login.data["data"]["csrfToken"]
        refresh = client.post(
            "/api/v1/auth/refresh",
            {},
            format="json",
            HTTP_X_CSRFTOKEN=rotated_csrf,
            **origin,
        )
        self.assertEqual(refresh.status_code, 200, refresh.data)
        self.assertNotIn("refreshToken", refresh.data["data"])
        self.assertEqual(
            client.post(
                "/api/v1/auth/logout",
                {},
                format="json",
                HTTP_X_CSRFTOKEN=rotated_csrf,
                **origin,
            ).status_code,
            200,
        )
        self.assertEqual(client.cookies["sales_refresh"].value, "")


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class SuperadminEmployeeAPITests(TestCase):
    def setUp(self):
        self.admin = get_user_model().objects.create_superuser(
            "admin@example.test", "a-strong-admin-password"
        )
        self.client = APIClient()
        self.client.force_authenticate(self.admin)
        self.media = TemporaryDirectory()
        media_settings = self.settings(MEDIA_ROOT=self.media.name)
        media_settings.enable()
        self.addCleanup(media_settings.disable)
        self.addCleanup(self.media.cleanup)

    def test_superadmin_creates_an_employee_account(self):
        response = self.client.post(
            "/api/v1/admin/employees",
            {
                "email": "new.employee@example.test",
                "fullName": "New Employee",
                "employeeNumber": "EMP-200",
                "jobTitle": "Sales Executive",
                "timeZone": "Asia/Jakarta",
                "initialPassword": "a-strong-initial-password",
            },
            format="json",
            HTTP_IDEMPOTENCY_KEY="create-employee-0001",
        )
        self.assertEqual(response.status_code, 201, response.data)
        employee = get_user_model().objects.get(email="new.employee@example.test")
        self.assertTrue(employee.check_password("a-strong-initial-password"))
        self.assertNotIn("initialPassword", response.data["data"])
        self.assertTrue(
            AuditLog.objects.filter(
                event="employeeCreated", resource_id=employee.pk
            ).exists()
        )

    def test_regular_employee_cannot_create_accounts(self):
        employee = get_user_model().objects.create_user("ordinary@example.test")
        self.client.force_authenticate(employee)
        response = self.client.post(
            "/api/v1/admin/employees",
            {
                "email": "blocked@example.test",
                "fullName": "Blocked",
                "employeeNumber": "EMP-201",
                "initialPassword": "a-strong-initial-password",
            },
            format="json",
            HTTP_IDEMPOTENCY_KEY="create-employee-0002",
        )
        self.assertEqual(response.status_code, 403)

    def test_superadmin_updates_employee_profile_without_role_fields(self):
        employee = get_user_model().objects.create_user(
            "old@example.test", employee_number="EMP-300", full_name="Old Name"
        )
        response = self.client.patch(
            "/api/v1/admin/employees/" + employee.pk,
            {
                "email": "updated@example.test",
                "fullName": "Updated Name",
                "jobTitle": "Area Manager",
                "isActive": False,
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.data)
        employee.refresh_from_db()
        self.assertEqual(employee.full_name, "Updated Name")
        self.assertEqual(employee.job_title, "Area Manager")
        self.assertFalse(employee.is_active)
        self.assertTrue(
            AuditLog.objects.filter(
                event="employeeProfileUpdated", resource_id=employee.pk
            ).exists()
        )

        forbidden = self.client.patch(
            "/api/v1/admin/employees/" + employee.pk,
            {"roles": ["approver"]},
            format="json",
        )
        self.assertEqual(forbidden.status_code, 400)

    def test_superadmin_replaces_role_and_location_grants(self):
        employee = get_user_model().objects.create_user("grants@example.test")
        old = Location.objects.create(code="OLD", name="Old")
        current = Location.objects.create(code="CURRENT", name="Current")
        employee.locations.add(old)
        UserRole.objects.create(user=employee, role="submitter")

        response = self.client.put(
            f"/api/v1/admin/employees/{employee.pk}/access",
            {"roles": ["checker", "approver"], "locationIds": [current.pk]},
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data["data"]["roles"], ["approver", "checker"])
        self.assertEqual(response.data["data"]["locationIds"], [current.pk])
        self.assertEqual(
            set(employee.role_grants.values_list("role", flat=True)),
            {"checker", "approver"},
        )
        self.assertTrue(
            AuditLog.objects.filter(
                event="employeeAccessUpdated", resource_id=employee.pk
            ).exists()
        )

    def test_superadmin_adds_an_immutable_signature_version(self):
        employee = get_user_model().objects.create_user("signer@example.test")
        old = AccountSignature.objects.create(
            user=employee,
            storage_key="signatures/historical.png",
            sha256="0" * 64,
        )
        employee.signature = old
        employee.save()
        stream = io.BytesIO()
        Image.new("RGB", (120, 40), "white").save(stream, format="JPEG")

        response = self.client.post(
            f"/api/v1/admin/employees/{employee.pk}/signatures",
            {
                "file": SimpleUploadedFile(
                    "signature.jpg", stream.getvalue(), content_type="image/jpeg"
                )
            },
            format="multipart",
            HTTP_IDEMPOTENCY_KEY="replace-signature-0001",
        )
        self.assertEqual(response.status_code, 201, response.data)
        employee.refresh_from_db()
        self.assertNotEqual(employee.signature_id, old.pk)
        self.assertTrue(AccountSignature.objects.filter(pk=old.pk).exists())
        self.assertEqual(AccountSignature.objects.filter(user=employee).count(), 2)
        self.assertTrue(
            AuditLog.objects.filter(
                event="employeeSignatureReplaced", resource_id=employee.pk
            ).exists()
        )

    def test_superadmin_replaces_employee_checker_with_audit(self):
        employee = get_user_model().objects.create_user("routed@example.test")
        previous = get_user_model().objects.create_user("old.checker@example.test")
        replacement = get_user_model().objects.create_user("checker@example.test")
        UserRole.objects.create(user=previous, role="checker")
        UserRole.objects.create(user=replacement, role="checker")
        employee.checker = previous
        employee.save()

        response = self.client.put(
            f"/api/v1/admin/employees/{employee.pk}/checker",
            {"checkerId": replacement.pk},
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.data)
        employee.refresh_from_db()
        self.assertEqual(employee.checker_id, replacement.pk)
        log = AuditLog.objects.get(
            event="employeeCheckerUpdated", resource_id=employee.pk
        )
        self.assertEqual(log.details["previousCheckerId"], previous.pk)
        self.assertEqual(log.details["checkerId"], replacement.pk)
