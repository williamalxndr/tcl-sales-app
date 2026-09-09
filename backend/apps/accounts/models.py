from uuid import uuid4

from django.contrib.auth.base_user import BaseUserManager
from django.contrib.auth.models import AbstractUser
from django.db import models


def user_id():
    return "usr_" + uuid4().hex


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email, password=None, **extra_fields):
        if not email or not email.strip():
            raise ValueError("An email address is required.")
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        if (
            extra_fields.get("is_staff") is not True
            or extra_fields.get("is_superuser") is not True
        ):
            raise ValueError(
                "A superuser must have is_staff=True and is_superuser=True."
            )
        return self.create_user(email, password, **extra_fields)

    def get_by_natural_key(self, email):
        return self.get(email=email.strip().lower())


class User(AbstractUser):
    """Pre-provisioned employee identity and company-assigned routing."""

    id = models.CharField(
        primary_key=True, max_length=64, default=user_id, editable=False
    )
    username = None
    first_name = None
    last_name = None
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=150, blank=True)
    employee_number = models.CharField(
        max_length=50, unique=True, null=True, blank=True
    )
    job_title = models.CharField(max_length=150, blank=True)
    time_zone = models.CharField(max_length=64, default="Asia/Jakarta")
    updated_at = models.DateTimeField(auto_now=True)
    checker = models.ForeignKey(
        "self",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="checked_employees",
    )
    locations = models.ManyToManyField(
        "programs.Location", blank=True, related_name="employees"
    )
    signature = models.ForeignKey(
        "AccountSignature",
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="+",
    )

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []
    objects = UserManager()

    def save(self, *args, **kwargs):
        self.email = self.email.strip().lower()
        self.employee_number = (self.employee_number or "").strip() or None
        super().save(*args, **kwargs)

    def get_full_name(self):
        return self.full_name

    def get_short_name(self):
        return self.full_name or self.email

    def __str__(self):
        return self.email


def session_id():
    return "ses_" + uuid4().hex


def signature_id():
    return "sig_" + uuid4().hex


class UserRole(models.Model):
    ROLES = ["submitter", "checker", "acknowledger", "approver", "backofficeAdmin"]
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="role_grants")
    role = models.CharField(max_length=24, choices=[(r, r) for r in ROLES])

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "role"], name="unique_user_role")
        ]


class AccountSignature(models.Model):
    id = models.CharField(
        primary_key=True, max_length=64, default=signature_id, editable=False
    )
    user = models.ForeignKey(
        User, on_delete=models.PROTECT, related_name="signature_versions"
    )
    storage_key = models.CharField(max_length=255, unique=True)
    sha256 = models.CharField(max_length=64)
    created_at = models.DateTimeField(auto_now_add=True)


class AuthSession(models.Model):
    id = models.CharField(
        primary_key=True, max_length=64, default=session_id, editable=False
    )
    user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="api_sessions"
    )
    client_type = models.CharField(
        max_length=6, choices=[("native", "Native"), ("web", "Web")]
    )
    access_hash = models.CharField(max_length=64, unique=True)
    access_expires_at = models.DateTimeField()
    refresh_expires_at = models.DateTimeField()
    revoked_at = models.DateTimeField(null=True)
    created_at = models.DateTimeField(auto_now_add=True)


class RefreshCredential(models.Model):
    session = models.ForeignKey(
        AuthSession, on_delete=models.CASCADE, related_name="refresh_credentials"
    )
    token_hash = models.CharField(max_length=64, unique=True)
    used_at = models.DateTimeField(null=True)
    created_at = models.DateTimeField(auto_now_add=True)
