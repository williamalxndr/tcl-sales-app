from django.core.management.base import BaseCommand

from apps.programs.models import Location, ProgramType


class Command(BaseCommand):
    help = "Create the observed BSD/Bekasi and Bundling/Diskon master records; no accounts or submissions."

    def handle(self, *args, **options):
        for code, name in [("BSD", "BSD"), ("BEKASI", "Bekasi")]:
            Location.objects.get_or_create(code=code, defaults={"name": name})
        for code, name in [("bundling", "Bundling"), ("diskon", "Diskon")]:
            ProgramType.objects.get_or_create(code=code, defaults={"name": name})
        self.stdout.write("Master data present.")
