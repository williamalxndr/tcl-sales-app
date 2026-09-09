import logging

from django.db import OperationalError
from django.http import JsonResponse
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler

logger = logging.getLogger(__name__)


def meta(request):
    return {"requestId": request.request_id}


def success(request, data, status=200):
    return Response({"data": data, "meta": meta(request)}, status=status)


def error_payload(request, code, message, details=None):
    return {
        "error": {"code": code, "message": message, "details": details or []},
        "meta": meta(request),
    }


def validation_details(value, field=None):
    details = []
    if isinstance(value, dict):
        for key, child in value.items():
            name = f"{field}.{key}" if field else key
            details.extend(
                validation_details(child, None if key == "non_field_errors" else name)
            )
    elif isinstance(value, list):
        for index, child in enumerate(value):
            name = f"{field}.{index}" if field is not None else str(index)
            details.extend(
                validation_details(
                    child, name if isinstance(child, (dict, list)) else field
                )
            )
    else:
        details.append(
            {
                "field": field,
                "code": str(getattr(value, "code", "invalid")).upper(),
                "message": str(value),
            }
        )
    return details


def exception_handler(exc, context):
    request = context["request"]
    if isinstance(exc, OperationalError):
        return Response(
            error_payload(
                request,
                "SERVICE_UNAVAILABLE",
                "The database is temporarily unavailable.",
            ),
            status=503,
            headers={"Retry-After": "5"},
        )
    from .services import DomainError

    if isinstance(exc, DomainError):
        headers = (
            {"WWW-Authenticate": "Bearer"}
            if exc.status_code == 401
            else {"Retry-After": "5"}
            if exc.status_code == 503
            else {}
        )
        return Response(
            error_payload(request, exc.code, exc.message, exc.details),
            status=exc.status_code,
            headers=headers,
        )
    response = drf_exception_handler(exc, context)
    if response is None:
        # No exception text or request body in the client response/log message.
        logger.error(
            "Unhandled API error requestId=%s type=%s",
            request.request_id,
            type(exc).__name__,
        )
        return Response(
            error_payload(request, "INTERNAL_ERROR", "An unexpected error occurred."),
            status=500,
        )
    if isinstance(exc, ValidationError):
        response.status_code = 422
        response.data = error_payload(
            request,
            "VALIDATION_FAILED",
            "One or more fields are invalid.",
            validation_details(response.data),
        )
        return response
    codes = {
        400: ("BAD_REQUEST", "The request is malformed."),
        401: ("UNAUTHENTICATED", "Authentication is required."),
        403: ("FORBIDDEN", "Access is denied."),
        404: ("NOT_FOUND", "Resource not found."),
        405: ("METHOD_NOT_ALLOWED", "This method is not allowed."),
        406: ("NOT_ACCEPTABLE", "The requested response format is unavailable."),
        415: ("UNSUPPORTED_MEDIA_TYPE", "The request media type is unsupported."),
        429: ("RATE_LIMITED", "Too many requests."),
    }
    code, message = codes.get(
        response.status_code, ("REQUEST_FAILED", "The request could not be completed.")
    )
    response.data = error_payload(request, code, message)
    return response


def bad_request(request, exception):
    return JsonResponse(
        error_payload(request, "BAD_REQUEST", "The request is malformed."), status=400
    )


def forbidden(request, exception):
    return JsonResponse(
        error_payload(request, "FORBIDDEN", "Access is denied."), status=403
    )


def not_found(request, exception):
    return JsonResponse(
        error_payload(request, "NOT_FOUND", "Resource not found."), status=404
    )


def server_error(request):
    return JsonResponse(
        error_payload(request, "INTERNAL_ERROR", "An unexpected error occurred."),
        status=500,
    )
