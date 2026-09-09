import getpass
import hashlib
import io
import os
from pathlib import Path
from uuid import uuid4

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from PIL import Image

from apps.accounts.models import AccountSignature, UserRole
from apps.core.models import AuditLog
from apps.programs.models import Location, ReviewerEligibility
from apps.programs.uploads import private_path


class Command(BaseCommand):
    help = "Provision a trusted employee account. Password is prompted or read from SALES_EMPLOYEE_PASSWORD; never printed."

    def add_arguments(self, p):
        p.add_argument("--email", required=True)
        p.add_argument("--name", required=True)
        p.add_argument("--employee-number", required=True)
        p.add_argument("--job-title", default="")
        p.add_argument("--roles", nargs="+", choices=UserRole.ROLES, required=True)
        p.add_argument("--checker-email")
        p.add_argument("--locations", nargs="*", default=[])
        p.add_argument("--acknowledgers", nargs="*", default=[])
        p.add_argument("--approvers", nargs="*", default=[])
        p.add_argument(
            "--signature",
            help="PNG/JPEG image provisioned by the organization; new immutable version.",
        )

    def handle(self, *args, **opts):
        password = os.environ.get("SALES_EMPLOYEE_PASSWORD") or getpass.getpass(
            "Employee password: "
        )
        User = get_user_model()
        email = opts["email"].strip().lower()
        candidate = User(email=email, full_name=opts["name"])
        if len(password) > 128:
            raise CommandError("Password exceeds the 128-character login limit.")
        validate_password(password, candidate)
        written = None
        try:
            with transaction.atomic():
                user = User.objects.filter(email=email).first()
                if user:
                    raise CommandError(
                        "This account already exists; use an explicit future account-update workflow."
                    )
                user = User.objects.create_user(
                    email,
                    password,
                    full_name=opts["name"],
                    employee_number=opts["employee_number"],
                    job_title=opts["job_title"],
                )
                UserRole.objects.bulk_create(
                    [UserRole(user=user, role=r) for r in set(opts["roles"])]
                )
                if opts["checker_email"]:
                    user.checker = User.objects.get(
                        email=opts["checker_email"].strip().lower(),
                        is_active=True,
                        role_grants__role="checker",
                    )
                locations = list(
                    Location.objects.filter(code__in=opts["locations"], is_active=True)
                )
                if len(locations) != len(set(opts["locations"])):
                    raise CommandError("Create all selected locations first.")
                user.locations.set(locations)
                for key, stage, role in [
                    ("acknowledgers", "acknowledgement", "acknowledger"),
                    ("approvers", "approval", "approver"),
                ]:
                    for email in set(opts[key]):
                        reviewer = User.objects.get(
                            email=email.strip().lower(),
                            is_active=True,
                            role_grants__role=role,
                        )
                        ReviewerEligibility.objects.create(
                            employee=user, reviewer=reviewer, stage=stage
                        )
                if opts["signature"]:
                    source = Path(opts["signature"])
                    if source.stat().st_size > 2_000_000:
                        raise CommandError("Signature image exceeds 2 MB.")
                    with Image.open(source) as image:
                        if (
                            image.format not in ["PNG", "JPEG"]
                            or image.width * image.height > 4_000_000
                        ):
                            raise CommandError(
                                "Use a PNG/JPEG signature up to 4 megapixels."
                            )
                        image.load()
                        image = image.convert("RGBA")
                        image.thumbnail((1600, 800))
                        stream = io.BytesIO()
                        image.save(stream, format="PNG")
                        content = stream.getvalue()
                    key = "signatures/" + uuid4().hex + ".png"
                    written = private_path(key)
                    written.parent.mkdir(parents=True, exist_ok=True)
                    written.write_bytes(content)
                    user.signature = AccountSignature.objects.create(
                        user=user,
                        storage_key=key,
                        sha256=hashlib.sha256(content).hexdigest(),
                    )
                user.full_clean(exclude=["password"])
                user.save()
                AuditLog.objects.create(
                    event="employeeProvisioned",
                    resource_id=user.pk,
                    request_id="management_command",
                    details={"roles": opts["roles"]},
                )
        except Exception:
            if written:
                written.unlink(missing_ok=True)
            raise
        self.stdout.write("Employee provisioned: " + user.pk)
