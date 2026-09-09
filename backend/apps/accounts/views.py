import secrets
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.middleware.csrf import CsrfViewMiddleware, get_token, rotate_token
from django.utils import timezone
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView

from apps.core.api import success
from apps.core.services import DomainError, audit, digest, rate_limit

from .models import AuthSession, RefreshCredential
from .serializers import LoginSerializer, RefreshSerializer, profile


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
