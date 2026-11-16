from collections import Counter

from common.text import cell_hash, normalize_value, rarity_weight


def fingerprint_dataframe(df, columns, salt):
    """Build cell level fingerprints for a dataframe.

    Fingerprints are hashes of normalized values. The column name is not
    part of the hash, so a renamed header or a dropped column does not
    break matching. Weights come from in file frequency: rare values such
    as emails and identity numbers dominate common values such as cities.
    """
    column_types = {col["name"]: col.get("pii_type", "OTHER") for col in columns}
    row_count = len(df)
    cells = []
    row_hashes = []
    row_hashes_by_column = {name: [] for name in df.columns}
    value_index = {}

    for row_index in range(row_count):
        row_hashes.append([])

    for column_name in df.columns:
        pii_type = column_types.get(column_name, "OTHER")
        normalized = [normalize_value(value) for value in df[column_name].tolist()]
        counts = Counter(value for value in normalized if value)
        column_hash_cache = {}
        for value, frequency in counts.items():
            hashed = cell_hash(salt, value)
            column_hash_cache[value] = hashed
            weight = rarity_weight(row_count, frequency)
            cells.append(
                {
                    "column_name": column_name,
                    "value_hash": hashed,
                    "weight": weight,
                    "count": frequency,
                    "pii_type": pii_type,
                }
            )
            existing = value_index.get(hashed)
            if existing is None:
                value_index[hashed] = {"weight": weight, "columns": {column_name}}
            else:
                existing["weight"] = max(existing["weight"], weight)
                existing["columns"].add(column_name)

        column_hashes = []
        for row_index, value in enumerate(normalized):
            hashed = column_hash_cache.get(value) if value else None
            column_hashes.append(hashed)
            row_hashes_by_column[column_name].append(hashed)
            if hashed:
                row_hashes[row_index].append(hashed)

    non_empty_cells = sum(len(hashes) for hashes in row_hashes)
    return {
        "cells": cells,
        "value_index": value_index,
        "row_hashes": row_hashes,
        "row_hashes_by_column": row_hashes_by_column,
        "row_count": row_count,
        "cell_count": non_empty_cells,
        "unique_cell_count": len(value_index),
    }
