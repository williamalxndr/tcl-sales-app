from django.urls import path

from apps.core.views import LiveView, ReadyView

urlpatterns = [
    path("api/v1/health/live", LiveView.as_view(), name="health-live"),
    path("api/v1/health/ready", ReadyView.as_view(), name="health-ready"),
]

handler400 = "apps.core.api.bad_request"
handler403 = "apps.core.api.forbidden"
handler404 = "apps.core.api.not_found"
handler500 = "apps.core.api.server_error"
