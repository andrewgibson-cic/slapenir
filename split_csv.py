#!/usr/bin/env python3
import csv
import sys
import os
from pathlib import Path


def split_csv(input_file, output_dir=None):
    input_path = Path(input_file)
    if output_dir is None:
        output_dir = input_path.parent / f"{input_path.stem}_split"
    else:
        output_dir = Path(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    with open(input_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        headers = next(reader)

        files_created = []
        for row in reader:
            if not row or all(cell.strip() == "" for cell in row):
                continue

            first_col_value = row[0].strip() if row else "unknown"
            safe_filename = "".join(
                c if c.isalnum() or c in ("-", "_") else "_" for c in first_col_value
            )
            if not safe_filename:
                safe_filename = "unknown"

            output_file = output_dir / f"{safe_filename}.csv"
            counter = 1
            while output_file.exists():
                output_file = output_dir / f"{safe_filename}_{counter}.csv"
                counter += 1

            with open(output_file, "w", newline="", encoding="utf-8") as out_f:
                writer = csv.writer(out_f)
                writer.writerow(headers)
                writer.writerow(row)

            files_created.append(output_file)

    print(f"Created {len(files_created)} files in {output_dir}")
    return output_dir


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python split_csv.py <input.csv> [output_dir]")
        sys.exit(1)

    input_file = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None
    split_csv(input_file, output_dir)
