#!/usr/bin/env python
import json
import sys
from openpyxl import load_workbook

if len(sys.argv) < 2:
    print("Usage: excel-to-json.py <file.xlsx> [sheet_name]")
    sys.exit(1)

file_path = sys.argv[1]
sheet_name = sys.argv[2] if len(sys.argv) > 2 else None

try:
    wb = load_workbook(file_path)

    if sheet_name:
        sheets = [sheet_name]
    else:
        sheets = wb.sheetnames

    results = {}

    for sname in sheets:
        ws = wb[sname]
        data = []

        # Get headers from first row
        headers = []
        for cell in ws[1]:
            headers.append(cell.value)

        # Get data rows
        for row_idx in range(2, ws.max_row + 1):
            row_data = {}
            for col_idx, header in enumerate(headers, 1):
                cell = ws.cell(row=row_idx, column=col_idx)
                row_data[header] = cell.value
            data.append(row_data)

        results[sname] = data

    print(json.dumps(results, indent=2, default=str))

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
    sys.exit(1)
