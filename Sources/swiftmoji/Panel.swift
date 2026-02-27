import AppKit

class FloatingPanel: NSPanel {
    nonisolated(unsafe) var onDismiss: (() -> Void)?
    nonisolated(unsafe) var onArrowUp: (() -> Void)?
    nonisolated(unsafe) var onArrowDown: (() -> Void)?
    nonisolated(unsafe) var onCreateCombo: (() -> Void)?
    nonisolated(unsafe) var onDeleteCombo: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Allow the panel to receive key events
        isMovableByWindowBackground = false

        // Close when clicking outside
        hidesOnDeactivate = false
    }

    // Required for the panel to accept key input
    override var canBecomeKey: Bool { true }

    // Intercept key events BEFORE the responder chain dispatches them.
    // This prevents arrow keys from reaching the NSTextField (which would
    // move the text cursor instead of navigating the results list).
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            switch event.keyCode {
            case 53:
                onDismiss?()
                return
            case 126:
                onArrowUp?()
                return
            case 125:
                onArrowDown?()
                return
            case 48: // Tab
                if event.modifierFlags.contains(.shift) {
                    onArrowUp?()
                } else {
                    onArrowDown?()
                }
                return
            case 45: // 'n'
                if event.modifierFlags.contains(.command) {
                    onCreateCombo?()
                    return
                }
            case 51: // Delete/Backspace
                if event.modifierFlags.contains(.command) {
                    onDeleteCombo?()
                    return
                }
            default:
                break
            }
        }
        super.sendEvent(event)
    }
}
