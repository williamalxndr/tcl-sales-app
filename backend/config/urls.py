from apps.accounts import views as accounts
from apps.core.views import LiveView, ReadyView
from apps.programs import pdf, uploads
from apps.programs import views as programs
from django.urls import path

urlpatterns = [
    path("api/v1/health/live", LiveView.as_view(), name="health-live"),
    path("api/v1/health/ready", ReadyView.as_view(), name="health-ready"),
    path("api/v1/auth/csrf", accounts.CsrfView.as_view()),
    path("api/v1/auth/login", accounts.LoginView.as_view()),
    path("api/v1/auth/refresh", accounts.RefreshView.as_view()),
    path("api/v1/auth/logout", accounts.LogoutView.as_view()),
    path("api/v1/users/me", accounts.ProfileView.as_view()),
    path("api/v1/admin/employees", accounts.SuperadminEmployeesView.as_view()),
    path(
        "api/v1/admin/employees/<str:employeeId>",
        accounts.SuperadminEmployeeView.as_view(),
    ),
    path(
        "api/v1/admin/employees/<str:employeeId>/access",
        accounts.SuperadminEmployeeAccessView.as_view(),
    ),
    path(
        "api/v1/admin/employees/<str:employeeId>/signatures",
        accounts.SuperadminEmployeeSignaturesView.as_view(),
    ),
    path(
        "api/v1/admin/employees/<str:employeeId>/checker",
        accounts.SuperadminEmployeeCheckerView.as_view(),
    ),
    path("api/v1/master-data/locations", programs.LocationsView.as_view()),
    path("api/v1/master-data/program-types", programs.ProgramTypesView.as_view()),
    path("api/v1/program-submissions", programs.OwnProgramsView.as_view()),
    path(
        "api/v1/program-submissions/<str:submissionId>",
        programs.OwnProgramView.as_view(),
    ),
    path(
        "api/v1/program-submissions/<str:submissionId>/policy",
        programs.PolicyView.as_view(),
    ),
    path(
        "api/v1/program-submissions/<str:submissionId>/reviewer-options",
        programs.ReviewerOptionsView.as_view(),
    ),
    path(
        "api/v1/program-submissions/<str:submissionId>/submit",
        programs.SubmitView.as_view(),
    ),
    path(
        "api/v1/program-submissions/<str:submissionId>/cancel",
        programs.CancelView.as_view(),
    ),
    path(
        "api/v1/program-submissions/<str:submissionId>/revisions",
        programs.RevisionView.as_view(),
    ),
    path("api/v1/program-submissions/<str:submissionId>/pdf", pdf.PdfView.as_view()),
    path(
        "api/v1/program-submissions/<str:submissionId>/attachments",
        uploads.UploadView.as_view(),
    ),
    path(
        "api/v1/program-submissions/<str:submissionId>/attachments/<str:attachmentId>",
        uploads.AttachmentView.as_view(),
    ),
    path(
        "api/v1/program-submissions/<str:submissionId>/attachments/<str:attachmentId>/content",
        uploads.AttachmentContentView.as_view(),
    ),
    path(
        "api/v1/backoffice/program-submissions",
        programs.BackofficeProgramsView.as_view(),
    ),
    path("api/v1/backoffice/review-history", programs.ReviewHistoryView.as_view()),
    path(
        "api/v1/backoffice/filter-options/people", programs.FilterPeopleView.as_view()
    ),
    path(
        "api/v1/backoffice/program-submissions/<str:submissionId>",
        programs.BackofficeProgramView.as_view(),
    ),
    path(
        "api/v1/backoffice/program-submissions/<str:submissionId>/review-tasks/<str:taskId>/approve",
        programs.DecisionView.as_view(),
    ),
    path(
        "api/v1/backoffice/program-submissions/<str:submissionId>/review-tasks/<str:taskId>/reject",
        programs.RejectView.as_view(),
    ),
    path(
        "api/v1/backoffice/program-submissions/<str:submissionId>/review-tasks/<str:taskId>/delegate",
        programs.DelegateReviewTaskView.as_view(),
    ),
    path(
        "api/v1/backoffice/program-submissions/<str:submissionId>/pdf",
        pdf.BackofficePdfView.as_view(),
    ),
    path(
        "api/v1/backoffice/program-submissions/<str:submissionId>/attachments/<str:attachmentId>/content",
        uploads.BackofficeAttachmentContentView.as_view(),
    ),
]

handler400 = "apps.core.api.bad_request"
handler403 = "apps.core.api.forbidden"
handler404 = "apps.core.api.not_found"
handler500 = "apps.core.api.server_error"
