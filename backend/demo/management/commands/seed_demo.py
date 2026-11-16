from django.core.management.base import BaseCommand

from demo.seed import seed_demo


class Command(BaseCommand):
    help = "Create the synthetic Acme Traders demo organization, dataset, events, and models."

    def add_arguments(self, parser):
        parser.add_argument(
            "--reset",
            action="store_true",
            help="Delete the demo organization and rebuild it from scratch.",
        )

    def handle(self, *args, **options):
        result = seed_demo(reset=options["reset"])
        self.stdout.write(self.style.SUCCESS("SALUS demo seed"))
        for key, value in result.items():
            if key == "manifest":
                continue
            self.stdout.write(f"  {key}: {value}")
