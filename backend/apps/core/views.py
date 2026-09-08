from django.db import DatabaseError, connection
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .api import error_payload, success


class LiveView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        return success(request, {"status": "ok"})


class ReadyView(LiveView):
    def get(self, request):
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        except DatabaseError:
            return Response(
                error_payload(request, "SERVICE_UNAVAILABLE", "The service is temporarily unavailable."),
                status=503,
                headers={"Retry-After": "5"},
            )
        return success(request, {"status": "ready", "database": "ok"})
