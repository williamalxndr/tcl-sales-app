from datetime import datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.core.services import DomainError, audit

from .models import (
    DraftReviewer,
    Program,
    ProgramCounter,
    ProgramType,
    ReviewerEligibility,
    ReviewTask,
    WorkflowPolicy,
)
from .selectors import ROLE_FOR_STAGE, roles


def iso(value):
    return value.isoformat().replace("+00:00", "Z") if value else None


def person(user):
    return {
        "id": user.pk,
        "fullName": user.full_name,
        "jobTitle": user.job_title or None,
    }


def master(value):
    return {
        "id": value.pk,
        "code": value.code,
        "name": value.name,
        "isActive": value.is_active,
    }


def policy():
    value = WorkflowPolicy.objects.filter(pk=1).first()
    return value or WorkflowPolicy()


def policy_dict(p):
    return {
        "withinStageMode": p.within_stage_mode,
        "rejectionEndsSubmission": p.rejection_ends_submission,
        "cancellationStates": p.cancellation_states,
        "requireSignature": p.require_signature,
        "allowSelfApproval": p.allow_self_approval,
        "requireTypeAndCost": p.require_type_and_cost,
        "maxAcknowledgers": p.max_acknowledgers,
        "maxApprovers": p.max_approvers,
    }


def review_plan(program):
    if program.snapshot:
        return program.snapshot["reviewPlan"]
    checker = program.owner.checker
    reviewers = list(
        program.draft_reviewers.select_related("reviewer").order_by("position")
    )
    return {
        "checker": person(checker) if checker else None,
        "acknowledgers": [
            person(r.reviewer) for r in reviewers if r.stage == "acknowledgement"
        ],
        "approvers": [person(r.reviewer) for r in reviewers if r.stage == "approval"],
    }


def issue(field, code, message):
    return {"field": field, "code": code, "message": message}


