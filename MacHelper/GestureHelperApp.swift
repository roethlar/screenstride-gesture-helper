import SwiftUI
import ApplicationServices
import ServiceManagement

@main
struct GestureHelperApp: App {
    @NSApplicationDelegateAdaptor(HelperDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra("ScreenStride Gesture Helper", systemImage: "hand.draw") {
            HelperMenu(model: delegate.model)
        }
    }
}

final class HelperDelegate: NSObject, NSApplicationDelegate {
    let model = HelperModel()
    func applicationDidFinishLaunching(_ notification: Notification) { model.refresh() }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
}

final class HelperModel: ObservableObject {
    @Published private(set) var status = "Checking permission…"
    @Published private(set) var trusted = false
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginApprovalNeeded = false
    @Published var error: String?
    @Published var enabled = UserDefaults.standard.object(forKey: "gesturesEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "gesturesEnabled"); refresh() }
    }
    let supported = ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 27
    private let events = GestureEventTap()
    private var timer: Timer?
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(suspend),
            name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(suspend),
            name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(resume),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(resume),
            name: NSWorkspace.didWakeNotification, object: nil)
    }
    private var suspended = false
    @objc private func suspend() { suspended = true; events.stop(); refresh() }
    @objc private func resume() { suspended = false; refresh() }
    func refresh() {
        trusted = AXIsProcessTrusted()
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginApprovalNeeded = SMAppService.mainApp.status == .requiresApproval
        guard supported else { events.stop(); status = "macOS 27 support is not available yet"; return }
        guard enabled else { events.stop(); status = "Gestures paused"; return }
        guard !suspended else { events.stop(); status = "Waiting for your Mac session"; return }
        guard trusted else { events.stop(); status = "Accessibility permission required"; return }
        status = events.start() ? "Ready for iPad gestures" : "Unable to start — check Accessibility"
    }
    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        refresh()
    }
    func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch { self.error = error.localizedDescription }
        refresh()
    }
    func stop() { events.stop() }
    deinit { timer?.invalidate(); NSWorkspace.shared.notificationCenter.removeObserver(self) }
}

private struct HelperMenu: View {
    @ObservedObject var model: HelperModel
    var body: some View {
        Text("ScreenStride Gesture Helper").font(.headline)
        Text(model.status)
        Divider()
        Toggle("Enable gestures", isOn: $model.enabled).disabled(!model.supported)
        if !model.trusted {
            Button("Grant Accessibility Permission…") { model.requestPermission() }
        }
        Button("Open Accessibility Settings…") { model.openAccessibility() }
        Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }))
        if model.loginApprovalNeeded {
            Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
        }
        if let error = model.error { Text(error) }
        Divider()
        Text("Enable three-finger gestures in the iPad app’s Settings.")
        Text("Screen sharing and audio work without this helper.")
        Button("About ScreenStride Gesture Helper") { NSApp.orderFrontStandardAboutPanel() }
        Button("Quit ScreenStride Gesture Helper") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
