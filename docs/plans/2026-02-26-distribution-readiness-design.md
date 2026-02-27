# Distribution Readiness Design

## Goal

Make Swiftmoji distributable as a proper macOS `.app` bundle via direct distribution (notarized, not App Store).

## Decision: Direct Distribution

Swiftmoji uses `CGEvent.tapCreate()` for global hotkeys, which requires Accessibility permissions incompatible with App Sandbox. Direct distribution (notarized .dmg/.zip) is the standard approach for utility apps like this.

## Approach: Xcode Project Wrapping SPM

Add an Xcode project that references the existing `SwiftmojiCore` SPM package. This keeps the clean SPM structure for library code and tests while using Xcode for app bundle assembly, code signing, and notarization.

## Changes

### New Files
- `Swiftmoji.xcodeproj` — macOS App target depending on local SwiftmojiCore package
- `Swiftmoji.entitlements` — Accessibility permission declaration
- Complete `Info.plist` — bundle ID, version, LSUIElement, usage descriptions

### Modified Files
- `Package.swift` — remove `swiftmoji` executable target; keep SwiftmojiCore + tests

### No Code Changes
All Swift source files remain identical. They move from the SPM executable target to the Xcode app target.

## Build Workflow
- `swift test` — runs unit tests via SPM (unchanged)
- Xcode — build, run, archive, notarize the .app

## Out of Scope
- App icon
- DMG installer
- Auto-update (Sparkle)
- Onboarding UI for Accessibility permissions
