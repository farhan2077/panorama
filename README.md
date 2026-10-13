# Panorama

A native macOS scrolling overview for finding and opening your windows. Browse a horizontal strip of live previews without rearranging the windows themselves.

## Run

Requires macOS 14+, Xcode 26+ with the macOS 26 SDK or newer, and Swift 6. The runtime supports older systems using native material fallbacks. Initial development is on Apple silicon.

```sh
./script/build_and_run.sh
```

The script builds a real app at `dist/Panorama.app`, embeds Sparkle, signs locally, and launches it. The Codex Run action uses the same script. Use `--verify`, `--logs`, `--telemetry`, `--debug`, or `--build-only` as needed. `CONFIGURATION=release` builds with optimization.

On first launch, grant Screen Recording and Accessibility in General Settings. If macOS asks you to quit and reopen, do so. These permissions are needed for live previews and exact-window activation. They are never bypassed by the app.

The default shortcut is Control–Option–Space. Four-finger horizontal swipes can also activate the overview; assign macOS “Swipe between full-screen applications” to three fingers or off to avoid a conflict. Two-finger scrolling works inside the overview. Return opens explicit selection or the nearest centered window. Escape cancels. Clicking a bottom item navigates to it; clicking its large preview opens it.

The menu bar provides Enable/Disable, Open Overview, Settings and Quit. Disabling stops activation listeners. Closing the overview stops capture and releases the rendering session. Every eligible window on the active display and current Space receives its own item. Minimized windows, full-screen Spaces and system dialogs are outside the first version’s scope.

## Settings

- Live previews by default; snapshot mode and 15/30/60 fps capture options.
- Compact bottom navigator with proportionate thumbnails + app icons or icons only.
- Natural scrolling, gentle snapping, configurable shortcut and gesture activation.
- System accent by default, with a custom color option.
- Liquid Glass on macOS 26+, native translucent fallback; respects accessibility display preferences.
- Space reserved for the Dock whether hidden or shown, on all three Dock edges.
- Automatic updates at startup and every three hours, including install/relaunch once the overview closes.
- Opt-in 10-second performance benchmark with local JSON export.

## Verify

```sh
swift test
./script/build_and_run.sh --verify
```

Read [the architecture](docs/ARCHITECTURE.md), [manual acceptance checklist](docs/ACCEPTANCE.md), and [release guide](docs/RELEASING.md). Benchmarks measure display-link callbacks, capture delivery, process CPU and resident memory; they are not a GPU presentation guarantee. Use Instruments for deeper profiling.

## Release status

The project starts at `0.1.0`. `release.json` must contain a repository, HTTPS feed, and matching Sparkle public key before automatic updates are enabled. The update private key is stored in macOS Keychain under `panorama-updates`. No credentials belong in the repository.

This development build is ad hoc signed. Developer ID signing/notarization and a two-version update installation test remain separate release checks. See the acceptance checklist for platform behavior that still needs physical testing.
