"""Send scan reports to DefectDojo.

Usage:  python tools/dojo_import.py FOLDER [ENGAGEMENT]
        python tools/dojo_import.py reports/
        python tools/dojo_import.py reports/pr "Vulnerable branch"
Reads the API key from the DD_API_KEY environment variable. Never put the
key in this file. DD_URL can point somewhere other than this machine.
"""
import os
import pathlib
import re
import sys

import requests

DD_URL = os.environ.get("DD_URL", "http://localhost:8080")

# Which DefectDojo parser reads which report: (file name starts with, ends with, scan type)
PARSERS = [
    ("trivy-", ".json", "Trivy Scan"),
    ("semgrep", ".json", "Semgrep JSON Report"),
    ("zap", ".xml", "ZAP Scan"),
    ("checkov", ".json", "Checkov Scan"),
    ("prowler-output", ".ocsf.json", "Prowler Scan"),
    ("lynis-report", ".dat", "Lynis Scan"),
]


def scan_type_for(path):
    for start, end, scan_type in PARSERS:
        if path.name.startswith(start) and path.name.endswith(end):
            return scan_type
    return None


def main():
    api_key = os.environ.get("DD_API_KEY")
    if not api_key:
        sys.exit("DD_API_KEY is not set. Run: read -s DD_API_KEY && export DD_API_KEY")
    folder = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "reports")
    engagement = sys.argv[2] if len(sys.argv) > 2 else "Security section"

    for path in sorted(folder.rglob("*")):
        scan_type = scan_type_for(path)
        if not path.is_file() or scan_type is None:
            continue
        # Prowler puts the account and the date in its file names. Dropping long
        # numbers means every run lands in the same test, so old findings close.
        title = re.sub(r"-[0-9]{6,}", "", path.name)
        with path.open("rb") as report:
            # reimport-scan updates the test with the same title if it exists,
            # and closes findings that are no longer in the report.
            response = requests.post(
                f"{DD_URL}/api/v2/reimport-scan/",
                headers={"Authorization": f"Token {api_key}"},
                data={
                    "scan_type": scan_type,
                    "product_type_name": "Tech Two Forty",
                    "product_name": "devsecops-capstone",
                    "engagement_name": engagement,
                    "test_title": title,
                    "auto_create_context": "true",
                },
                files={"file": report},
                timeout=300,
            )
        if response.ok:
            print(f"Imported {path.name} as {scan_type} into {engagement}")
        else:
            print(f"Could not import {path.name}: HTTP {response.status_code} {response.text[:200]}")


if __name__ == "__main__":
    main()
