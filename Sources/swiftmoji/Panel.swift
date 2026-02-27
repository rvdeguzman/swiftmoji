import AppKit

class FloatingPanel: NSPanel {
    nonisolated(unsafe) var onDismiss: (() -> Void)?

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

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            onDismiss?()
        } else {
            super.keyDown(with: event)
        }
    }
}
