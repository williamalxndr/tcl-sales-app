from django.contrib.auth import get_user_model, password_validation
from django.core.exceptions import ValidationError as DjangoValidationError
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


class EmployeeCreateSerializer(StrictSerializer):
    email = serializers.EmailField(max_length=254)
    fullName = serializers.CharField(max_length=150)
    employeeNumber = serializers.CharField(max_length=50)
    jobTitle = serializers.CharField(max_length=150, required=False, allow_blank=True)
    timeZone = serializers.CharField(max_length=64, default="Asia/Jakarta")
    initialPassword = serializers.CharField(
        max_length=128, trim_whitespace=False, write_only=True
    )

    def validate_email(self, value):
        value = value.strip().lower()
        if get_user_model().objects.filter(email=value).exists():
            raise serializers.ValidationError("An employee with this email exists.")
        return value

    def validate_employeeNumber(self, value):
        value = value.strip()
        if get_user_model().objects.filter(employee_number=value).exists():
            raise serializers.ValidationError(
                "An employee with this employee number exists."
            )
        return value

    def validate(self, attrs):
        candidate = get_user_model()(
            email=attrs["email"],
            full_name=attrs["fullName"].strip(),
            employee_number=attrs["employeeNumber"],
        )
        try:
            password_validation.validate_password(
                attrs["initialPassword"], user=candidate
            )
        except DjangoValidationError as error:
            raise serializers.ValidationError(
                {"initialPassword": list(error.messages)}
            ) from error
        return attrs


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
