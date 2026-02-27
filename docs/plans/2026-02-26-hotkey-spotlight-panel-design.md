# Swiftmoji: Global Hotkey + Spotlight Panel Design

## Overview

Swiftmoji is a macOS background agent that provides a Spotlight-like emoji fuzzy-finder. Users press opt+e to open a floating panel, type to search emojis, and select one to paste it directly into the focused app.

## Architecture: SwiftUI + NSPanel

- **UI framework**: SwiftUI views hosted in an NSPanel via NSHostingView
- **Window management**: Custom NSPanel subclass for Spotlight-like behavior
- **Global hotkey**: CGEvent tap for system-wide opt+e detection
- **Emoji paste**: Pasteboard + simulated Cmd+V via CGEvent

## App Lifecycle

- SPM executable converted to a proper macOS app
- `LSUIElement = true` — no Dock icon, no menu bar icon
- `@main` entry point is an NSApplicationDelegate that registers the hotkey on launch

## Global Hotkey (opt+e)

- `CGEvent.tapCreate` registers a system-wide event tap
- Filters for `.keyDown` events, checks for `e` keycode + option modifier
- Toggles the panel on/off
- Requires Accessibility permissions (prompted on first launch)

## Panel (NSPanel)

Custom NSPanel subclass:
- **Floating level** (`NSWindow.Level.floating`)
- **Non-activating** (`NSPanel.StyleMask.nonactivatingPanel`) — keeps target app focused
- **Borderless** — no title bar, rounded corners, drop shadow
- **Positioned** center-horizontal, upper third of screen (like Spotlight)
- **Dismisses on**: escape key, clicking outside, selecting an emoji

## SwiftUI Content

Hosted inside the panel via NSHostingView:
- **Search field**: TextField, auto-focuses when panel appears
- **Results list**: Vertical list of matching emojis (emoji + name), max ~8 visible rows
- **Keyboard navigation**: Up/down arrows move selection, Enter selects

## Emoji Paste

When user selects an emoji:
1. Close the panel
2. Save current pasteboard contents
3. Copy emoji to NSPasteboard
4. Simulate Cmd+V via CGEvent to paste into frontmost app
5. Restore previous pasteboard contents after short delay

## Decisions

- **No menu bar icon** — runs as invisible background agent
- **Paste into focused app** (not clipboard copy) — like Raycast emoji picker
- **Spotlight-style UI** — single text field with dropdown result list
