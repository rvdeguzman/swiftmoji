import AppKit
import SwiftUI

@main
struct SwiftmojiApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Swiftmoji running")

        hotkeyManager = HotkeyManager(onHotkey: { [weak self] in
            self?.togglePanel()
        })

        if !hotkeyManager!.start() {
            // Prompt for accessibility permissions
            let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            print("Please grant Accessibility access and restart Swiftmoji.")
        }
    }

    func togglePanel() {
        if let panel = panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        if panel == nil {
            let panelWidth: CGFloat = 500
            let panelHeight: CGFloat = 44
            let panel = FloatingPanel(contentRect: NSRect(
                x: 0, y: 0, width: panelWidth, height: panelHeight
            ))
            self.panel = panel
        }

        guard let panel = panel, let screen = NSScreen.main else { return }

        let hostingView = NSHostingView(rootView: SearchView(onDismiss: { [weak self] in
            self?.hidePanel()
        }))
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 44)
        panel.contentView = hostingView

        // Center horizontally, upper third of screen
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - screenFrame.height / 3
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        panel?.orderOut(nil)
    }
}
