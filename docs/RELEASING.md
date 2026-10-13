# Releasing Panorama

## Configure once

Set `repository` to `owner/repo` in `release.json`. For a public GitHub repository, use `https://github.com/owner/repo/releases/latest/download/appcast.xml` as `feedURL`. `publicEDKey` must match the private key in Keychain under the configured `keychainAccount` (currently `panorama-updates`). Public keys can be committed; private keys must never be committed. Back up the private key securely before relying on the updater.

Private repositories need an authenticated feed and archive endpoint; simply pointing Sparkle at a private GitHub URL will not work. Do not embed a personal GitHub token in the app. Configure an authenticated distribution service before publishing private updates.

## Publish each version

1. Update `VERSION` using SemVer: patch for fixes, minor for features, major for breaking changes. Update CHANGELOG and `docs/RELEASE_NOTES.md`.
2. Run the acceptance checks for the change.
3. Run `./script/package_release.sh`. It tests and builds Release, packages the app, signs the archive using the Keychain key, and writes the appcast and checksum.
4. Commit the code and release notes, then run `./script/publish_release.sh`. This creates and pushes `vX.Y.Z` and a GitHub Release with the zip, checksum and appcast. It refuses a dirty tree.
5. Verify the release asset links, install the earlier version, check for an update, and verify install/relaunch, settings persistence, signature rejection and deferral while browsing.

The appcast asset on the latest release is the stable feed endpoint. Never modify an archive after it has been signed. No automatic publishing happens in ordinary CI; publishing is explicit and every published version gets a GitHub Release.

## Signing

Local builds use ad hoc signing when no signing identity is configured. This permits local testing but is not a notarized distribution identity, and development rebuilds may require permission grants again.

For distribution outside your own Mac, provide a Developer ID Application identity as `SIGNING_IDENTITY`. The build script signs nested Sparkle code from the inside out using hardened runtime, then the packaging script can notarize with `NOTARY_PROFILE` and staple. Local ad hoc signing preserves Sparkle’s vendor-signed nested code. Verify the nested helpers when preparing a notarized release. Do not mistake a signed update archive for Apple notarization.

Sparkle is the only external package. Keep its pinned release and verification tooling in sync.
