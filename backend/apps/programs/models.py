from uuid import uuid4

from django.conf import settings
from django.db import models

from .policy import CANCELLABLE_STATUSES


def default_cancellation_states():
    return list(CANCELLABLE_STATUSES)

STAGES = [
    ("checker", "Checker"),
    ("acknowledgement", "Mengetahui"),
    ("approval", "Menyetujui"),
]
STATUSES = [
    "draft",
    "pendingChecker",
    "pendingAcknowledgement",
    "pendingApproval",
    "approved",
    "rejected",
    "cancelled",
]


def program_id():
    return "sub_" + uuid4().hex


def location_id():
    return "loc_" + uuid4().hex


def type_id():
    return "typ_" + uuid4().hex


def task_id():
    return "tsk_" + uuid4().hex


def attachment_id():
    return "att_" + uuid4().hex


class Location(models.Model):
    id = models.CharField(
        primary_key=True, max_length=64, default=location_id, editable=False
    )
    code = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=150)
    is_active = models.BooleanField(default=True)


class ProgramType(models.Model):
    id = models.CharField(
        primary_key=True, max_length=64, default=type_id, editable=False
    )
    code = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=150)
    is_active = models.BooleanField(default=True)


class ReviewerEligibility(models.Model):
    employee = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="reviewer_eligibilities",
    )
    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="eligible_for"
    )
    stage = models.CharField(max_length=20, choices=STAGES[1:])

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["employee", "reviewer", "stage"],
                name="unique_reviewer_eligibility",
            )
        ]


class WorkflowPolicy(models.Model):
    # One explicitly configured company policy; snapshots are saved at submit.
    id = models.PositiveSmallIntegerField(primary_key=True, default=1)
    within_stage_mode = models.CharField(
        max_length=20,
        blank=True,
        choices=[("sequential", "Sequential"), ("parallelAll", "Parallel/all")],
    )
    rejection_ends_submission = models.BooleanField(null=True)
    cancellation_states = models.JSONField(default=default_cancellation_states)
    require_signature = models.BooleanField(null=True)
    allow_self_approval = models.BooleanField(null=True)
    require_type_and_cost = models.BooleanField(null=True)
    max_acknowledgers = models.PositiveSmallIntegerField(default=2)
    max_approvers = models.PositiveSmallIntegerField(default=3)
    updated_at = models.DateTimeField(auto_now=True)


class ProgramCounter(models.Model):
    year = models.PositiveSmallIntegerField(primary_key=True)
    value = models.PositiveIntegerField(default=0)


class Program(models.Model):
    id = models.CharField(
        primary_key=True, max_length=64, default=program_id, editable=False
    )
    program_number = models.CharField(max_length=64, unique=True)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="programs"
    )
    program_name = models.CharField(max_length=200, null=True, blank=True)
    program_type = models.ForeignKey(ProgramType, null=True, on_delete=models.PROTECT)
    locations = models.ManyToManyField(Location)
    period_start = models.DateField(null=True)
    period_end = models.DateField(null=True)
    estimated_cost = models.DecimalField(max_digits=16, decimal_places=2, null=True)
    status = models.CharField(
        max_length=24, choices=[(s, s) for s in STATUSES], default="draft"
    )
    current_stage = models.CharField(max_length=20, choices=STAGES, null=True)
    version = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    submitted_at = models.DateTimeField(null=True)
    closed_at = models.DateTimeField(null=True)
    cancellation_reason = models.TextField(blank=True)
    snapshot = models.JSONField(default=dict)
    policy_snapshot = models.JSONField(default=dict)
    proposer_signature = models.ForeignKey(
        "accounts.AccountSignature", null=True, on_delete=models.PROTECT
    )

    class Meta:
        indexes = [
            models.Index(fields=["owner", "created_at", "id"]),
            models.Index(fields=["status", "created_at", "id"]),
        ]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(estimated_cost__gte=0)
                | models.Q(estimated_cost__isnull=True),
                name="nonnegative_program_cost",
            ),
            models.CheckConstraint(
                condition=models.Q(period_start__isnull=True)
                | models.Q(period_end__isnull=True)
                | models.Q(period_end__gte=models.F("period_start")),
                name="ordered_program_dates",
            ),
        ]


class DraftReviewer(models.Model):
    program = models.ForeignKey(
        Program, on_delete=models.CASCADE, related_name="draft_reviewers"
    )
    reviewer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    stage = models.CharField(max_length=20, choices=STAGES[1:])
    position = models.PositiveSmallIntegerField()

    class Meta:
        ordering = ["position", "id"]
        constraints = [
            models.UniqueConstraint(
                fields=["program", "stage", "position"],
                name="unique_draft_review_position",
            ),
            models.UniqueConstraint(
                fields=["program", "stage", "reviewer"], name="unique_draft_reviewer"
            ),
        ]


class ReviewTask(models.Model):
    id = models.CharField(
        primary_key=True, max_length=64, default=task_id, editable=False
    )
    program = models.ForeignKey(
        Program, on_delete=models.PROTECT, related_name="review_tasks"
    )
    reviewer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="review_tasks"
    )
    reviewer_snapshot = models.JSONField()
    stage = models.CharField(max_length=20, choices=STAGES)
    position = models.PositiveSmallIntegerField()
    status = models.CharField(
        max_length=12,
        default="waiting",
        choices=[
            (s, s) for s in ["waiting", "ready", "approved", "rejected", "voided"]
        ],
    )
    decided_at = models.DateTimeField(null=True)
    note = models.TextField(null=True)
    signature = models.ForeignKey(
        "accounts.AccountSignature", null=True, on_delete=models.PROTECT
    )

    class Meta:
        ordering = ["position", "id"]
        indexes = [models.Index(fields=["reviewer", "status", "program"])]
        constraints = [
            models.UniqueConstraint(
                fields=["program", "stage", "position"],
                name="unique_review_task_position",
            )
        ]


class Attachment(models.Model):
    id = models.CharField(
        primary_key=True, max_length=64, default=attachment_id, editable=False
    )
    program = models.ForeignKey(
        Program, on_delete=models.PROTECT, related_name="attachments"
    )
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT)
    file_name = models.CharField(max_length=255)
    storage_key = models.CharField(max_length=255, unique=True)
    content_type = models.CharField(max_length=150)
    size_bytes = models.PositiveIntegerField()
    sha256 = models.CharField(max_length=64)
    scan_status = models.CharField(
        max_length=12,
        default="pending",
        choices=[(s, s) for s in ["pending", "clean", "rejected"]],
    )
    scan_reason = models.CharField(max_length=80, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)
    scanned_at = models.DateTimeField(null=True)
    removed_at = models.DateTimeField(null=True)
