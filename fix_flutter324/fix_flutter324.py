#!/usr/bin/env python3
"""Converts newer Flutter APIs to the equivalents available in Flutter 3.24.3.

The GitHub workflow builds with Flutter 3.24.3, which does not have:
  Color.withValues(alpha: x)      -> Color.withOpacity(x)
  SwitchListTile(activeThumbColor) -> SwitchListTile(activeColor)
  Matrix4.translateByDouble(x, y, 0, 1) -> Matrix4.translate(x, y)
  Matrix4.scaleByDouble(s, s, s, 1)     -> Matrix4.scale(s)

Run from the project root (the folder that contains lib/):
    python3 fix_flutter324.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path("lib")
if not ROOT.is_dir():
    sys.exit("Run this from the project root (the folder that contains lib/).")

RULES = [
    (re.compile(r"\.withValues\(alpha:\s*([^)]+?)\)"), r".withOpacity(\1)",
     "withValues(alpha:) -> withOpacity()"),
    (re.compile(r"\bactiveThumbColor:"), "activeColor:",
     "activeThumbColor -> activeColor"),
    (re.compile(r"\.translateByDouble\(([^,()]+),\s*([^,()]+),\s*0,\s*1\)"),
     r".translate(\1, \2)", "translateByDouble -> translate"),
    (re.compile(r"\.scaleByDouble\(([^,()]+),\s*[^,()]+,\s*[^,()]+,\s*1\)"),
     r".scale(\1)", "scaleByDouble -> scale"),
]

changed_files = 0
for path in sorted(ROOT.rglob("*.dart")):
    text = path.read_text(encoding="utf-8")
    new_text = text
    for pattern, replacement, _ in RULES:
        new_text = pattern.sub(replacement, new_text)
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        changed_files += 1
        print(f"updated {path}")

print(f"\nDone. {changed_files} file(s) changed.")

leftover = []
for path in ROOT.rglob("*.dart"):
    text = path.read_text(encoding="utf-8")
    for pattern, _, label in RULES:
        if pattern.search(text):
            leftover.append(f"{path}: {label}")
if leftover:
    print("Still needs a manual look:")
    print("\n".join(leftover))
else:
    print("No 3.27-only APIs left in lib/.")
