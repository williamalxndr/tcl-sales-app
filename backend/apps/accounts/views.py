import hashlib
import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.middleware.csrf import CsrfViewMiddleware, get_token, rotate_token
from django.utils import timezone
from rest_framework.permissions import AllowAny
from rest_framework.parsers import MultiPartParser
from rest_framework.views import APIView

from apps.core.api import success
from apps.core.services import DomainError, audit, digest, idempotent, rate_limit

from .models import AuthSession, RefreshCredential
from .serializers import (
    EmployeeCreateSerializer,
    EmployeeCheckerSerializer,
    EmployeeAccessSerializer,
    EmployeeUpdateSerializer,
    LoginSerializer,
    RefreshSerializer,
    profile,
)


def iso(value):
    return value.isoformat().replace("+00:00", "Z")


def enforce_csrf(request):
    raw = request._request
    check = CsrfViewMiddleware(lambda r: None)
    check.process_request(raw)
    reason = check.process_view(raw, lambda r: None, (), {})
    if reason:
        raise DomainError(
            "CSRF_FAILED", "A valid CSRF token and trusted origin are required.", 403
        )


def issue_tokens(session):
    access, refresh = secrets.token_urlsafe(48), secrets.token_urlsafe(48)
    session.access_hash = digest(access)
    session.access_expires_at = timezone.now() + timedelta(minutes=15)
    session.save()
    RefreshCredential.objects.create(session=session, token_hash=digest(refresh))
    return access, refresh


def session_response(request, session, access, refresh):
    data = {
        "accessToken": access,
        "tokenType": "Bearer",
        "expiresIn": 900,
        "refreshExpiresAt": iso(session.refresh_expires_at),
        "sessionId": session.pk,
        "user": profile(session.user),
    }
    if session.client_type == "native":
        data["refreshToken"] = refresh
    else:
        data["csrfToken"] = get_token(request._request)
    response = success(request, data)
    if session.client_type == "web":
        response.set_cookie(
            settings.REFRESH_COOKIE_NAME,
            refresh,
            httponly=True,
            secure=not settings.DEBUG,
            samesite="Lax",
            path="/api/v1/auth",
            max_age=max(
                0, int((session.refresh_expires_at - timezone.now()).total_seconds())
            ),
        )
    return response


class PublicAuthView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get_authenticate_header(self, request):
        return "Bearer"

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        if request.query_params:
            raise DomainError("BAD_REQUEST", "Query parameters are not accepted.", 400)
        rate_limit("auth-ip:" + request.META.get("REMOTE_ADDR", ""), 60)


class CsrfView(PublicAuthView):
    def get(self, request):
        return success(request, {"csrfToken": get_token(request._request)})


class LoginView(PublicAuthView):
    def post(self, request):
        form = LoginSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        email = form.validated_data["email"].strip().lower()
        kind = form.validated_data["clientType"]
        if (
            kind == "web"
            or request.headers.get("Origin")
            or request.COOKIES.get(settings.REFRESH_COOKIE_NAME)
        ):
            enforce_csrf(request)
        rate_limit("login-email:" + email, 10)
        user = get_user_model().objects.filter(email=email).first()
        if user is None:
            # Match the password hashing work for unknown identities.
            get_user_model()().set_password(form.validated_data["password"])
        valid = (
            user is not None
            and user.check_password(form.validated_data["password"])
            and user.is_active
        )
        if not valid:
            audit(request, "loginFailed")
            from rest_framework.exceptions import AuthenticationFailed

            raise AuthenticationFailed("Invalid email or password.")
        with transaction.atomic():
            session = AuthSession(
                user=user,
                client_type=kind,
                refresh_expires_at=timezone.now() + timedelta(days=30),
            )
            access, refresh = issue_tokens(session)
            request.user = user
            audit(request, "login", session.pk)
        if kind == "web":
            rotate_token(request._request)
        return session_response(request, session, access, refresh)


def refresh_input(request):
    form = RefreshSerializer(data=request.data)
    form.is_valid(raise_exception=True)
    token = form.validated_data.get("refreshToken")
    cookie = request.COOKIES.get(settings.REFRESH_COOKIE_NAME)
    if cookie or request.headers.get("Origin"):
        enforce_csrf(request)
    if token and cookie:
        raise DomainError("BAD_REQUEST", "Use one refresh credential transport.", 400)
    if not token and not cookie:
        raise DomainError("UNAUTHENTICATED", "A refresh credential is required.", 401)
    return token or cookie, "web" if cookie else "native"


