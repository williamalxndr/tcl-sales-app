from rest_framework import serializers

from apps.core.serializers import StrictSerializer


class MoneySerializer(StrictSerializer):
    currency = serializers.ChoiceField(choices=["IDR"])
    amount = serializers.RegexField(r"^(0|[1-9][0-9]{0,13})\.[0-9]{2}$")


class DraftSerializer(StrictSerializer):
    programName = serializers.CharField(max_length=200, allow_null=True, required=False)
    programTypeId = serializers.CharField(
        max_length=64, allow_null=True, required=False
    )
    estimatedCost = MoneySerializer(allow_null=True, required=False)
    locationIds = serializers.ListField(
        child=serializers.CharField(max_length=64), max_length=100, required=False
    )
    periodStart = serializers.DateField(allow_null=True, required=False)
    periodEnd = serializers.DateField(allow_null=True, required=False)
    acknowledgerIds = serializers.ListField(
        child=serializers.CharField(max_length=64), max_length=4, required=False
    )
    approverIds = serializers.ListField(
        child=serializers.CharField(max_length=64), max_length=5, required=False
    )

    def validate(self, data):
        for name in ["locationIds", "acknowledgerIds", "approverIds"]:
            if name in data and len(data[name]) != len(set(data[name])):
                raise serializers.ValidationError(
                    {name: "Duplicate IDs are not allowed."}
                )
        if not data and self.context.get("patch"):
            raise serializers.ValidationError("Provide at least one field.")
        return data


class DecisionSerializer(StrictSerializer):
    note = serializers.CharField(
        max_length=2000, allow_null=True, allow_blank=True, required=False
    )


class CancellationSerializer(StrictSerializer):
    reason = serializers.CharField(max_length=2000)


class ReviewerAssignmentSerializer(StrictSerializer):
    reviewerId = serializers.CharField(max_length=64)
