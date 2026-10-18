#!/usr/bin/env python3
"""Check every i18n/<code>.json against en.json.

Each catalog must carry exactly the English keys, keep the same %1/%2
placeholders in every plural form, and use only CLDR plural categories.

    python3 tools/check-i18n.py
"""
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent / "i18n"
english = json.loads((root / "en.json").read_text(encoding="utf-8"))
categories = {"zero", "one", "two", "few", "many", "other"}


def forms(value):
    return list(value.values()) if isinstance(value, dict) else [value]


def placeholders(text):
    return {p for p in ("%1", "%2") if p in text}


problems = []
for path in sorted(root.glob("*.json")):
    catalog = json.loads(path.read_text(encoding="utf-8"))
    code = path.stem
    for key in sorted(set(english) - set(catalog)):
        problems.append(f"{code}: missing {key}")
    for key in sorted(set(catalog) - set(english)):
        problems.append(f"{code}: unknown key {key}")
    for key, value in catalog.items():
        if key not in english:
            continue
        if isinstance(value, dict):
            if "other" not in value:
                problems.append(f"{code}.{key}: plural entry needs 'other'")
            for category in set(value) - categories:
                problems.append(f"{code}.{key}: unknown plural category '{category}'")
        expected = placeholders(forms(english[key])[-1])
        for form in forms(value):
            if placeholders(form) != expected:
                problems.append(f"{code}.{key}: placeholders {sorted(placeholders(form))}, expected {sorted(expected)}")

if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"{len(list(root.glob('*.json')))} catalogs, {len(english)} keys each: OK")
