from unittest.mock import patch

from django.db import OperationalError, connection
from django.test import SimpleTestCase, TestCase, override_settings


class LiveTests(SimpleTestCase):
    def test_liveness_does_not_require_a_database(self):
        response = self.client.get("/api/v1/health/live")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["data"], {"status": "ok"})
        self.assertEqual(response.json()["meta"]["requestId"], response["X-Request-Id"])
        self.assertEqual(response["Cache-Control"], "no-store")

    def test_method_error_is_json(self):
        response = self.client.post(
            "/api/v1/health/live", {}, content_type="application/json"
        )
        self.assertEqual(response.status_code, 405)
        self.assertEqual(response.json()["error"]["code"], "METHOD_NOT_ALLOWED")

    @override_settings(DEBUG=False)
    def test_unknown_routes_are_json(self):
        response = self.client.get("/api/v1/does-not-exist")
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["error"]["code"], "NOT_FOUND")

    @override_settings(CORS_ALLOWED_ORIGINS=["http://localhost:3000"])
    def test_cors_preflight_allows_configured_flutter_web_origin_only(self):
        response = self.client.options(
            "/api/v1/health/live",
            HTTP_ORIGIN="http://localhost:3000",
            HTTP_ACCESS_CONTROL_REQUEST_METHOD="GET",
        )
        self.assertEqual(
            response["Access-Control-Allow-Origin"], "http://localhost:3000"
        )
        response = self.client.options(
            "/api/v1/health/live",
            HTTP_ORIGIN="https://untrusted.example",
            HTTP_ACCESS_CONTROL_REQUEST_METHOD="GET",
        )
        self.assertNotIn("Access-Control-Allow-Origin", response)


class ReadyTests(TestCase):
    def test_readiness_queries_mysql(self):
        self.assertEqual(connection.vendor, "mysql")
        response = self.client.get("/api/v1/health/ready")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["data"], {"status": "ready", "database": "ok"})

    def test_database_outage_is_sanitized(self):
        with patch(
            "apps.core.views.connection.cursor",
            side_effect=OperationalError("private database address"),
        ):
            response = self.client.get("/api/v1/health/ready")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json()["error"]["code"], "SERVICE_UNAVAILABLE")
        self.assertEqual(response["Retry-After"], "5")
        self.assertNotIn("private database address", response.content.decode())
