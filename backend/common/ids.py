import re

from django.db import transaction


def next_public_id(model, field, prefix, floor=None):
    """Return the next human readable id such as SL-9310.

    The demo runs at low write volume, so a max scan is enough.
    A floor keeps the seeded ids and the ids created during the
    demo in separate ranges.
    """
    start = (floor - 1) if floor else 0
    qs = model.objects.filter(**{field + "__startswith": prefix + "-"}).values_list(field, flat=True)
    highest = start
    for value in qs:
        match = re.search(r"(\d+)$", value or "")
        if match:
            highest = max(highest, int(match.group(1)))
    return f"{prefix}-{highest + 1}"


def allocate_public_id(model, field, prefix, floor=None):
    with transaction.atomic():
        return next_public_id(model, field, prefix, floor=floor)
