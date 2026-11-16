"""Create the Ghost Copy from the synthetic customer master.

The script renames the file, converts XLSX to CSV, removes the watermark,
drops three columns, drops 700 rows, and deliberately keeps three canary
rows so the demo can show provenance. All data is synthetic.

Usage:
    python scripts/ghost_copy.py
"""

import argparse
import json
import random
import sys
from pathlib import Path

import pandas as pd

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "backend"))

from demo.generator import GHOST_DROP_COLUMNS, WATERMARK  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source", default=str(REPO_ROOT / "demo_data" / "customer_master_v1.xlsx")
    )
    parser.add_argument(
        "--out", default=str(REPO_ROOT / "demo_data" / "clients_export_final.csv")
    )
    parser.add_argument("--rows", type=int, default=300)
    parser.add_argument("--canary-rows", type=int, default=3)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    source_path = Path(args.source)
    if not source_path.exists():
        raise SystemExit(
            f"Source file not found: {source_path}\nRun scripts/generate_dataset.py first."
        )

    df = pd.read_excel(source_path, dtype=str, keep_default_na=False, engine="openpyxl")
    original_rows, original_columns = len(df), list(df.columns)

    canary_mask = df["customer_ref"].astype(str).str.startswith("CN-007")
    canary_rows = df[canary_mask]
    normal_rows = df[~canary_mask]

    keep_canary = min(args.canary_rows, len(canary_rows))
    canary_sample = canary_rows.sample(n=keep_canary, random_state=args.seed)
    remaining = max(args.rows - keep_canary, 0)
    normal_sample = normal_rows.sample(
        n=min(remaining, len(normal_rows)), random_state=args.seed
    )

    ghost = pd.concat([normal_sample, canary_sample]).sample(
        frac=1.0, random_state=args.seed
    )
    ghost = ghost.drop(columns=GHOST_DROP_COLUMNS, errors="ignore")

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    ghost.to_csv(out_path, index=False)

    summary = {
        "source_file": source_path.name,
        "ghost_file": out_path.name,
        "original_rows": original_rows,
        "ghost_rows": len(ghost),
        "original_columns": original_columns,
        "ghost_columns": list(ghost.columns),
        "dropped_columns": GHOST_DROP_COLUMNS,
        "canary_rows_kept": int(keep_canary),
        "canary_values": canary_sample["customer_ref"].tolist(),
        "watermark_removed": WATERMARK,
        "format": "XLSX to CSV",
        "renamed_from": source_path.name,
        "renamed_to": out_path.name,
    }
    manifest_path = out_path.parent / "ghost_manifest.json"
    manifest_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print("SALUS ghost copy created")
    print(f"  source: {source_path}")
    print(f"  ghost:  {out_path}")
    print(f"  rows: {len(ghost)} of {original_rows}")
    print(f"  columns kept: {list(ghost.columns)}")
    print(f"  dropped: {GHOST_DROP_COLUMNS}")
    print(f"  canary rows kept: {keep_canary} ({canary_sample['customer_ref'].tolist()})")
    print(f"  watermark removed: {WATERMARK} (CSV has no document properties)")
    print(f"  manifest: {manifest_path}")
    print("  upload this CSV in the SALUS investigation screen.")


if __name__ == "__main__":
    main()
