import Cocoa
import SwiftUI

@main
struct MeetingLightApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let lightState = LightState()
    private var overlayWindow: OverlayWindow?
    private var hotkeyManager: HotkeyManager?
    private var stateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: "Meeting Light")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let settingsView = SettingsView(state: lightState)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 340)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: settingsView)

        overlayWindow = OverlayWindow(state: lightState)

        hotkeyManager = HotkeyManager(state: lightState)
        hotkeyManager?.register()

        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.overlayWindow?.applyState()
        }
        RunLoop.main.add(timer, forMode: .common)
        stateTimer = timer
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