def submission_issues(program):
    if program.status != "draft":
        return []
    out = []
    p = policy()
    owner = program.owner
    if not program.program_name:
        out.append(issue("programName", "REQUIRED", "A program name is required."))
    if not program.period_start or not program.period_end:
        out.append(
            issue("periodStart", "REQUIRED", "Both execution dates are required.")
        )
    selected = list(program.locations.all())
    if not selected:
        out.append(issue("locationIds", "REQUIRED", "Select at least one location."))
    permitted = set(owner.locations.filter(is_active=True).values_list("id", flat=True))
    if any(l.pk not in permitted for l in selected):
        out.append(
            issue(
                "locationIds",
                "INVALID_LOCATION",
                "A location is inactive or no longer assigned.",
            )
        )
    if program.program_type_id and not program.program_type.is_active:
        out.append(
            issue("programTypeId", "INACTIVE_TYPE", "The program type is inactive.")
        )
    if p.require_type_and_cost is True or (
        p.require_type_and_cost is None
        and (not program.program_type_id or program.estimated_cost is None)
    ):
        code = "POLICY_UNRESOLVED" if p.require_type_and_cost is None else "REQUIRED"
        if not program.program_type_id:
            out.append(
                issue(
                    "programTypeId",
                    code,
                    "Program type is missing; submit requirements must be configured.",
                )
            )
        if program.estimated_cost is None:
            out.append(
                issue(
                    "estimatedCost",
                    code,
                    "Estimated cost is missing; submit requirements must be configured.",
                )
            )
    if (
        not owner.checker_id
        or not owner.checker.is_active
        or "checker" not in roles(owner.checker)
    ):
        out.append(
            issue(
                "checkerId",
                "CHECKER_UNAVAILABLE",
                "An active Checker must be assigned to this employee.",
            )
        )
    reviewers = list(program.draft_reviewers.select_related("reviewer"))
    for stage, limit in [
        ("acknowledgement", p.max_acknowledgers),
        ("approval", p.max_approvers),
    ]:
        group = [r for r in reviewers if r.stage == stage]
        if not 1 <= len(group) <= limit:
            out.append(
                issue(
                    stage,
                    "INVALID_REVIEWER_COUNT",
                    "Reviewer count is outside the configured limits.",
                )
            )
        if len(group) > 1 and not p.within_stage_mode:
            out.append(
                issue(
                    stage,
                    "POLICY_UNRESOLVED",
                    "Within-stage order must be configured for multiple reviewers.",
                )
            )
        for r in group:
            if not eligible(owner, r.reviewer, stage):
                out.append(
                    issue(
                        stage,
                        "INELIGIBLE_REVIEWER",
                        "A selected reviewer is inactive or no longer eligible.",
                    )
                )
    involved = [r.reviewer for r in reviewers] + (
        [owner.checker] if owner.checker_id else []
    )
    if len({r.pk for r in involved}) != len(involved):
        out.append(
            issue(
                None,
                "POLICY_UNRESOLVED",
                "Using one person in multiple review stages has not been authorized.",
            )
        )
    if any(r.pk == owner.pk for r in involved) and p.allow_self_approval is not True:
        out.append(
            issue(
                None,
                "SELF_APPROVAL_UNCONFIGURED",
                "The proposer is in the review plan; self-approval is not authorized.",
            )
        )
    if p.rejection_ends_submission is not True:
        out.append(
            issue(
                None,
                "POLICY_UNRESOLVED",
                "Rejection consequences must be confirmed before review begins.",
            )
        )
    if p.require_signature is None:
        out.append(
            issue(
                None, "POLICY_UNRESOLVED", "Signature requirements must be configured."
            )
        )
    elif p.require_signature and not owner.signature_id:
        out.append(
            issue(
                None,
                "SIGNATURE_REQUIRED",
                "The proposer needs a provisioned signature.",
            )
        )
    if (
        program.attachments.filter(removed_at__isnull=True)
        .exclude(scan_status="clean")
        .exists()
    ):
        out.append(
            issue(
                "attachments",
                "ATTACHMENT_NOT_READY",
                "Every retained attachment must pass scanning; attachments may also be removed.",
            )
        )
    return out


def eligible(owner, reviewer, stage):
    return (
        reviewer.is_active
        and ROLE_FOR_STAGE[stage] in roles(reviewer)
        and ReviewerEligibility.objects.filter(
            employee=owner, reviewer=reviewer, stage=stage
        ).exists()
    )


def attachment_data(a):
    return {
        "id": a.pk,
        "submissionId": a.program_id,
        "fileName": a.file_name,
        "contentType": a.content_type,
        "sizeBytes": a.size_bytes,
        "scanStatus": a.scan_status,
        "uploadedAt": iso(a.uploaded_at),
    }


def summary(program, user):
    snap = program.snapshot
    active = [
        t.pk
        for t in program.review_tasks.all()
        if t.reviewer_id == user.pk
        and t.status == "ready"
        and ROLE_FOR_STAGE[t.stage] in roles(user)
    ]
    return {
        "id": program.pk,
        "programNumber": program.program_number,
        "programName": program.program_name,
        "programType": snap.get("programType")
        if snap
        else master(program.program_type)
        if program.program_type
        else None,
        "locations": snap.get("locations")
        if snap
        else [master(l) for l in program.locations.order_by("code", "id")],
        "periodStart": iso(program.period_start),
        "periodEnd": iso(program.period_end),
        "estimatedCost": {
            "currency": "IDR",
            "amount": format(program.estimated_cost, ".2f"),
        }
        if program.estimated_cost is not None
        else None,
        "owner": snap.get("owner") if snap else person(program.owner),
        "status": program.status,
        "currentStage": program.current_stage,
        "createdAt": iso(program.created_at),
        "updatedAt": iso(program.updated_at),
        "submittedAt": iso(program.submitted_at),
        "version": program.version,
        "revisedFromId": program.revised_from_id,
        "myActiveTaskIds": active,
    }


