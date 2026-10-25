#!/usr/bin/env python3
"""Standalone integrity check. Cross-repo freshness requires parent contracts.py check."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parent
receipt = root / 'bundle.json'
try:
    manifest = json.loads(receipt.read_text())
    required = {'openapi.json', 'fixtures/leave-approval.json', 'check-bundle.py'}
    if set(manifest['files']) != required:
        raise ValueError('Unexpected or missing bundle files')
    for name, expected in manifest['files'].items():
        actual = hashlib.sha256((root / name).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f'{name} differs from the source bundle receipt')
    print('Bundle integrity verified; source freshness requires the cross-repository check.')
except (OSError, KeyError, ValueError) as error:
    print(f'Bundle check failed: {error}', file=sys.stderr)
    sys.exit(1)
