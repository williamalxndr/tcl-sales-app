from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Q
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.api import success
from apps.core.serializers import StrictSerializer
from apps.core.services import DomainError, audit, idempotent, rate_limit, version_match

from . import services as svc
from .models import ProgramType, ReviewerEligibility, ReviewTask
from .selectors import (
    check_query,
    filter_programs,
    get_program,
    paginated,
    roles,
    scoped,
)
from .serializers import (
    CancellationSerializer,
    DecisionSerializer,
    DraftSerializer,
    ReviewerAssignmentSerializer,
)


def program_response(request, program, status=200):
    response = success(request, svc.detail(program, request.user), status)
    response["ETag"] = f'"{program.version}"'
    if status == 201:
        response["Location"] = "/api/v1/program-submissions/" + program.pk
    return response


class AuthenticatedView(APIView):
    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        rate_limit("api-user:" + request.user.pk, 180)


class OwnProgramsView(AuthenticatedView):
    def get(self, request):
        query = filter_programs(request, scoped(request.user, "own"))
        return Response(
            paginated(request, query, lambda p: svc.summary(p, request.user))
        )

    def post(self, request):
        scoped(request.user, "own")
        check_query(request, [])
        form = DraftSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        return idempotent(
            request,
            request.data,
            lambda: program_response(
                request, svc.create_program(request, form.validated_data), 201
            ),
        )


class OwnProgramView(AuthenticatedView):
    def get(self, request, submissionId):
        check_query(request, [])
        return program_response(request, get_program(request.user, submissionId))

    def patch(self, request, submissionId):
        check_query(request, [])
        form = DraftSerializer(data=request.data, context={"patch": True})
        form.is_valid(raise_exception=True)
        with transaction.atomic():
            program = get_program(request.user, submissionId, lock=True)
            version_match(request, program)
            svc.save_fields(program, form.validated_data)
            program.version += 1
            program.save()
            audit(
                request,
                "draftUpdated",
                program.pk,
                version=program.version,
                fields=list(form.validated_data),
            )
            return program_response(request, program)


class PolicyView(AuthenticatedView):
    def get(self, request, submissionId):
        from .uploads import ALLOWED_EXTENSIONS, MAX_BYTES

        check_query(request, [])
        program = get_program(request.user, submissionId)
        p = svc.policy()
        checker = program.owner.checker
        valid = checker and checker.is_active and "checker" in roles(checker)
        return success(
            request,
            {
                "policyVersion": svc.iso(p.updated_at)
                if p.updated_at
                else "unconfigured",
                "checker": svc.person(checker) if valid else None,
                "minAcknowledgers": 1,
                "maxAcknowledgers": p.max_acknowledgers,
                "minApprovers": 1,
                "maxApprovers": p.max_approvers,
                "allowedAttachmentExtensions": list(ALLOWED_EXTENSIONS),
                "maxAttachmentBytes": MAX_BYTES,
                "routingConfigured": bool(valid),
            },
        )


class ReviewerOptionsView(AuthenticatedView):
    def get(self, request, submissionId):
        check_query(request, ["stage", "q", "page", "pageSize"])
        program = get_program(request.user, submissionId)
        stage = request.query_params.get("stage")
        if stage not in ["acknowledgement", "approval"]:
            raise DomainError(
                "VALIDATION_FAILED", "A selectable stage is required.", 422
            )
        grants = ReviewerEligibility.objects.filter(
            employee=program.owner,
            stage=stage,
            reviewer__is_active=True,
            reviewer__role_grants__role=svc.ROLE_FOR_STAGE[stage],
        )
        users = get_user_model().objects.filter(pk__in=grants.values("reviewer_id"))
        q = request.query_params.get("q", "").strip()
        if q:
            users = users.filter(Q(full_name__icontains=q) | Q(job_title__icontains=q))
        return Response(
            paginated(
                request,
                users.order_by("full_name", "id"),
                lambda u: {"person": svc.person(u), "eligibleStages": [stage]},
            )
        )


class BackofficeProgramsView(AuthenticatedView):
    scope = "inbox"

    def get(self, request):
        query = filter_programs(request, scoped(request.user, self.scope), True)
        return Response(
            paginated(request, query, lambda p: svc.summary(p, request.user))
        )