def detail(program, user):
    result = summary(program, user)
    tasks = list(program.review_tasks.all())
    issues = submission_issues(program)
    actions = (
        ["downloadPdf"]
        if program.status != "draft" or user.pk == program.owner_id
        else []
    )
    if program.status == "draft" and user.pk == program.owner_id:
        actions += ["update", "uploadAttachment"]
        if program.attachments.filter(removed_at__isnull=True).exists():
            actions.append("removeAttachment")
        if not issues:
            actions.append("submit")
    if any(t.pk in result["myActiveTaskIds"] for t in tasks):
        actions.append("delegate")
        p = program.policy_snapshot
        can_sign = p.get("requireSignature") is False or bool(user.signature_id)
        if can_sign and (
            user.pk != program.owner_id or p.get("allowSelfApproval") is True
        ):
            actions.append("approve")
        if user.pk != program.owner_id and p.get("rejectionEndsSubmission") is True:
            actions.append("reject")
    if user.pk == program.owner_id and program.status in policy().cancellation_states:
        actions.append("cancel")
    if user.pk == program.owner_id and program.status == "rejected":
        actions.append("createRevision")
    result.update(
        reviewPlan=review_plan(program),
        reviewTasks=[
            {
                "id": t.pk,
                "stage": t.stage,
                "reviewer": t.reviewer_snapshot,
                "position": t.position,
                "status": t.status,
                "decidedAt": iso(t.decided_at),
                "note": t.note,
            }
            for t in sorted(
                tasks,
                key=lambda t: (
                    {"checker": 0, "acknowledgement": 1, "approval": 2}[t.stage],
                    t.position,
                ),
            )
        ],
        attachments=[
            attachment_data(a)
            for a in program.attachments.filter(removed_at__isnull=True).order_by(
                "uploaded_at", "id"
            )
        ],
        allowedActions=actions,
        submissionIssues=issues,
    )
    return result


def draft_only(program):
    if program.status != "draft":
        raise DomainError("SUBMISSION_LOCKED", "Only drafts may be edited.")


def save_fields(program, data):
    draft_only(program)
    for src, dest in [
        ("programName", "program_name"),
        ("periodStart", "period_start"),
        ("periodEnd", "period_end"),
    ]:
        if src in data:
            setattr(program, dest, data[src])
    if (
        program.period_start
        and program.period_end
        and program.period_start > program.period_end
    ):
        raise ValidationError({"periodEnd": "End date must be on or after start date."})
    if "programTypeId" in data:
        id = data["programTypeId"]
        value = (
            ProgramType.objects.filter(pk=id, is_active=True).first() if id else None
        )
        if id and not value:
            raise ValidationError(
                {"programTypeId": "Unknown or inactive program type."}
            )
        program.program_type = value
    if "estimatedCost" in data:
        program.estimated_cost = (
            Decimal(data["estimatedCost"]["amount"]) if data["estimatedCost"] else None
        )
    if "locationIds" in data:
        values = list(
            program.owner.locations.filter(pk__in=data["locationIds"], is_active=True)
        )
        if len(values) != len(data["locationIds"]):
            raise ValidationError(
                {"locationIds": "One or more locations are unavailable."}
            )
        program.locations.set(values)
    p = policy()
    for key, stage, limit in [
        ("acknowledgerIds", "acknowledgement", p.max_acknowledgers),
        ("approverIds", "approval", p.max_approvers),
    ]:
        if key not in data:
            continue
        if len(data[key]) > limit:
            raise ValidationError(
                {key: "Too many reviewers for the configured policy."}
            )
        users = {u.pk: u for u in get_user_model().objects.filter(pk__in=data[key])}
        if any(
            id not in users or not eligible(program.owner, users[id], stage)
            for id in data[key]
        ):
            raise ValidationError({key: "One or more reviewers are unavailable."})
        program.draft_reviewers.filter(stage=stage).delete()
        DraftReviewer.objects.bulk_create(
            [
                DraftReviewer(
                    program=program, reviewer=users[id], stage=stage, position=i + 1
                )
                for i, id in enumerate(data[key])
            ]
        )
    program.save()


