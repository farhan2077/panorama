#!/usr/bin/env bash
# Explicit publishing command: requires a clean, committed checkout and prepared archives.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ -n "$(git status --porcelain)" ]]; then echo "Commit changes before publishing." >&2; exit 1; fi
VERSION="$(cat VERSION)"
REPO="$(python3 -c 'import json; print(json.load(open("release.json"))["repository"])')"
if [[ -z "$REPO" ]]; then echo "Configure release.json first." >&2; exit 1; fi
for FILE in "dist/Panorama-$VERSION.zip" "dist/Panorama-$VERSION.zip.sha256" dist/appcast.xml; do test -s "$FILE"; done
git tag "v$VERSION"
git push origin HEAD "v$VERSION"
gh release create "v$VERSION" "dist/Panorama-$VERSION.zip" "dist/Panorama-$VERSION.zip.sha256" dist/appcast.xml --repo "$REPO" --title "Panorama $VERSION" --notes-file docs/RELEASE_NOTES.md --verify-tag
