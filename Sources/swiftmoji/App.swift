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
    private let comboFormState = ComboFormState()
    private var pickHistory: PickHistory?
    private var comboStore: ComboStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Swiftmoji running")
        let emojis = EmojiDataParser.loadAll()
        print("Loaded \(emojis.count) emojis")
        let kaomojis = KaomojiDataParser.loadAll()
        print("Loaded \(kaomojis.count) kaomojis")
        let historyURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Swiftmoji", isDirectory: true)
        try? FileManager.default.createDirectory(at: historyURL, withIntermediateDirectories: true)
        pickHistory = PickHistory(storageURL: historyURL.appendingPathComponent("pick-history.json"))

        comboStore = ComboStore(storageURL: historyURL.appendingPathComponent("combos.json"))
        emojiSearcher = EmojiSearcher(emojis: emojis, kaomojis: kaomojis, comboStore: comboStore)

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
            panel.onCreateCombo = { [weak self] in
                self?.showComboForm()
            }
            panel.onDeleteCombo = { [weak self] in
                self?.searchState.deleteRequested = true
            }
            panel.onTabPressed = { [weak self] in
                self?.searchState.toggleMode()
            }
            self.panel = panel
        }

        guard let panel = panel, let screen = NSScreen.main else { return }

        panel.interceptsTab = true
        searchState.reset()

        let hostingView = NSHostingView(rootView: SearchView(
            searchState: searchState,
            searcher: emojiSearcher!,
            pickHistory: pickHistory!,
            onSelect: { [weak self] emoji, query in
                self?.pickHistory?.record(query: query, emojiCharacter: emoji.character)
                self?.pickHistory?.save()
                self?.hidePanel()
                self?.pasteEmoji(emoji.character)
            },
            onDismiss: { [weak self] in
                self?.hidePanel()
            },
            onDeleteCombo: { [weak self] emoji in
                guard let self, let comboStore = self.comboStore else { return }
                if comboStore.isCombo(character: emoji.character) {
                    comboStore.delete(character: emoji.character)
                    comboStore.save()
                }
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

    func pasteEmoji(_ character: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(character, forType: .string)

        // Small delay to ensure the panel is fully dismissed before pasting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 'v'
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    func showComboForm() {
        guard let panel = panel else { return }
        panel.interceptsTab = false

        // Rewire arrow keys to combo form's emoji selection
        panel.onArrowUp = { [weak self] in
            self?.comboFormState.moveUp()
        }
        panel.onArrowDown = { [weak self] in
            self?.comboFormState.moveDown()
        }

        comboFormState.reset()

        let hostingView = NSHostingView(rootView: ComboFormView(
            formState: comboFormState,
            searcher: emojiSearcher!,
            onSave: { [weak self] names, characters in
                self?.comboStore?.add(names: names, characters: characters)
                self?.comboStore?.save()
                self?.showPanel()
            },
            onCancel: { [weak self] in
                self?.showPanel()
            }
        ))

        panel.contentView = hostingView
        let fittingSize = hostingView.fittingSize
        var frame = panel.frame
        frame.size = fittingSize
        frame.origin.y += panel.frame.height - fittingSize.height
        panel.setFrame(frame, display: true)

        DispatchQueue.main.async {
            if let textField = panel.contentView?.findFirstTextField() {
                panel.makeFirstResponder(textField)
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