class RefreshView(PublicAuthView):
    def post(self, request):
        token, kind = refresh_input(request)
        credential = RefreshCredential.objects.filter(token_hash=digest(token)).first()
        invalid = True
        if credential:
            with transaction.atomic():
                session = (
                    AuthSession.objects.select_for_update()
                    .select_related("user")
                    .get(pk=credential.session_id)
                )
                credential.refresh_from_db()
                invalid = (
                    credential.used_at is not None
                    or session.revoked_at is not None
                    or session.refresh_expires_at <= timezone.now()
                    or not session.user.is_active
                    or session.client_type != kind
                )
                if invalid:
                    session.revoked_at = timezone.now()
                    session.save(update_fields=["revoked_at"])
                    request.user = session.user
                    audit(request, "refreshRejected", session.pk)
                else:
                    credential.used_at = timezone.now()
                    credential.save(update_fields=["used_at"])
                    access, refresh = issue_tokens(session)
                    request.user = session.user
                    audit(request, "sessionRefreshed", session.pk)
        if invalid:
            # Raise after the transaction so reuse revocation cannot roll back.
            raise DomainError(
                "UNAUTHENTICATED", "Invalid or expired refresh credential.", 401
            )
        return session_response(request, session, access, refresh)


class LogoutView(PublicAuthView):
    def post(self, request):
        token, kind = refresh_input(request)
        credential = RefreshCredential.objects.filter(token_hash=digest(token)).first()
        if credential:
            with transaction.atomic():
                session = AuthSession.objects.select_for_update().get(
                    pk=credential.session_id
                )
                if session.client_type == kind:
                    session.revoked_at = timezone.now()
                    session.save(update_fields=["revoked_at"])
                    request.user = session.user
                    audit(request, "logout", session.pk)
        response = success(request, {"revoked": True})
        if kind == "web":
            response.delete_cookie(
                settings.REFRESH_COOKIE_NAME, path="/api/v1/auth", samesite="Lax"
            )
        return response


class ProfileView(APIView):
    def get(self, request):
        if request.query_params:
            raise DomainError("BAD_REQUEST", "Query parameters are not accepted.", 400)
        return success(request, profile(request.user))


class SuperadminEmployeesView(APIView):
    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        if not request.user.is_active or not request.user.is_superuser:
            raise DomainError("FORBIDDEN", "Superadmin access is required.", 403)
        rate_limit("superadmin:" + request.user.pk, 120)

    def post(self, request):
        if request.query_params:
            raise DomainError("BAD_REQUEST", "Query parameters are not accepted.", 400)
        form = EmployeeCreateSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        def create():
            values = form.validated_data
            with transaction.atomic():
                user = get_user_model().objects.create_user(
                    email=values["email"],
                    password=values["initialPassword"],
                    full_name=values["fullName"].strip(),
                    employee_number=values["employeeNumber"],
                    job_title=values.get("jobTitle", "").strip(),
                    time_zone=values["timeZone"],
                )
                audit(request, "employeeCreated", user.pk)
                response = success(request, profile(user), 201)
                response["Location"] = "/api/v1/admin/employees/" + user.pk
                return response

        return idempotent(request, request.data, create)


class SuperadminEmployeeView(SuperadminEmployeesView):
    def patch(self, request, employeeId):
        if request.query_params:
            raise DomainError("BAD_REQUEST", "Query parameters are not accepted.", 400)
        with transaction.atomic():
            user = (
                get_user_model().objects.select_for_update().filter(pk=employeeId).first()
            )
            if user is None:
                raise DomainError("NOT_FOUND", "Employee not found.", 404)
            form = EmployeeUpdateSerializer(user, data=request.data, partial=True)
            form.is_valid(raise_exception=True)
            if user.pk == request.user.pk and form.validated_data.get("isActive") is False:
                raise DomainError(
                    "SELF_LOCKOUT_FORBIDDEN",
                    "A superadmin cannot disable their own account.",
                    409,
                )
            mapping = {
                "email": "email",
                "fullName": "full_name",
                "employeeNumber": "employee_number",
                "jobTitle": "job_title",
                "timeZone": "time_zone",
                "isActive": "is_active",
            }
            for source, target in mapping.items():
                if source in form.validated_data:
                    value = form.validated_data[source]
                    if isinstance(value, str):
                        value = value.strip()
                    setattr(user, target, value)
            user.save()
            audit(
                request,
                "employeeProfileUpdated",
                user.pk,
                fields=sorted(form.validated_data),
            )
        return success(request, profile(user))


