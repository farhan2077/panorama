#!/usr/bin/env bash
# Preserve Sparkle’s vendor-signed nested code for ad hoc development; sign inside out for Developer ID.
set -euo pipefail
APP_BUNDLE="$1"
IDENTITY="${SIGNING_IDENTITY:--}"
if [[ "$IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP_BUNDLE"
else
    SPARKLE="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B"
    for NESTED in "$SPARKLE/XPCServices/Downloader.xpc" "$SPARKLE/XPCServices/Installer.xpc" "$SPARKLE/Autoupdate" "$SPARKLE/Updater.app" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"; do
        codesign --force --options runtime --timestamp --sign "$IDENTITY" "$NESTED"
    done
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP_BUNDLE"
fi
codesign --verify --deep --strict "$APP_BUNDLE"
