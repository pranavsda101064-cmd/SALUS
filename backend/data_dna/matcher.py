import math
from collections import defaultdict

from django.conf import settings

from assets.models import Asset
from common.ids import next_public_id
from data_dna.models import CanaryIssuance, CellFingerprint, MatchRecord

RARE_WEIGHT = 3.0
DEFAULT_MATCH_THRESHOLD = 0.3


def match_threshold():
    return float(getattr(settings, "SALUS_MATCH_THRESHOLD", DEFAULT_MATCH_THRESHOLD))


def rare_threshold(row_count):
    """Rarity is relative to the source size.

    A value that appears once in five rows is unusual. A city that appears
    twenty times in one hundred rows is not. The stored weights stay the
    same; this threshold only decides whether a shared cell counts as
    evidence strong enough to corroborate a row.
    """
    n = max(int(row_count or 0), 1)
    return max(1.0, 0.5 * math.log(1 + n))


def _load_source_index(source_asset):
    rows = CellFingerprint.objects.filter(asset=source_asset).values_list(
        "column_name", "value_hash", "weight"
    )
    index = {}
    by_column = defaultdict(list)
    for column_name, value_hash, weight in rows:
        current = index.get(value_hash)
        if current is None or weight > current["weight"]:
            index[value_hash] = {"weight": weight, "columns": {column_name}}
        else:
            current["columns"].add(column_name)
        by_column[column_name].append(value_hash)
    return index, by_column


def _canary_for_source(source_asset, query_fp, query_hashes):
    issuances = CanaryIssuance.objects.filter(asset=source_asset)
    best = None
    for issuance in issuances:
        canary_hashes = set(issuance.value_hashes or [])
        found = canary_hashes & query_hashes
        if not found:
            continue
        matched_rows = 0
        for row in query_fp["row_hashes"]:
            if any(hashed in found for hashed in row):
                matched_rows += 1
        entry = {
            "found": True,
            "canary_id": issuance.public_id,
            "token": issuance.token,
            "recipient": issuance.recipient,
            "issued_at": issuance.issued_at.isoformat().replace("+00:00", "Z"),
            "matched_values": len(found),
            "matched_rows": matched_rows,
        }
        if best is None or entry["matched_values"] > best["matched_values"]:
            best = entry
    return best or {"found": False}


