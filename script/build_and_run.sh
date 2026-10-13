#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
CONFIG="${CONFIGURATION:-debug}"
APP_BUNDLE="$ROOT_DIR/dist/Panorama.app"
case "$MODE" in run|--debug|--logs|--telemetry|--verify|--build-only) ;; *) echo "Usage: $0 [--build-only|--debug|--logs|--telemetry|--verify]" >&2; exit 2;; esac
if [[ "$MODE" != "--build-only" ]]; then pkill -x Panorama >/dev/null 2>&1 || true; fi
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Frameworks" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/Panorama" "$APP_BUNDLE/Contents/MacOS/Panorama"
SPARKLE="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$SPARKLE" ]]; then echo "Sparkle framework not found" >&2; exit 1; fi
ditto "$SPARKLE" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/Panorama" 2>/dev/null || true
export PANORAMA_BUNDLE="$APP_BUNDLE"
python3 script/write_info_plist.py
if [[ -f Resources/Panorama.icns ]]; then cp Resources/Panorama.icns "$APP_BUNDLE/Contents/Resources/"; fi
./script/sign_bundle.sh "$APP_BUNDLE"
case "$MODE" in
  --build-only) echo "Built $APP_BUNDLE";;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/Panorama";;
  --logs|--telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "app.panorama"';;
  --verify) open -n "$APP_BUNDLE"; sleep 2; pgrep -x Panorama >/dev/null; echo "Panorama is running.";;
  *) open -n "$APP_BUNDLE";;
esac
