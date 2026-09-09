from django.utils import timezone
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed

from apps.core.services import digest

from .models import AuthSession


class OpaqueBearerAuthentication(BaseAuthentication):
    def authenticate(self, request):
        parts = get_authorization_header(request).split()
        if not parts:
            return None
        if len(parts) != 2 or parts[0].lower() != b"bearer":
            raise AuthenticationFailed("Invalid authentication credentials.")
        try:
            token = parts[1].decode("ascii")
        except UnicodeDecodeError:
            raise AuthenticationFailed("Invalid authentication credentials.")
        session = (
            AuthSession.objects.select_related("user")
            .filter(
                access_hash=digest(token),
                revoked_at__isnull=True,
                access_expires_at__gt=timezone.now(),
                user__is_active=True,
            )
            .first()
        )
        if not session:
            raise AuthenticationFailed("Invalid authentication credentials.")
        return session.user, session

    def authenticate_header(self, request):
        return "Bearer"