class ReviewHistoryView(BackofficeProgramsView):
    scope = "history"


class BackofficeProgramView(AuthenticatedView):
    def get(self, request, submissionId):
        check_query(request, [])
        return program_response(
            request, get_program(request.user, submissionId, "visible")
        )


class FilterPeopleView(AuthenticatedView):
    def get(self, request):
        check_query(request, ["field", "scope", "q", "page", "pageSize"])
        scope = request.query_params.get("scope", "inbox")
        field = request.query_params.get("field")
        if scope not in ["inbox", "history"] or field not in [
            "owner",
            "checker",
            "acknowledger",
            "approver",
        ]:
            raise DomainError(
                "VALIDATION_FAILED", "Invalid filter field or scope.", 422
            )
        programs = scoped(request.user, scope)
        if field == "owner":
            ids = programs.values("owner_id")
        else:
            ids = ReviewTask.objects.filter(
                program__in=programs,
                stage={
                    "checker": "checker",
                    "acknowledger": "acknowledgement",
                    "approver": "approval",
                }[field],
            ).values("reviewer_id")
        query = get_user_model().objects.filter(pk__in=ids)
        q = request.query_params.get("q", "").strip()
        if q:
            query = query.filter(Q(full_name__icontains=q) | Q(job_title__icontains=q))
        return Response(
            paginated(request, query.order_by("full_name", "id"), svc.person)
        )


class LocationsView(AuthenticatedView):
    def get(self, request):
        check_query(request, ["q", "page", "pageSize"])
        query = request.user.locations.filter(is_active=True)
        q = request.query_params.get("q", "").strip()
        if q:
            query = query.filter(Q(code__icontains=q) | Q(name__icontains=q))
        return Response(paginated(request, query.order_by("code", "id"), svc.master))


class ProgramTypesView(LocationsView):
    def get(self, request):
        check_query(request, ["q", "page", "pageSize"])
        query = ProgramType.objects.filter(is_active=True)
        q = request.query_params.get("q", "").strip()
        if q:
            query = query.filter(Q(code__icontains=q) | Q(name__icontains=q))
        return Response(paginated(request, query.order_by("code", "id"), svc.master))


class SubmitView(AuthenticatedView):
    def post(self, request, submissionId):
        check_query(request, [])
        form = StrictSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        get_program(request.user, submissionId)

        def change():
            program = get_program(request.user, submissionId, lock=True)
            version_match(request, program)
            svc.submit_program(request, program)
            return program_response(request, program)

        return idempotent(request, request.data, change)


class CancelView(AuthenticatedView):
    def post(self, request, submissionId):
        check_query(request, [])
        form = CancellationSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        get_program(request.user, submissionId)

        def change():
            program = get_program(request.user, submissionId, lock=True)
            version_match(request, program)
            svc.cancel(request, program, form.validated_data["reason"])
            return program_response(request, program)

        return idempotent(request, request.data, change)


class RevisionView(AuthenticatedView):
    def post(self, request, submissionId):
        check_query(request, [])
        form = StrictSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        get_program(request.user, submissionId)

        def change():
            source = get_program(request.user, submissionId, lock=True)
            revision = svc.create_revision(request, source)
            return program_response(request, revision, 201)

        return idempotent(request, request.data, change)


class DecisionView(AuthenticatedView):
    action = "approve"

    def post(self, request, submissionId, taskId):
        check_query(request, [])
        form = DecisionSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        get_program(request.user, submissionId, "visible")

        def change():
            program = get_program(request.user, submissionId, "visible", lock=True)
            version_match(request, program)
            svc.decide(
                request, program, taskId, self.action, form.validated_data.get("note")
            )
            return program_response(request, program)

        return idempotent(request, request.data, change)


class RejectView(DecisionView):
    action = "reject"


class DelegateReviewTaskView(AuthenticatedView):
    def post(self, request, submissionId, taskId):
        check_query(request, [])
        form = ReviewerAssignmentSerializer(data=request.data)
        form.is_valid(raise_exception=True)
        get_program(request.user, submissionId, "visible")

        def change():
            program = get_program(request.user, submissionId, "visible", lock=True)
            version_match(request, program)
            svc.delegate_task(
                request, program, taskId, form.validated_data["reviewerId"]
            )
            return program_response(request, program)

        return idempotent(request, request.data, change)
