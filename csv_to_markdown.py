#!/usr/bin/env python3
"""
CSV Splitter + Pandoc Markdown Converter

Splits a multi-row CSV into individual CSV files (one per row), then converts
each to Markdown using pandoc. Filenames are derived from the first column value.
"""

import argparse
import csv
import os
import re
import subprocess
import sys
from pathlib import Path


def sanitize_filename(name: str) -> str:
    """Sanitize a string to be safe for use as a filename."""
    sanitized = re.sub(r"[^\w\s-]", "", name)
    sanitized = re.sub(r"[-\s]+", "_", sanitized)
    sanitized = sanitized.strip("_")
    return sanitized or "unnamed"


def get_unique_filename(directory: Path, base_name: str, extension: str) -> str:
    """Generate a unique filename, appending suffix if necessary."""
    filename = f"{base_name}{extension}"
    filepath = directory / filename

    if not filepath.exists():
        return filename

    counter = 1
    while True:
        filename = f"{base_name}_{counter}{extension}"
        filepath = directory / filename
        if not filepath.exists():
            return filename
        counter += 1


def write_single_row_csv(filepath: Path, header: list, row: list) -> None:
    """Write a CSV file with header and single data row."""
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerow(row)


def convert_csv_to_markdown(csv_path: Path, md_path: Path) -> bool:
    """Convert CSV to Markdown using pandoc."""
    try:
        result = subprocess.run(
            ["pandoc", str(csv_path), "-o", str(md_path)],
            capture_output=True,
            text=True,
        )
        return result.returncode == 0
    except FileNotFoundError:
        print("Error: pandoc is not installed or not in PATH.", file=sys.stderr)
        sys.exit(1)


def process_csv(input_file: str, output_dir: str) -> tuple[int, int]:
    """
    Process the input CSV file.
    Returns tuple of (csv_count, md_count).
    """
    input_path = Path(input_file)

    if not input_path.exists():
        print(f"Error: Input file '{input_file}' not found.", file=sys.stderr)
        sys.exit(1)

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    with open(input_path, "r", newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)

        if not header:
            print("Error: CSV file is empty or has no header.", file=sys.stderr)
            sys.exit(1)

        csv_count = 0
        md_count = 0
        used_names = set()

        for row_num, row in enumerate(reader, start=2):
            if not row:
                continue

            first_col_value = row[0] if row else ""
            base_name = sanitize_filename(str(first_col_value))

            if not base_name:
                base_name = f"row_{row_num}"

            if base_name in used_names:
                filename_base = Path(
                    get_unique_filename(output_path, base_name, ".csv")
                ).stem
            else:
                filename_base = base_name
                used_names.add(base_name)

            csv_filename = f"{filename_base}.csv"
            csv_filepath = output_path / csv_filename

            write_single_row_csv(csv_filepath, header, row)
            csv_count += 1

            md_filename = f"{filename_base}.md"
            md_filepath = output_path / md_filename

            if convert_csv_to_markdown(csv_filepath, md_filepath):
                md_count += 1
                print(f"  {csv_filename} -> {md_filename}")
            else:
                print(
                    f"  {csv_filename} -> FAILED to convert to markdown",
                    file=sys.stderr,
                )

        return csv_count, md_count


def main():
    parser = argparse.ArgumentParser(
        description="Split CSV into single-row files and convert to Markdown via pandoc."
    )
    parser.add_argument("input_file", help="Path to the input CSV file")
    parser.add_argument(
        "-o",
        "--output-dir",
        default="./output",
        help="Output directory for generated files (default: ./output)",
    )

    args = parser.parse_args()

    print(f"Processing: {args.input_file}")
    print(f"Output directory: {args.output_dir}")
    print()

    csv_count, md_count = process_csv(args.input_file, args.output_dir)

    print()
    print(f"Complete: {csv_count} CSV file(s), {md_count} Markdown file(s) created.")


if __name__ == "__main__":
    main()
