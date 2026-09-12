from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [("programs", "0002_enable_cancellation_policy")]

    operations = [
        migrations.AddField(
            model_name="program",
            name="revised_from",
            field=models.OneToOneField(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.PROTECT,
                related_name="revision",
                to="programs.program",
            ),
        )
    ]
