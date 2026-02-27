import AppKit
import SwiftUI
import SwiftmojiCore

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

extension NSView {
    func findFirstTextField() -> NSTextField? {
        if let textField = self as? NSTextField, textField.isEditable {
            return textField
        }
        for subview in subviews {
            if let found = subview.findFirstTextField() {
                return found
            }
        }
        return nil
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private var hotkeyManager: HotkeyManager?
    private var clickMonitor: Any?
    private var emojiSearcher: EmojiSearcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Swiftmoji running")
        emojiSearcher = EmojiSearcher(emojis: EmojiDataParser.loadAll())

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
            let panelHeight: CGFloat = 340
            let panel = FloatingPanel(contentRect: NSRect(
                x: 0, y: 0, width: panelWidth, height: panelHeight
            ))
            panel.onDismiss = { [weak self] in
                self?.hidePanel()
            }
            self.panel = panel
        }

        guard let panel = panel, let screen = NSScreen.main else { return }

        let hostingView = NSHostingView(rootView: SearchView(
            searcher: emojiSearcher!,
            onSelect: { [weak self] emoji in
                print("Selected: \(emoji.character) \(emoji.name)")
                self?.hidePanel()
            },
            onDismiss: { [weak self] in
                self?.hidePanel()
            }
        ))
        hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 340)
        panel.contentView = hostingView

        // Center horizontally, upper third of screen
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - screenFrame.height / 3
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.makeKeyAndOrderFront(nil)

        // Force focus into the search field — @FocusState alone can be
        // unreliable inside a non-activating NSPanel.
        DispatchQueue.main.async {
            if let textField = panel.contentView?.findFirstTextField() {
                panel.makeFirstResponder(textField)
            }
        }

        // Dismiss on click outside
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hidePanel()
            }
        }
    }

    func hidePanel() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        panel?.orderOut(nil)
    }
}
