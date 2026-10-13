#!/usr/bin/env bash
# Build locally, sign the archive with the update key, and prepare a release appcast.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
python3 - <<'PY'
import json,re
from pathlib import Path
v=Path('VERSION').read_text().strip()
assert re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)',v), 'VERSION must be stable SemVer (x.y.z)'
r=json.loads(Path('release.json').read_text())
assert re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+',r['repository']), 'Set the GitHub repository in release.json first'
assert r['feedURL'].startswith('https://'), 'Configure the HTTPS update feed first'
assert r['publicEDKey'], 'Configure the Sparkle public key first'
PY
swift test
CONFIGURATION=release ./script/build_and_run.sh --build-only
VERSION="$(cat VERSION)"
ARCHIVE="dist/Panorama-$VERSION.zip"
# Optional notarization for a Developer ID build. Local personal builds do not require it.
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    if [[ -z "${SIGNING_IDENTITY:-}" ]]; then echo "Notarization needs SIGNING_IDENTITY." >&2; exit 1; fi
    ditto -c -k --keepParent dist/Panorama.app dist/Panorama-notarize.zip
    xcrun notarytool submit dist/Panorama-notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple dist/Panorama.app
fi
codesign --verify --deep --strict dist/Panorama.app
ditto -c -k --keepParent dist/Panorama.app "$ARCHIVE"
SIGN_TOOL="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"
ACCOUNT="$(python3 -c 'import json; print(json.load(open("release.json"))["keychainAccount"])')"
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then
    "$SIGN_TOOL" --ed-key-file "$SPARKLE_KEY_FILE" "$ARCHIVE" > dist/update-signature.txt
else
    "$SIGN_TOOL" --account "$ACCOUNT" "$ARCHIVE" > dist/update-signature.txt
fi
python3 script/write_appcast.py
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Prepared $ARCHIVE and dist/appcast.xml"
