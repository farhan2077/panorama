# Manual acceptance checklist

Use a release build and record the Mac model, macOS version, display refresh rate, number of windows, and preview mode.

- Grant Screen Recording and Accessibility through General Settings; relaunch if macOS requests it.
- Activate using the configured shortcut; Escape restores the previous app.
- Open with no highlight; scroll without selection; Return opens nearest center; arrows and actual mouse movement establish selection.
- Confirm individual windows from the same app remain separate and exact-window activation works.
- Verify live video/text updates while browsing; compare snapshot mode.
- Navigate across both ends; check gentle snapping, natural/reversed direction and Reduce Motion.
- Check thumbnail and icons-only navigators, compact spacing, visible-range outline and new-window badge.
- Launch a new application/window while open; existing windows remain anchored. Close a window and verify safe removal.
- Test bottom/left/right Dock, hidden/shown, magnification and external display placement.
- Test system and custom accent, light/dark appearance, Reduce Transparency and material fallback.
- Assign macOS desktop switching to three fingers or off; physically test four-finger left/right activation and navigation. Verify two/three/five fingers do not activate.
- Disable Panorama: activation stops. Quit: no process remains. Sleep/wake: shortcut and gesture listener recover.
- Benchmark live and snapshot modes with 5/10/20 windows; inspect reports and Instruments. Repeat 30 open/close cycles and inspect resident memory after idle.
- Verify signed update delivery using two distinct versions, including installation deferral during overview, automatic relaunch, failed-signature rejection and settings preservation.

Automated core tests complement this list; they cannot certify physical gestures, protected window capture, TCC permission flows, or GPU smoothness.