def next_program_number():
    year = datetime.now(ZoneInfo("Asia/Jakarta")).year
    counter, _ = ProgramCounter.objects.get_or_create(year=year)
    counter = ProgramCounter.objects.select_for_update().get(pk=year)
    counter.value += 1
    counter.save()
    return f"PRG-{year}-{counter.value:04d}"


def create_program(request, data):
    program = Program.objects.create(
        owner=request.user, program_number=next_program_number()
    )
    save_fields(program, data)
    audit(request, "draftCreated", program.pk, version=program.version)
    return program


def create_revision(request, source):
    if source.owner_id != request.user.pk:
        raise DomainError("FORBIDDEN", "Only the proposer can create a revision.", 403)
    if source.status != "rejected":
        raise DomainError(
            "INVALID_TRANSITION", "Only a rejected submission can be revised."
        )
    if Program.objects.filter(revised_from=source).exists():
        raise DomainError(
            "REVISION_EXISTS", "A revision already exists for this submission."
        )
    revision = Program.objects.create(
        owner=source.owner,
        revised_from=source,
        program_number=next_program_number(),
        program_name=source.program_name,
        program_type=source.program_type,
        period_start=source.period_start,
        period_end=source.period_end,
        estimated_cost=source.estimated_cost,
    )
    revision.locations.set(source.locations.all())
    candidates = []
    for task in source.review_tasks.select_related("reviewer").exclude(stage="checker"):
        reviewer = task.reviewer
        if reviewer.is_active and eligible(source.owner, reviewer, task.stage):
            candidates.append(
                DraftReviewer(
                    program=revision,
                    reviewer=reviewer,
                    stage=task.stage,
                    position=task.position,
                )
            )
    DraftReviewer.objects.bulk_create(candidates)
    audit(
        request,
        "submissionRevisionCreated",
        revision.pk,
        revisedFromId=source.pk,
        version=revision.version,
    )
    return revision


def activate_stage(program, stage):
    group = program.review_tasks.filter(stage=stage, status="waiting").order_by(
        "position"
    )
    ids = list(group.values_list("id", flat=True))
    if program.policy_snapshot.get("withinStageMode") != "parallelAll":
        ids = ids[:1]
    program.review_tasks.filter(pk__in=ids).update(status="ready")
    program.current_stage = stage
    program.status = {
        "checker": "pendingChecker",
        "acknowledgement": "pendingAcknowledgement",
        "approval": "pendingApproval",
    }[stage]


def submit_program(request, program):
    draft_only(program)
    problems = submission_issues(program)
    if problems:
        blocked = any(
            p["code"] in ["POLICY_UNRESOLVED", "SELF_APPROVAL_UNCONFIGURED"]
            for p in problems
        )
        raise DomainError(
            "WORKFLOW_POLICY_UNRESOLVED" if blocked else "VALIDATION_FAILED",
            "Submission requirements are not satisfied.",
            409 if blocked else 422,
            problems,
        )
    program.snapshot = {
        "owner": person(program.owner),
        "programType": master(program.program_type) if program.program_type else None,
        "locations": [master(l) for l in program.locations.order_by("code", "id")],
        "reviewPlan": review_plan(program),
    }
    program.policy_snapshot = policy_dict(policy())
    program.proposer_signature = program.owner.signature
    plan = [("checker", program.owner.checker, 1)] + [
        (r.stage, r.reviewer, r.position)
        for r in program.draft_reviewers.select_related("reviewer")
    ]
    ReviewTask.objects.bulk_create(
        [
            ReviewTask(
                program=program,
                stage=s,
                reviewer=u,
                position=i,
                reviewer_snapshot=person(u),
            )
            for s, u, i in plan
        ]
    )
    activate_stage(program, "checker")
    program.submitted_at = timezone.now()
    program.version += 1
    program.save()
    audit(request, "submitted", program.pk, version=program.version)


