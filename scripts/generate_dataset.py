"""Generate the synthetic customer master used in the Ghost Copy demo.

Usage:
    python scripts/generate_dataset.py
    python scripts/generate_dataset.py --out demo_data --seed 42
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "backend"))

from demo.generator import (  # noqa: E402
    WATERMARK,
    generate_rows,
    manifest,
    to_csv_bytes,
    to_xlsx_bytes,
)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=str(REPO_ROOT / "demo_data"))
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    rows = generate_rows(seed=args.seed)
    xlsx_path = out_dir / "customer_master_v1.xlsx"
    csv_path = out_dir / "customer_master_v1.csv"
    manifest_path = out_dir / "manifest.json"

    xlsx_path.write_bytes(to_xlsx_bytes(rows))
    csv_path.write_bytes(to_csv_bytes(rows))
    manifest_path.write_text(json.dumps(manifest(rows, seed=args.seed), indent=2), encoding="utf-8")

    print("SALUS synthetic dataset generated")
    print(f"  rows: {len(rows)}")
    print(f"  xlsx: {xlsx_path}")
    print(f"  csv:  {csv_path}")
    print(f"  manifest: {manifest_path}")
    print(f"  watermark: {WATERMARK}")
    print("  canary rows: 5 (token CN-007, recipient vendor.acme@external.test)")


if __name__ == "__main__":
    main()
