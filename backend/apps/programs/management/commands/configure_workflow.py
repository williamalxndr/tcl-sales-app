from django.core.management.base import BaseCommand
from django.db import transaction

from apps.core.models import AuditLog
from apps.programs.models import WorkflowPolicy


class Command(BaseCommand):
    help = "Configure confirmed workflow policy. Does not rewrite submitted policy snapshots."

    def add_arguments(self, p):
        p.add_argument(
            "--cancellation-states",
            nargs="+",
            choices=[
                "draft",
                "pendingChecker",
                "pendingAcknowledgement",
                "pendingApproval",
                "approved",
            ],
        )
        p.add_argument("--require-type-and-cost", choices=["yes", "no"])

    def handle(self, *args, **options):
        with transaction.atomic():
            obj, _ = WorkflowPolicy.objects.get_or_create(pk=1)
            obj = WorkflowPolicy.objects.select_for_update().get(pk=1)
            # Confirmed by the user: sequential, terminal rejection, provisioned signatures.
            obj.within_stage_mode = "sequential"
            obj.rejection_ends_submission = True
            obj.require_signature = True
            if options["cancellation_states"] is not None:
                obj.cancellation_states = options["cancellation_states"]
            if options["require_type_and_cost"] is not None:
                obj.require_type_and_cost = options["require_type_and_cost"] == "yes"
            obj.save()
            AuditLog.objects.create(
                event="workflowConfigured",
                resource_id="policy_1",
                request_id="management_command",
                details={"cancellationStates": obj.cancellation_states},
            )
        self.stdout.write(
            "Confirmed workflow configured. Unanswered cancellation/field rules retain their existing values."
        )
