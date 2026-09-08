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
        if extra_fields.get("is_staff") is not True or extra_fields.get("is_superuser") is not True:
            raise ValueError("A superuser must have is_staff=True and is_superuser=True.")
        return self.create_user(email, password, **extra_fields)

    def get_by_natural_key(self, email):
        return self.get(email=email.strip().lower())


class User(AbstractUser):
    """Identity foundation; no public registration or business-role grants yet."""

    id = models.CharField(primary_key=True, max_length=64, default=user_id, editable=False)
    username = None
    first_name = None
    last_name = None
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=150, blank=True)
    employee_number = models.CharField(max_length=50, unique=True, null=True, blank=True)
    job_title = models.CharField(max_length=150, blank=True)
    time_zone = models.CharField(max_length=64, default="Asia/Jakarta")
    updated_at = models.DateTimeField(auto_now=True)

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
