#!/usr/bin/env python3
"""Generate bundle metadata from a single SemVer source and optional release config."""
import json
import os
import plistlib
from pathlib import Path
root = Path(__file__).resolve().parent.parent
version = (root / "VERSION").read_text().strip()
info = {
    "CFBundleExecutable": "Panorama", "CFBundleIdentifier": "com.farhan2077.Panorama",
    "CFBundleName": "Panorama", "CFBundleDisplayName": "Panorama", "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": version, "CFBundleVersion": version,
    "LSMinimumSystemVersion": "14.0", "NSPrincipalClass": "NSApplication", "LSUIElement": True,
    "NSHighResolutionCapable": True, "CFBundleIconFile": "Panorama",
    "NSScreenCaptureUsageDescription": "Panorama shows live previews of your windows while the overview is open.",
    "SUEnableAutomaticChecks": True, "SUAutomaticallyUpdate": True, "SUScheduledCheckInterval": 10800,
    "SUSendProfileInfo": False,
}
config = root / "release.json"
if config.exists():
    release = json.loads(config.read_text())
    if release.get("feedURL") and release.get("publicEDKey"):
        info["SUFeedURL"] = release["feedURL"]
        info["SUPublicEDKey"] = release["publicEDKey"]
output = Path(os.environ["PANORAMA_BUNDLE"]) / "Contents/Info.plist"
output.write_bytes(plistlib.dumps(info))
