"""Lineage is derived, never invented.

Every edge carries a reference to a stored Event or a stored MatchRecord.
If no event or match exists, the edge does not exist.
"""


def _user_labels(actor_ids):
    from organizations.models import User

    ids = {actor_id for actor_id in actor_ids if actor_id}
    labels = {}
    for public_id, display_name, first_name, last_name, username in User.objects.filter(
        public_id__in=ids
    ).values_list("public_id", "display_name", "first_name", "last_name", "username"):
        full_name = f"{first_name} {last_name}".strip()
        labels[public_id] = display_name or full_name or username
    return {actor_id: labels.get(actor_id, actor_id) for actor_id in ids}


def build_lineage(incident):
    from events.models import Event

    evidence = incident.evidence or {}
    timeline = evidence.get("timeline_events", [])
    event_ids = [event.get("event_id") for event in timeline if event.get("event_id")]
    existing_ids = set(
        Event.objects.filter(
            organization=incident.organization, event_id__in=event_ids
        ).values_list("event_id", flat=True)
    )
    timeline = [event for event in timeline if event.get("event_id") in existing_ids]
    user_labels = _user_labels(event.get("actor_id") for event in timeline)
    match = incident.match
    source = incident.source_asset
    suspect = incident.suspect_asset

    nodes = {}
    edges = []

    def add_node(node_id, node_type, label, meta=None):
        if node_id not in nodes:
            nodes[node_id] = {
                "id": node_id,
                "type": node_type,
                "label": label,
                "meta": meta or {},
            }

    if source is not None:
        add_node(
            source.public_id,
            "ASSET",
            source.name,
            {"rows": source.row_count, "sensitivity": source.sensitivity_label},
        )
    if suspect is not None:
        add_node(
            suspect.public_id,
            "ASSET",
            suspect.name,
            {"rows": suspect.row_count, "suspect": True},
        )

    edge_counter = 0

    def add_edge(source_id, target_id, relation, ref_type, ref_id, label="", simulated=False):
        nonlocal edge_counter
        edge_counter += 1
        edges.append(
            {
                "id": f"LE-{edge_counter:02d}",
                "from": source_id,
                "to": target_id,
                "relation": relation,
                "label": label,
                "simulated": simulated,
                "ref": {"type": ref_type, "id": ref_id},
            }
        )

    for event in timeline:
        actor_id = event.get("actor_id")
        if not actor_id:
            continue
        add_node(actor_id, "USER", user_labels.get(actor_id, actor_id))
        action = event.get("action")
        simulated = bool(event.get("simulated"))
        if action in {"FILE_DOWNLOADED", "FILE_COPIED", "FILE_VIEWED"} and source is not None:
            add_edge(
                actor_id,
                source.public_id,
                action,
                "EVENT",
                event.get("event_id"),
                label=event.get("destination", ""),
                simulated=simulated,
            )
        elif action == "EXTERNAL_SHARE":
            destination = event.get("destination") or "unknown"
            add_node(destination, "DESTINATION", destination)
            add_edge(
                actor_id,
                destination,
                "SHARED_TO",
                "EVENT",
                event.get("event_id"),
                label="external share",
                simulated=simulated,
            )
        elif action == "SUSPECT_UPLOAD" and suspect is not None:
            add_edge(
                actor_id,
                suspect.public_id,
                "UPLOADED_FOR_INVESTIGATION",
                "EVENT",
                event.get("event_id"),
                label="intake",
                simulated=simulated,
            )

    if match is not None and source is not None and suspect is not None:
        add_edge(
            suspect.public_id,
            source.public_id,
            "DERIVED_FROM",
            "MATCH",
            match.public_id,
            label=f"{int(round(match.recall_vs_original * 100))} percent of rows, "
            f"{len(match.matched_columns)} matched columns",
            simulated=False,
        )

    return {
        "incident_id": incident.public_id,
        "nodes": list(nodes.values()),
        "edges": edges,
    }
