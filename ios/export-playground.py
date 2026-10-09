#!/usr/bin/env python3
"""Synchronize the iPad app package from the canonical Xcode sources."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parent
source = root / "ERP"
target = root / "ERP-iPad.swiftpm"
module = target / "Sources/ERP"
module.mkdir(parents=True, exist_ok=True)
for stale in module.glob("*.swift"):
    if not (source / stale.name).exists():
        stale.unlink()
for path in source.glob("*.swift"):
    shutil.copy2(path, module / path.name)
resources = module / "Resources"
resources.mkdir(exist_ok=True)
for path in (source / "Resources").glob("*.json"):
    shutil.copy2(path, resources / path.name)
shutil.copytree(source / "Resources/Assets.xcassets", module / "Assets.xcassets", dirs_exist_ok=True)
shutil.copy2(root / "Playground.Package.swift", target / "Package.swift")
print(target)