def decide(request, program, task_id, action, note):
    task = program.review_tasks.filter(pk=task_id, reviewer=request.user).first()
    if not task:
        raise DomainError("NOT_FOUND", "Review task not found.", 404)
    if ROLE_FOR_STAGE[task.stage] not in roles(request.user):
        raise DomainError("FORBIDDEN", "Required reviewer role is missing.", 403)
    if task.status != "ready" or program.status not in [
        "pendingChecker",
        "pendingAcknowledgement",
        "pendingApproval",
    ]:
        raise DomainError("TASK_NOT_READY", "This task is not currently actionable.")
    p = program.policy_snapshot
    if action == "reject":
        if request.user.pk == program.owner_id:
            raise DomainError(
                "FORBIDDEN", "The proposer cannot reject their own submission.", 403
            )
        if p.get("rejectionEndsSubmission") is not True:
            raise DomainError(
                "WORKFLOW_POLICY_UNRESOLVED",
                "Rejection consequences have not been configured.",
            )
        task.status = "rejected"
        program.status = "rejected"
        program.current_stage = None
        program.closed_at = timezone.now()
        program.review_tasks.filter(status__in=["waiting", "ready"]).exclude(
            pk=task.pk
        ).update(status="voided")
    else:
        if (
            request.user.pk == program.owner_id
            and p.get("allowSelfApproval") is not True
        ):
            raise DomainError("FORBIDDEN", "Self-approval is not authorized.", 403)
        if p.get("requireSignature") is None:
            raise DomainError(
                "WORKFLOW_POLICY_UNRESOLVED",
                "Signature requirements are not configured.",
            )
        if p.get("requireSignature") and not request.user.signature_id:
            raise DomainError(
                "SIGNATURE_REQUIRED", "A provisioned account signature is required."
            )
        task.status = "approved"
        task.signature = request.user.signature
    task.note = note
    task.decided_at = timezone.now()
    task.save()
    if action == "approve":
        remaining = program.review_tasks.filter(
            stage=task.stage, status__in=["waiting", "ready"]
        )
        if remaining.exists():
            if p.get("withinStageMode") == "sequential":
                next_task = (
                    remaining.filter(status="waiting").order_by("position").first()
                )
                if next_task:
                    next_task.status = "ready"
                    next_task.save(update_fields=["status"])
        else:
            stages = ["checker", "acknowledgement", "approval"]
            index = stages.index(task.stage)
            if index == 2:
                program.status = "approved"
                program.current_stage = None
                program.closed_at = timezone.now()
            else:
                activate_stage(program, stages[index + 1])
    program.version += 1
    program.save()
    audit(
        request,
        {"approve": "approved", "reject": "rejected"}[action],
        program.pk,
        taskId=task.pk,
        version=program.version,
    )


def cancel(request, program, reason):
    if request.user.pk != program.owner_id:
        raise DomainError("FORBIDDEN", "Only the proposer can cancel.", 403)
    permitted = policy().cancellation_states
    if not permitted:
        raise DomainError(
            "WORKFLOW_POLICY_UNRESOLVED",
            "Cancellation stages have not been configured.",
        )
    if program.status not in permitted:
        raise DomainError(
            "INVALID_TRANSITION", "Cancellation is not permitted at this stage."
        )
    program.review_tasks.filter(status__in=["waiting", "ready"]).update(status="voided")
    program.status = "cancelled"
    program.current_stage = None
    program.closed_at = timezone.now()
    program.cancellation_reason = reason
    program.version += 1
    program.save()
    audit(request, "cancelled", program.pk, version=program.version)


