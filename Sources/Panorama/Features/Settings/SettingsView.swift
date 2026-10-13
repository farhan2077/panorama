import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var app: AppCoordinator
    @Bindable var preferences: Preferences
    init(app: AppCoordinator) { self.app = app; self.preferences = app.preferences }
    @State private var selected: Category? = .general
    enum Category: String, CaseIterable, Identifiable {
        case general = "General", overview = "Overview", appearance = "Appearance", shortcuts = "Shortcuts", performance = "Performance", updates = "Updates"
        var id: Self { self }
        var icon: String {
            switch self {
            case .general: "gearshape"
            case .overview: "rectangle.on.rectangle"
            case .appearance: "paintpalette"
            case .shortcuts: "keyboard"
            case .performance: "gauge.with.dots.needle.67percent"
            case .updates: "arrow.down.circle"
            }
        }
    }
    var body: some View {
        NavigationSplitView {
            List(Category.allCases, selection: $selected) { category in
                Label(category.rawValue, systemImage: category.icon).tag(category)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Panorama").font(.headline)
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }
        } detail: {
            Form {
                switch selected ?? .general {
                case .general: general
                case .overview: overview
                case .appearance: appearance
                case .shortcuts: shortcuts
                case .performance: performance
                case .updates: updates
                }
            }
            .formStyle(.grouped)
            .navigationTitle((selected ?? .general).rawValue)
        }
        .tint(app.preferences.color)
        .frame(minWidth: 700, minHeight: 500)
        .onAppear { app.permissions.refresh() }
    }
    private var general: some View {
        Group {
            Section {
                Toggle("Enable Panorama", isOn: $preferences.isEnabled)
                Toggle("Launch at login", isOn: Binding(get: { app.loginEnabled }, set: { app.setLogin($0) }))
                Button("Open Overview") { app.toggleOverview() }
                    .disabled(!app.preferences.isEnabled)
            }
            Section("Permissions") {
                permissionRow("Screen Recording", subtitle: "Displays live previews of your windows. Nothing is recorded to disk.", granted: app.permissions.screenRecording, action: app.permissions.requestScreenRecording)
                permissionRow("Accessibility", subtitle: "Opens the exact window you select.", granted: app.permissions.accessibility, action: app.permissions.requestAccessibility)
                Button("Refresh Permission Status") { app.permissions.refresh() }
            }
            Section {
                Text("Browse windows on your current display and Space. Escape cancels. Return opens the selected window, or the window closest to center.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private func permissionRow(_ name: String, subtitle: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) { Text(name); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            if granted { Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout) }
            else { Button("Allow…", action: action) }
        }.padding(.vertical, 4)
    }
    private var overview: some View {
        Group {
            Section("Previews") {
                Picker("Preview mode", selection: $preferences.previewMode) {
                    ForEach(Preferences.PreviewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                Picker("Bottom navigator", selection: $preferences.navigatorMode) {
                    ForEach(Preferences.NavigatorMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
            }
            Section("Navigation") {
                Toggle("Natural scrolling", isOn: $preferences.naturalScrolling)
                Toggle("Gentle snapping", isOn: $preferences.gentleSnapping)
                Text("The neutral outline tracks the visible range. An accent outline appears only after you move the pointer or use arrow keys. Click a bottom item to bring it into view; click its large preview to open it.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Dock clearance") {
                Slider(value: $preferences.dockReserve, in: 72...180, step: 4) { Text("Minimum space") }
                Text("\(Int(app.preferences.dockReserve)) points minimum. Panorama also accounts for the Dock’s position and configured size, even when hidden.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var appearance: some View {
        Group {
            Section("Accent color") {
                Toggle("Use macOS accent color", isOn: $preferences.useSystemAccent)
                if !app.preferences.useSystemAccent {
                    ColorPicker("Custom accent", selection: Binding(get: { app.preferences.color }, set: { value in
                        guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
                        app.preferences.customAccentHex = String(format: "%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
                    }), supportsOpacity: false)
                }
            }
            Section("Materials") {
                Text("The bottom navigator uses Liquid Glass on macOS 26 and later, with a native translucent material on earlier versions. Window previews have no shared panel background.")
                Text("Light and Dark appearance, Reduce Motion, and Reduce Transparency follow macOS settings.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var shortcuts: some View {
        Group {
            Section("Activation") {
                HStack { Text("Global shortcut"); Spacer(); ShortcutRecorder(preferences: app.preferences).frame(width: 170, height: 28) }
                Toggle("Four-finger horizontal swipe", isOn: $preferences.fourFingerEnabled)
                Text(app.inputStatus).font(.caption).foregroundStyle(.secondary)
            }
            Section("Trackpad setup") {
                Text("For four-finger activation, set macOS “Swipe between full-screen applications” to three fingers or turn it off in Trackpad → More Gestures. Panorama does not change your system settings.")
                Button("Open Trackpad Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!) }
                Text("Four-finger recognition uses an undocumented macOS interface. If an OS update changes it, disable this option and use your shortcut. Two-finger scrolling also works inside the overview.").font(.caption).foregroundStyle(.secondary)
            }
            Section("While browsing") {
                LabeledContent("Move selection", value: "← / →")
                LabeledContent("Open window", value: "Return or click")
                LabeledContent("Cancel", value: "Escape")
            }
        }
    }
    private var performance: some View {
        Group {
            Section("Live previews") {
                Picker("Capture frame rate", selection: $preferences.previewFPS) {
                    Text("15 fps · lower power").tag(15); Text("30 fps · balanced").tag(30); Text("60 fps · fluid content").tag(60)
                }
                Text("Scrolling follows the display refresh rate independently. Capture stops when the overview closes.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Benchmark") {
                Text("Measure a repeatable 10-second scroll across your actual windows. Open at least two windows on the current display.")
                Button(app.performance.isBenchmarking ? "Running…" : "Run Scroll Benchmark") { app.runBenchmark() }.disabled(app.performance.isBenchmarking)
                Text(app.performance.status).font(.callout).textSelection(.enabled)
                if let latency = app.performance.lastWindowActivationMilliseconds {
                    LabeledContent("Last window activation", value: String(format: "%.1f ms", latency))
                }
                if let url = app.performance.latestReport {
                    Button("Show Benchmark Report") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    Button("Export Report…") {
                        let panel = NSSavePanel(); panel.nameFieldStringValue = url.lastPathComponent
                        if panel.runModal() == .OK, let destination = panel.url {
                            do { try Data(contentsOf: url).write(to: destination, options: .atomic) }
                            catch { app.performance.status = "Export failed: \(error.localizedDescription)" }
                        }
                    }
                }
            }
            Section {
                Text("Reports stay on this Mac and contain timing and resource measurements, never window titles or screenshots. Display-link timing estimates animation cadence; use Instruments for GPU and WindowServer analysis.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var updates: some View {
        Group {
            Section("Automatic updates") {
                Toggle("Automatically download, install, and relaunch", isOn: $preferences.automaticUpdates)
                Text("Check at startup and every three hours while running. Installation waits until the overview closes.").font(.caption).foregroundStyle(.secondary)
                Button("Check for Updates") { app.updates.checkNow() }.disabled(!app.updates.isConfigured)
                Text(app.updates.status).font(.callout).foregroundStyle(.secondary)
            }
            Section("Version") {
                LabeledContent("Panorama", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")
            }
        }
    }
}
