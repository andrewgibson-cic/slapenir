#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path


def convert_to_markdown(input_dir, output_dir=None):
    input_path = Path(input_dir)
    if output_dir is None:
        output_dir = input_path / "markdown"
    else:
        output_dir = Path(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)

    csv_files = list(input_path.glob("*.csv"))

    for csv_file in csv_files:
        first_col_value = csv_file.stem
        md_file = output_dir / f"{first_col_value}.md"

        with open(csv_file, "r", encoding="utf-8") as f:
            lines = f.readlines()
            if len(lines) >= 2:
                first_data_line = lines[1].strip()
                parts = (
                    list(csv.reader([first_data_line]))[0]
                    if "," in first_data_line
                    else [first_data_line]
                )
                first_col_value = parts[0] if parts else csv_file.stem

        import csv

        with open(csv_file, "r", encoding="utf-8") as f:
            reader = csv.reader(f)
            next(reader)
            first_row = next(reader, None)
            if first_row:
                first_col_value = first_row[0]

        result = subprocess.run(
            ["pandoc", str(csv_file), "-t", "markdown"], capture_output=True, text=True
        )

        if result.returncode != 0:
            print(f"Error converting {csv_file}: {result.stderr}")
            continue

        with open(md_file, "w", encoding="utf-8") as f:
            f.write(f"# {first_col_value}\n\n")
            f.write(result.stdout)

        print(f"Created {md_file}")

    print(f"Converted {len(csv_files)} files to {output_dir}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_to_md.py <input_dir> [output_dir]")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None
    convert_to_markdown(input_dir, output_dir)
