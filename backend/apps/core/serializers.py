from rest_framework import serializers

from .services import DomainError


class StrictSerializer(serializers.Serializer):
    def to_internal_value(self, data):
        if not isinstance(data, dict):
            raise DomainError("BAD_REQUEST", "Expected a JSON object.", 400)
        for key, value in data.items():
            field = self.fields.get(key)
            if (
                value is not None
                and isinstance(field, (serializers.CharField, serializers.DateField))
                and not isinstance(value, str)
            ):
                raise serializers.ValidationError({key: "Expected a string."})
        unknown = set(data) - set(self.fields)
        if unknown:
            raise DomainError(
                "BAD_REQUEST",
                "Unknown request fields.",
                400,
                [
                    {
                        "field": str(k),
                        "code": "UNKNOWN_FIELD",
                        "message": "This field is not accepted.",
                    }
                    for k in sorted(unknown)
                ],
            )
        return super().to_internal_value(data)