class SuperadminEmployeeAccessView(SuperadminEmployeesView):
    def put(self, request, employeeId):
        if request.query_params:
            raise DomainError("BAD_REQUEST", "Query parameters are not accepted.", 400)
        form = EmployeeAccessSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        from apps.programs.models import Location

        location_ids = form.validated_data["locationIds"]
        locations = list(Location.objects.filter(pk__in=location_ids, is_active=True))
        if len(locations) != len(location_ids):
            raise DomainError(
                "VALIDATION_FAILED",
                "Every location grant must reference an active location.",
                422,
            )
        with transaction.atomic():
            user = (
                get_user_model().objects.select_for_update().filter(pk=employeeId).first()
            )
            if user is None:
                raise DomainError("NOT_FOUND", "Employee not found.", 404)
            from .models import UserRole

            UserRole.objects.filter(user=user).delete()
            UserRole.objects.bulk_create(
                [
                    UserRole(user=user, role=role)
                    for role in form.validated_data["roles"]
                ]
            )
            user.locations.set(locations)
            audit(
                request,
                "employeeAccessUpdated",
                user.pk,
                roles=sorted(form.validated_data["roles"]),
                locationIds=sorted(location_ids),
            )
        return success(request, profile(user))


class SuperadminEmployeeSignaturesView(SuperadminEmployeesView):
    parser_classes = [MultiPartParser]

    def post(self, request, employeeId):
        if request.query_params or set(request.data) != {"file"}:
            raise DomainError(
                "BAD_REQUEST", "Provide exactly one multipart file field.", 400
            )
        uploaded = request.FILES.get("file")
        if uploaded is None:
            raise DomainError("BAD_REQUEST", "A signature file is required.", 400)
        from .signatures import normalize_signature, write_signature_version

        content = normalize_signature(uploaded.read(2_000_001))
        payload = {"sha256": hashlib.sha256(content).hexdigest()}

        def create():
            written = None
            try:
                with transaction.atomic():
                    user = (
                        get_user_model()
                        .objects.select_for_update()
                        .filter(pk=employeeId)
                        .first()
                    )
                    if user is None:
                        raise DomainError("NOT_FOUND", "Employee not found.", 404)
                    previous_id = user.signature_id
                    signature = write_signature_version(user, content)
                    written = signature.storage_key
                    user.signature = signature
                    user.save(update_fields=["signature", "updated_at"])
                    audit(
                        request,
                        "employeeSignatureReplaced",
                        user.pk,
                        previousSignatureId=previous_id,
                        signatureId=signature.pk,
                    )
                    return success(
                        request,
                        {
                            "id": signature.pk,
                            "employeeId": user.pk,
                            "createdAt": iso(signature.created_at),
                        },
                        201,
                    )
            except Exception:
                if written:
                    from apps.programs.uploads import private_path

                    private_path(written).unlink(missing_ok=True)
                raise

        return idempotent(request, payload, create)


class SuperadminEmployeeCheckerView(SuperadminEmployeesView):
    def put(self, request, employeeId):
        if request.query_params:
            raise DomainError("BAD_REQUEST", "Query parameters are not accepted.", 400)
        form = EmployeeCheckerSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        checker_id = form.validated_data["checkerId"]
        with transaction.atomic():
            user = (
                get_user_model().objects.select_for_update().filter(pk=employeeId).first()
            )
            if user is None:
                raise DomainError("NOT_FOUND", "Employee not found.", 404)
            if checker_id == user.pk:
                raise DomainError(
                    "VALIDATION_FAILED", "An employee cannot check their own work.", 422
                )
            checker = None
            if checker_id is not None:
                checker = (
                    get_user_model()
                    .objects.filter(
                        pk=checker_id,
                        is_active=True,
                        role_grants__role="checker",
                    )
                    .first()
                )
                if checker is None:
                    raise DomainError(
                        "VALIDATION_FAILED",
                        "Checker must reference an active employee with the checker role.",
                        422,
                    )
            previous_id = user.checker_id
            user.checker = checker
            user.save(update_fields=["checker", "updated_at"])
            audit(
                request,
                "employeeCheckerUpdated",
                user.pk,
                previousCheckerId=previous_id,
                checkerId=checker_id,
            )
        return success(request, profile(user))
