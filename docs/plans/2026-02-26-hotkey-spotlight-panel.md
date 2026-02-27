# Global Hotkey + Spotlight Panel Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS background agent that opens a Spotlight-like floating panel when the user presses opt+e.

**Architecture:** SwiftUI views hosted in a non-activating NSPanel, triggered by a CGEvent tap global hotkey. The app runs as an LSUIElement (no Dock/menu bar icon). Panel dismisses on escape, click-outside, or losing focus.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (NSPanel), CGEvent API

---

### Task 1: Set Up macOS App Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/swiftmoji/App.swift`
- Create: `Sources/swiftmoji/Info.plist`

**Step 1: Create Package.swift with macOS platform and AppKit dependency**

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftmoji",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "swiftmoji",
            resources: [.copy("Info.plist")]
        ),
    ]
)
```

**Step 2: Create Info.plist for LSUIElement**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
```

**Step 3: Create App.swift entry point with NSApplicationDelegate**

```swift
import AppKit
import SwiftUI

@main
struct SwiftmojiApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Swiftmoji running")
    }
}
```

**Step 4: Build and run to verify the app launches**

Run: `swift build 2>&1`
Expected: Build succeeds

Run: `swift run swiftmoji &; sleep 2; kill %1`
Expected: Prints "Swiftmoji running", no Dock icon appears

**Step 5: Commit**

```bash
git add Package.swift Sources/
git commit -m "feat: set up macOS background agent with LSUIElement"
```

---

### Task 2: Create the Floating Panel (NSPanel)

**Files:**
- Create: `Sources/swiftmoji/Panel.swift`
- Modify: `Sources/swiftmoji/App.swift`

**Step 1: Create Panel.swift with custom NSPanel subclass**

The panel needs to:
- Float above all windows
- Not activate (so the target app stays focused for pasting)
- Accept key events despite being non-activating (override `canBecomeKey`)
- Have no title bar, rounded corners, and a shadow

```swift
import AppKit

class FloatingPanel: NSPanel {
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
}
```

**Step 2: Add panel creation and show/hide to AppDelegate**

Update `App.swift` to create the panel centered on screen:

```swift
import AppKit
import SwiftUI

@main
struct SwiftmojiApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Swiftmoji running")
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
```

**Step 3: Build to verify compilation**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/swiftmoji/Panel.swift Sources/swiftmoji/App.swift
git commit -m "feat: add floating NSPanel with Spotlight-like positioning"
```

---

### Task 3: Add SwiftUI Search Field to Panel

**Files:**
- Create: `Sources/swiftmoji/SearchView.swift`
- Modify: `Sources/swiftmoji/App.swift`

**Step 1: Create SearchView.swift with a styled text field**

```swift
import SwiftUI

struct SearchView: View {
    @State private var query: String = ""
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))

                TextField("Search emoji...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .onSubmit {
                        // Will handle emoji selection later
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 500)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand {
            onDismiss()
        }
    }
}
```

**Step 2: Host the SwiftUI view in the panel**

Update `showPanel()` in `App.swift` to set the panel's content view:

In the `showPanel()` method, after creating the panel and before `makeKeyAndOrderFront`, add:

```swift
let hostingView = NSHostingView(rootView: SearchView(onDismiss: { [weak self] in
    self?.hidePanel()
}))
hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 44)
panel.contentView = hostingView
```

**Step 3: Build and run to verify the panel displays the search field**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/swiftmoji/SearchView.swift Sources/swiftmoji/App.swift
git commit -m "feat: add SwiftUI search field to floating panel"
```

---

### Task 4: Register Global Hotkey (opt+e)

**Files:**
- Create: `Sources/swiftmoji/HotkeyManager.swift`
- Modify: `Sources/swiftmoji/App.swift`

**Step 1: Create HotkeyManager.swift with CGEvent tap**

```swift
import AppKit

class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onHotkey: () -> Void

    init(onHotkey: @escaping () -> Void) {
        self.onHotkey = onHotkey
    }

    func start() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Store self in a pointer so the C callback can access it
        let userInfo = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = manager.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                // Check for opt+e (keycode 14 = 'e')
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                if keyCode == 14 && flags.contains(.maskAlternate)
                    && !flags.contains(.maskCommand)
                    && !flags.contains(.maskControl)
                    && !flags.contains(.maskShift)
                {
                    DispatchQueue.main.async {
                        manager.onHotkey()
                    }
                    // Consume the event so 'e' with option doesn't type a character
                    return nil
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: userInfo
        ) else {
            print("Failed to create event tap. Check Accessibility permissions.")
            Unmanaged<HotkeyManager>.fromOpaque(userInfo).release()
            return false
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("Global hotkey registered: opt+e")
        return true
    }

    deinit {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}
```