def delegate_task(request, program, task_id, reviewer_id):
    task = program.review_tasks.filter(pk=task_id, reviewer=request.user).first()
    if task is None:
        raise DomainError("NOT_FOUND", "Review task not found.", 404)
    if task.status != "ready":
        raise DomainError("TASK_NOT_READY", "Only a ready task can be delegated.")
    required_role = ROLE_FOR_STAGE[task.stage]
    reviewer = (
        get_user_model()
        .objects.filter(
            pk=reviewer_id, is_active=True, role_grants__role=required_role
        )
        .first()
    )
    if reviewer is None or reviewer.pk == request.user.pk:
        raise DomainError(
            "VALIDATION_FAILED",
            "Delegate must be another active employee with the required role.",
            422,
        )
    if reviewer.pk == program.owner_id and program.policy_snapshot.get(
        "allowSelfApproval"
    ) is not True:
        raise DomainError("FORBIDDEN", "Self-approval is not authorized.", 403)
    if task.stage != "checker" and not ReviewerEligibility.objects.filter(
        employee_id=program.owner_id,
        reviewer=reviewer,
        stage=task.stage,
    ).exists():
        raise DomainError(
            "VALIDATION_FAILED", "Delegate is not eligible for this employee.", 422
        )
    if program.review_tasks.exclude(pk=task.pk).filter(reviewer=reviewer).exists():
        raise DomainError(
            "VALIDATION_FAILED",
            "The delegate already has a task in this submission.",
            422,
        )
    previous_id = task.reviewer_id
    task.reviewer = reviewer
    task.reviewer_snapshot = person(reviewer)
    task.save(update_fields=["reviewer", "reviewer_snapshot"])
    program.version += 1
    program.save(update_fields=["version", "updated_at"])
    audit(
        request,
        "reviewTaskDelegated",
        program.pk,
        taskId=task.pk,
        previousReviewerId=previous_id,
        reviewerId=reviewer.pk,
        version=program.version,
    )


def reassign_task(request, program, task_id, reviewer_id):
    task = program.review_tasks.filter(pk=task_id).first()
    if task is None:
        raise DomainError("NOT_FOUND", "Review task not found.", 404)
    if task.status not in ["waiting", "ready"]:
        raise DomainError(
            "TASK_NOT_REASSIGNABLE", "Only an undecided task can be reassigned."
        )
    required_role = ROLE_FOR_STAGE[task.stage]
    reviewer = (
        get_user_model()
        .objects.filter(
            pk=reviewer_id, is_active=True, role_grants__role=required_role
        )
        .first()
    )
    if reviewer is None or reviewer.pk == task.reviewer_id:
        raise DomainError(
            "VALIDATION_FAILED",
            "Replacement must be another active employee with the required role.",
            422,
        )
    if reviewer.pk == program.owner_id and program.policy_snapshot.get(
        "allowSelfApproval"
    ) is not True:
        raise DomainError("FORBIDDEN", "Self-approval is not authorized.", 403)
    if task.stage != "checker" and not ReviewerEligibility.objects.filter(
        employee_id=program.owner_id,
        reviewer=reviewer,
        stage=task.stage,
    ).exists():
        raise DomainError(
            "VALIDATION_FAILED", "Replacement is not eligible for this employee.", 422
        )
    if program.review_tasks.exclude(pk=task.pk).filter(reviewer=reviewer).exists():
        raise DomainError(
            "VALIDATION_FAILED",
            "The replacement already has a task in this submission.",
            422,
        )
    previous_id = task.reviewer_id
    task.reviewer = reviewer
    task.reviewer_snapshot = person(reviewer)
    task.save(update_fields=["reviewer", "reviewer_snapshot"])
    program.version += 1
    program.save(update_fields=["version", "updated_at"])
    audit(
        request,
        "reviewTaskReassigned",
        program.pk,
        taskId=task.pk,
        previousReviewerId=previous_id,
        reviewerId=reviewer.pk,
        version=program.version,
    )
