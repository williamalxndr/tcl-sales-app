from rest_framework import serializers

from apps.core.serializers import StrictSerializer


class LoginSerializer(StrictSerializer):
    email = serializers.EmailField(max_length=254)
    password = serializers.CharField(max_length=128, trim_whitespace=False)
    clientType = serializers.ChoiceField(choices=["native", "web"], default="native")


class RefreshSerializer(StrictSerializer):
    refreshToken = serializers.CharField(
        min_length=32, max_length=2048, required=False, trim_whitespace=False
    )


def profile(user):
    return {
        "id": user.pk,
        "fullName": user.full_name,
        "employeeNumber": user.employee_number or "",
        "email": user.email,
        "jobTitle": user.job_title or None,
        "status": "active" if user.is_active else "disabled",
        "roles": list(user.role_grants.order_by("role").values_list("role", flat=True)),
        "timeZone": user.time_zone,
        "locationIds": list(user.locations.order_by("id").values_list("id", flat=True)),
        "checkerId": user.checker_id,
    }
