import AppKit

class HotkeyManager: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    nonisolated(unsafe) private let onHotkey: () -> Void

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
