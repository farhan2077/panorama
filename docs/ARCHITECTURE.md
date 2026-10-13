# Panorama architecture

Panorama is a temporary horizontal overview of existing windows. It does not arrange, move, or resize application windows.

## Runtime

One accessory/menu-bar app process, SwiftUI Settings, AppKit overview, Core Animation and AVSampleBufferDisplayLayer rendering, ScreenCaptureKit capture, Accessibility window activation. The deployment target is macOS 14; native NSGlassEffectView is used on macOS 26+ with NSVisualEffectView fallback. The system accent is the default.

The app coordinator owns service lifetimes. OverviewController owns one overview session. Closing a session cancels discovery, stops streams, invalidates animation, releases frames and destroys views. Background callbacks check a generation before delivering to a later session. Captured frames never enter SwiftUI observable state. Each stream coalesces delivery to one pending main-thread callback and one latest sample buffer. Capture uses three queued frames and previews sized for the visible cards. Nonvisible windows get small snapshots in the navigator, with live capture activated as they approach the viewport. Neither screenshots nor window titles enter benchmark reports or logs.

Discovery refreshes every 1.5 seconds only while the overview is open. Existing order survives refresh; new windows append to the right to preserve the current viewport and receive a New marker. This deliberately resolves the earlier “insert beside active window” idea in favor of preserving spatial stability while interacting. A selected window is distinct from the scroll position. Entry and scrolling have no selection. Mouse movement or arrows establish selection. Return uses explicit selection or the nearest window center. Bottom items navigate; large-preview clicks activate. Escape restores the previous application.

## Boundaries

- `PanoramaCore`: deterministic layout, four-finger recognition, bounded frame statistics; tested without permissions.
- `App`: entry point and service composition.
- `Features/Overview`: lifecycle, input policy and scrolling.
- `Features/Settings`: native grouped Settings and shortcut recorder.
- `Rendering`: video surfaces and navigator material.
- `Services/Capture`: ScreenCaptureKit and latest-frame delivery.
- `Services/Windows`: catalog, Dock clearance, permissions and Accessibility focusing.
- `Services/Input`: Carbon global shortcut and optional trackpad adapter.
- `Services/Diagnostics`: opt-in benchmark and OSLog signposts.
- `Services/Updates`: Sparkle update and relaunch policy.
- `TrackpadBridge`: small C ABI boundary for dynamically loaded MultitouchSupport.

Four-finger activation is the one explicitly undocumented API dependency. Missing symbols fail closed, leaving the shortcut usable. Framework availability does not prove physical gesture behavior; validate on the target Mac. System four-finger desktop switching must be disabled or assigned three fingers by the user. Panorama never changes those preferences. The listener stops on disable/sleep and restarts on wake.

## Distribution

`VERSION` is the authoritative SemVer. `release.json` holds the public feed URL and Ed25519 public key only. Sparkle owns archive verification and installation. Automatic checks run at startup and every three hours; downloaded updates install and relaunch after the overview is closed. Private signing material belongs in Keychain or GitHub Actions secrets, never the repository. Developer ID signing/notarization are separate from update-signature verification.

## Performance validation

The in-app 10-second benchmark runs a deterministic horizontal motion over real windows. It reports display-link timing, p95 interval, estimated missed frames, first-preview and open latency, aggregate delivered capture frames, sampled resident memory and process CPU. It does not claim GPU presentation measurement or system-wide memory. Use Instruments Time Profiler, Core Animation/Animation Hitches, Allocations, and OSLog signposts to diagnose further. Compare release builds, live/snapshot modes, 5/10/20 windows and repeated open/close cycles. No detailed diagnostic sampling runs outside benchmark sessions.
