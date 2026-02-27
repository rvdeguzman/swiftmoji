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
    private let searchState = SearchState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Swiftmoji running")
        let emojis = EmojiDataParser.loadAll()
        print("Loaded \(emojis.count) emojis")
        emojiSearcher = EmojiSearcher(emojis: emojis)

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
            let panel = FloatingPanel(contentRect: NSRect(
                x: 0, y: 0, width: 500, height: 44
            ))
            panel.onDismiss = { [weak self] in
                self?.hidePanel()
            }
            panel.onArrowUp = { [weak self] in
                self?.searchState.moveUp(resultCount: 50)
            }
            panel.onArrowDown = { [weak self] in
                self?.searchState.moveDown(resultCount: 50)
            }
            self.panel = panel
        }

        guard let panel = panel, let screen = NSScreen.main else { return }

        searchState.reset()

        let hostingView = NSHostingView(rootView: SearchView(
            searchState: searchState,
            searcher: emojiSearcher!,
            onSelect: { [weak self] emoji in
                print("Selected: \(emoji.character) \(emoji.name)")
                self?.hidePanel()
            },
            onDismiss: { [weak self] in
                self?.hidePanel()
            }
        ))

        // Let the hosting view size itself to fit SwiftUI content
        panel.contentView = hostingView

        // Position: center horizontally, upper third of screen
        // Anchor from the TOP so the panel grows downward when results appear
        let screenFrame = screen.visibleFrame
        let topY = screenFrame.maxY - screenFrame.height / 4
        let fittingSize = hostingView.fittingSize
        let x = screenFrame.midX - fittingSize.width / 2
        let y = topY - fittingSize.height
        panel.setFrame(NSRect(x: x, y: y, width: fittingSize.width, height: fittingSize.height), display: true)

        panel.makeKeyAndOrderFront(nil)

        // Force focus into the search field
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
