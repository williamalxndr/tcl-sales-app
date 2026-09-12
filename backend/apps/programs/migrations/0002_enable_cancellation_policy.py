from django.db import migrations, models

import apps.programs.models


def enable_cancellation(apps, schema_editor):
    policy = apps.get_model("programs", "WorkflowPolicy")
    allowed = [
        "draft",
        "pendingChecker",
        "pendingAcknowledgement",
        "pendingApproval",
    ]
    policy.objects.filter(pk=1).update(cancellation_states=allowed)


class Migration(migrations.Migration):
    dependencies = [("programs", "0001_initial")]

    operations = [
        migrations.RunPython(enable_cancellation, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="workflowpolicy",
            name="cancellation_states",
            field=models.JSONField(
                default=apps.programs.models.default_cancellation_states
            ),
        ),
    ]