**Step 2: Wire up the hotkey in AppDelegate**

Update `App.swift` `applicationDidFinishLaunching` to create the HotkeyManager:

```swift
private var hotkeyManager: HotkeyManager?

func applicationDidFinishLaunching(_ notification: Notification) {
    hotkeyManager = HotkeyManager(onHotkey: { [weak self] in
        self?.togglePanel()
    })

    if !hotkeyManager!.start() {
        // Prompt for accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        print("Please grant Accessibility access and restart Swiftmoji.")
    }
}
```

**Step 3: Build and verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 4: Commit**

```bash
git add Sources/swiftmoji/HotkeyManager.swift Sources/swiftmoji/App.swift
git commit -m "feat: register global hotkey (opt+e) via CGEvent tap"
```

---

### Task 5: Panel Dismiss Behavior

**Files:**
- Modify: `Sources/swiftmoji/Panel.swift`
- Modify: `Sources/swiftmoji/App.swift`
- Modify: `Sources/swiftmoji/SearchView.swift`

**Step 1: Add click-outside-to-dismiss via NSEvent monitor**

In `App.swift`, add a global click monitor when the panel is shown, remove it when hidden:

```swift
private var clickMonitor: Any?

func showPanel() {
    // ... existing code ...
    panel.makeKeyAndOrderFront(nil)

    // Dismiss on click outside
    clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
        self?.hidePanel()
    }
}

func hidePanel() {
    if let monitor = clickMonitor {
        NSEvent.removeMonitor(monitor)
        clickMonitor = nil
    }
    panel?.orderOut(nil)
}
```

**Step 2: Add escape key handling in Panel.swift**

Override `keyDown` in `FloatingPanel`:

```swift
var onDismiss: (() -> Void)?

override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 { // Escape key
        onDismiss?()
    } else {
        super.keyDown(with: event)
    }
}
```

**Step 3: Wire up the panel's onDismiss in showPanel()**

After creating the panel:

```swift
panel.onDismiss = { [weak self] in
    self?.hidePanel()
}
```

**Step 4: Clear the search query when hiding the panel**

This requires making the query resettable. Update `SearchView` to accept a `Binding<String>` for the query, and clear it in `hidePanel()`. Alternatively, recreate the hosting view each time. The simplest approach: recreate the content view in `showPanel()` each time (it's lightweight).

Move the `hostingView` setup so it runs every call to `showPanel()` (not just the first time):

```swift
func showPanel() {
    if panel == nil {
        // ... create panel ...
    }

    guard let panel = panel, let screen = NSScreen.main else { return }

    // Fresh SwiftUI view each time (resets query to "")
    let hostingView = NSHostingView(rootView: SearchView(onDismiss: { [weak self] in
        self?.hidePanel()
    }))
    hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 44)
    panel.contentView = hostingView

    // ... position and show ...
}
```

**Step 5: Build and verify**

Run: `swift build 2>&1`
Expected: Build succeeds

**Step 6: Commit**

```bash
git add Sources/swiftmoji/Panel.swift Sources/swiftmoji/App.swift Sources/swiftmoji/SearchView.swift
git commit -m "feat: dismiss panel on escape, click outside, and reset search"
```

---

### Task 6: Manual Integration Test

**Step 1: Build and run the app**

Run: `swift build && swift run swiftmoji`

**Step 2: Verify manually**

- [ ] App launches with no Dock icon
- [ ] Press opt+e → panel appears centered in upper third of screen
- [ ] Panel has a search field with magnifying glass icon
- [ ] Typing in the search field works
- [ ] Press opt+e again → panel hides (toggle)
- [ ] Press escape → panel hides
- [ ] Click anywhere outside panel → panel hides
- [ ] Reopen panel → search field is cleared
- [ ] Panel floats above other windows

**Step 3: Commit any fixes needed**

```bash
git add -A
git commit -m "fix: integration test fixes for panel behavior"
```