def match_one(query_asset, query_fp, source_asset):
    source_index, source_by_column = _load_source_index(source_asset)
    if not source_index:
        return None

    query_index = query_fp["value_index"]
    query_hashes = set(query_index)
    shared = query_hashes & set(source_index)

    shared_source_weight = sum(source_index[hashed]["weight"] for hashed in shared)
    total_source_weight = sum(entry["weight"] for entry in source_index.values()) or 1.0
    total_query_weight = sum(
        (source_index[hashed]["weight"] if hashed in source_index else entry["weight"])
        for hashed, entry in query_index.items()
    ) or 1.0

    containment = round(shared_source_weight / total_query_weight, 4)
    cell_recall = round(shared_source_weight / total_source_weight, 4)

    rare_cutoff = rare_threshold(source_asset.row_count)
    matched_cells = 0
    matched_rows = 0
    rare_row_count = 0
    for row in query_fp["row_hashes"]:
        hits = 0
        rare_hits = 0
        for hashed in row:
            entry = source_index.get(hashed)
            if entry is None:
                continue
            hits += 1
            if entry["weight"] >= rare_cutoff:
                rare_hits += 1
        matched_cells += hits
        if rare_hits >= 1 or hits >= 3:
            matched_rows += 1
        if rare_hits >= 1:
            rare_row_count += 1

    recall = round(matched_rows / source_asset.row_count, 4) if source_asset.row_count else 0.0

    matched_columns = []
    column_report = []
    for column_name, hashes in query_fp["row_hashes_by_column"].items():
        non_empty = [hashed for hashed in hashes if hashed]
        if not non_empty:
            continue
        hits = sum(1 for hashed in non_empty if hashed in source_index)
        ratio = hits / len(non_empty)
        column_report.append(
            {"column": column_name, "matched": hits, "total": len(non_empty), "ratio": round(ratio, 3)}
        )
        if ratio >= 0.5:
            matched_columns.append(column_name)

    dropped_columns = []
    for column_name, hashes in source_by_column.items():
        if not hashes:
            continue
        present = sum(1 for hashed in hashes if hashed in query_hashes)
        if present / len(hashes) < 0.05:
            dropped_columns.append(column_name)

    canary = _canary_for_source(source_asset, query_fp, query_hashes)

    rare_shared = sum(
        1 for hashed in shared if source_index[hashed]["weight"] >= rare_cutoff
    )
    confidence = 1 - math.exp(-rare_shared / 40) if rare_shared else 0.0
    match_score = round(min(0.999, 0.7 * containment + 0.3 * confidence), 3)

    exact_copy = bool(
        query_asset.exact_sha256
        and source_asset.exact_sha256
        and query_asset.exact_sha256 == source_asset.exact_sha256
    )
    if exact_copy:
        match_score = 1.0
        containment = 1.0
        recall = 1.0

    evidence = {
        "shared_unique_values": len(shared),
        "rare_shared_values": rare_shared,
        "source_unique_values": len(source_index),
        "query_unique_values": len(query_index),
        "cell_recall": cell_recall,
        "row_recall": recall,
        "rare_matched_rows": rare_row_count,
        "source_row_count": source_asset.row_count,
        "query_row_count": query_asset.row_count,
        "column_report": column_report[:20],
        "exact_copy": exact_copy,
        "watermark_on_source": source_asset.watermark,
        "watermark_on_query": query_asset.watermark,
        "watermark_stripped": bool(source_asset.watermark and not query_asset.watermark),
        "canary": canary,
    }

    return {
        "match_id": next_public_id(MatchRecord, "public_id", "MT", floor=2001),
        "query_asset_id": query_asset.public_id,
        "source_asset_id": source_asset.public_id,
        "method": "CELL_HASH_WEIGHTED_V1",
        "match_score": match_score,
        "containment": containment,
        "recall_vs_original": recall,
        "matched_rows": matched_rows,
        "matched_cells": matched_cells,
        "matched_columns": matched_columns,
        "dropped_columns": sorted(dropped_columns),
        "canary": canary,
        "evidence": evidence,
    }


def find_best_match(organization, query_asset, query_fp):
    sources = (
        Asset.objects.filter(organization=organization, kind="ORIGINAL", is_baseline=False)
        .exclude(pk=query_asset.pk)
        .order_by("created_at")
    )
    best = None
    best_source = None
    scanned = 0
    for source in sources:
        result = match_one(query_asset, query_fp, source)
        if result is None:
            continue
        scanned += 1
        if best is None or result["match_score"] > best["match_score"]:
            best = result
            best_source = source
    if best is None:
        return None, best_source, scanned

    evidence = best.get("evidence", {})
    if not evidence.get("exact_copy"):
        if best.get("matched_rows", 0) < 1 or evidence.get("rare_shared_values", 0) < 1:
            return None, best_source, scanned

    if best["match_score"] < match_threshold():
        return None, best_source, scanned
    match = MatchRecord.objects.create(
        public_id=best["match_id"],
        organization=organization,
        query_asset=query_asset,
        source_asset=best_source,
        method=best["method"],
        match_score=best["match_score"],
        containment=best["containment"],
        recall_vs_original=best["recall_vs_original"],
        matched_rows=best["matched_rows"],
        matched_cells=best["matched_cells"],
        matched_columns=best["matched_columns"],
        dropped_columns=best["dropped_columns"],
        canary=best["canary"],
        evidence=best["evidence"],
    )
    return match, best_source, scanned
