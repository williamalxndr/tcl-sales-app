import math
from datetime import date

from django.db.models import Exists, OuterRef, Q
from rest_framework.exceptions import NotFound

from apps.core.api import meta
from apps.core.services import DomainError

from .models import STATUSES, Program, ReviewTask

ROLE_FOR_STAGE = {
    "checker": "checker",
    "acknowledgement": "acknowledger",
    "approval": "approver",
}
REVIEW_ROLES = set(ROLE_FOR_STAGE.values())


def roles(user):
    if not hasattr(user, "_api_roles"):
        user._api_roles = set(user.role_grants.values_list("role", flat=True))
    return user._api_roles


def require_role(user, allowed):
    if not roles(user).intersection(allowed):
        raise DomainError("FORBIDDEN", "This account lacks the required role.", 403)


def scoped(user, scope):
    if scope == "own":
        require_role(user, {"submitter"})
        return Program.objects.filter(owner=user)
    require_role(user, REVIEW_ROLES)
    stages = [s for s, r in ROLE_FOR_STAGE.items() if r in roles(user)]
    states = (
        ["ready"]
        if scope == "inbox"
        else ["approved", "rejected"]
        if scope == "history"
        else ["ready", "approved", "rejected"]
    )
    tasks = ReviewTask.objects.filter(
        program_id=OuterRef("pk"), reviewer=user, stage__in=stages, status__in=states
    )
    return Program.objects.filter(Exists(tasks))


def get_program(user, pk, scope="own", lock=False):
    query = scoped(user, scope)
    if lock:
        query = query.select_for_update()
    try:
        return query.get(pk=pk)
    except Program.DoesNotExist:
        raise NotFound()


def check_query(request, allowed, repeated=()):
    if set(request.query_params) - set(allowed):
        raise DomainError("BAD_REQUEST", "Unknown query parameters.", 400)
    for key in request.query_params:
        values = request.query_params.getlist(key)
        if key not in repeated and len(values) != 1:
            raise DomainError(
                "BAD_REQUEST", "This query parameter accepts one value.", 400
            )
        limit = 100 if key == "q" else 64 if key.endswith("Id") else 200
        if len(values) > 100 or any(not v or len(v) > limit for v in values):
            raise DomainError("VALIDATION_FAILED", "Invalid query value.", 422)


def integer(request, key, default, low, high):
    try:
        value = int(request.query_params.get(key, default))
    except (ValueError, TypeError):
        raise DomainError("VALIDATION_FAILED", "Invalid " + key + ".", 422)
    if not low <= value <= high:
        raise DomainError("VALIDATION_FAILED", "Invalid " + key + ".", 422)
    return value


def paginated(request, query, serialize):
    page = integer(request, "page", 1, 1, 2147483647)
    size = integer(request, "pageSize", 20, 1, 100)
    total = query.count()
    return {
        "data": [serialize(item) for item in query[(page - 1) * size : page * size]],
        "meta": {
            **meta(request),
            "page": page,
            "pageSize": size,
            "totalItems": total,
            "totalPages": math.ceil(total / size),
            "hasNextPage": page * size < total,
        },
    }


FILTERS = [
    "q",
    "programNumber",
    "status",
    "locationId",
    "programTypeId",
    "periodStartFrom",
    "periodStartTo",
]
BOFILTERS = ["ownerId", "checkerId", "acknowledgerId", "approverId"]
REPEATED = ["status", "locationId", "checkerId", "acknowledgerId", "approverId"]


def filter_programs(request, query, backoffice=False):
    check_query(
        request,
        FILTERS + ["page", "pageSize", "sort"] + (BOFILTERS if backoffice else []),
        REPEATED,
    )
    params = request.query_params
    q = params.get("q", "").strip()
    if len(q) > 100:
        raise DomainError("VALIDATION_FAILED", "Search text is too long.", 422)
    if q:
        query = query.filter(
            Q(program_name__icontains=q) | Q(program_number__icontains=q)
        )
    for key, field in [
        ("programNumber", "program_number"),
        ("programTypeId", "program_type_id"),
        ("ownerId", "owner_id"),
    ]:
        if params.get(key):
            query = query.filter(**{field: params[key]})
    states = params.getlist("status")
    if set(states) - set(STATUSES):
        raise DomainError("VALIDATION_FAILED", "Unknown status.", 422)
    if states:
        query = query.filter(status__in=states)
    if params.getlist("locationId"):
        query = query.filter(locations__id__in=params.getlist("locationId"))
    dates = {}
    for key, lookup in [
        ("periodStartFrom", "period_start__gte"),
        ("periodStartTo", "period_start__lte"),
    ]:
        if key in params:
            try:
                dates[key] = date.fromisoformat(params[key])
            except ValueError:
                raise DomainError("VALIDATION_FAILED", "Invalid execution date.", 422)
            query = query.filter(**{lookup: dates[key]})
    if len(dates) == 2 and dates["periodStartFrom"] > dates["periodStartTo"]:
        raise DomainError("VALIDATION_FAILED", "Execution date range is reversed.", 422)
    for key, stage in [
        ("checkerId", "checker"),
        ("acknowledgerId", "acknowledgement"),
        ("approverId", "approval"),
    ]:
        if params.getlist(key):
            query = query.filter(
                review_tasks__stage=stage,
                review_tasks__reviewer_id__in=params.getlist(key),
            )
    sorts = {
        "-createdAt": "-created_at",
        "createdAt": "created_at",
        "-updatedAt": "-updated_at",
        "updatedAt": "updated_at",
        "programNumber": "program_number",
    }
    sort = params.get("sort", "-createdAt")
    if sort not in sorts:
        raise DomainError("VALIDATION_FAILED", "Unknown sort.", 422)
    return (
        query.select_related("owner", "program_type")
        .prefetch_related("locations", "review_tasks")
        .distinct()
        .order_by(sorts[sort], "id")
    )
