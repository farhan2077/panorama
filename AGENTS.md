# Panorama contributor guide

Panorama is a scrolling window overview and switcher, not a window manager. Never move or resize other applications’ windows.

- Use the macOS skills. Prefer small native Swift/AppKit/SwiftUI components and explicit service ownership.
- Keep upper previews separate, large, and proportional; only the compact bottom navigator gets grouped glass/material.
- No initial selection. Scrolling clears selection. Return opens explicit selection or the closest window to center.
- Keep scroll position stable as windows appear/disappear. New arrivals append during a session.
- Respect the system accent unless a custom accent is configured. Always reserve Dock space, including when auto-hidden.
- Live previews are the default. Stop capture, animation and session work on close/disable/quit.
- Bound frame queues and memory. Use display-linked animation. Do not route video buffers through SwiftUI observable state.
- Test meaningful geometry, input, lifecycle and performance behavior. Use `swift test` and `./script/build_and_run.sh --verify`.
- Use `VERSION` as the SemVer source. Each distributed version needs a GitHub Release. Never commit update-signing private keys or credentials.
- Mockups are references, not pixel-perfect acceptance targets. Actual app behavior and measured smoothness decide the details.
- Do not claim physical gestures, permissions, live captures or update installation work unless actually verified. Document remaining checks.
