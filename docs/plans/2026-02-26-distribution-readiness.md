# Distribution Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Swiftmoji a proper `.app` bundle that can be built, signed, and notarized via Xcode for direct distribution.

**Architecture:** Add an Xcode project that references the existing SwiftmojiCore SPM package. The Xcode project contains a macOS App target with the UI source files. SPM continues to own the library and test targets.

**Tech Stack:** Xcode 26.1, Swift 6.2, macOS 13+, SwiftPM (for library/tests)

---

### Task 1: Create the Xcode Project

This task creates the Xcode project file using `xcodebuild` scaffolding. Since Xcode project files are complex XML/plist structures, we'll create it via Xcode's command line tools.

**Files:**
- Create: `Swiftmoji.xcodeproj/project.pbxproj`

**Step 1: Generate the Xcode project**

Open Xcode and create a new macOS App project. From the terminal:

```bash
cd /Users/rv/conductor/workspaces/swiftmoji/el-paso

# Use a Python script to generate the .pbxproj since it's a structured plist
# The project needs:
# - macOS App target named "Swiftmoji"
# - Swift language
# - SwiftUI lifecycle (but we use custom AppDelegate, so minimal)
# - Local SwiftmojiCore package dependency
# - All app source files from Sources/swiftmoji/
```

Actually, the simplest approach: use `swift package generate-xcodeproj` or manually create via Xcode GUI. Since we can't automate Xcode GUI, we'll create the project programmatically using a minimal pbxproj.

**Step 1: Create the Xcode project structure**

Create the `.xcodeproj` bundle directory and the `project.pbxproj` file. The project must:

1. Define a native macOS App target called "Swiftmoji"
2. Reference these source files (from `Sources/swiftmoji/`):
   - `App.swift`
   - `Panel.swift`
   - `SearchView.swift`
   - `SearchState.swift`
   - `ComboFormView.swift`
   - `HotkeyManager.swift`
   - `Info.plist`
3. Add a local Swift package dependency on the root `Package.swift` for `SwiftmojiCore`
4. Set build settings:
   - `MACOSX_DEPLOYMENT_TARGET = 13.0`
   - `PRODUCT_BUNDLE_IDENTIFIER = com.swiftmoji.app`
   - `MARKETING_VERSION = 1.0.0`
   - `CURRENT_PROJECT_VERSION = 1`
   - `INFOPLIST_FILE = Sources/swiftmoji/Info.plist`
   - `CODE_SIGN_ENTITLEMENTS = Swiftmoji.entitlements`
   - `SWIFT_VERSION = 6.0`
   - `PRODUCT_NAME = Swiftmoji`
   - `GENERATE_INFOPLIST_FILE = NO` (we provide our own)

**Step 2: Verify project loads**

```bash
xcodebuild -project Swiftmoji.xcodeproj -list
```

Expected: Shows "Swiftmoji" target.

**Step 3: Commit**

```bash
git add Swiftmoji.xcodeproj
git commit -m "feat: add Xcode project for app bundle distribution"
```

---

### Task 2: Create Entitlements File

**Files:**
- Create: `Swiftmoji.entitlements`

**Step 1: Create the entitlements plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
</dict>
</plist>
```

Note: We explicitly disable sandbox since CGEvent tap requires Accessibility access which is incompatible with sandboxing. For direct distribution (notarized outside App Store), this is fine.

**Step 2: Commit**

```bash
git add Swiftmoji.entitlements
git commit -m "feat: add entitlements file (no sandbox for Accessibility API)"
```

---

### Task 3: Complete Info.plist

**Files:**
- Modify: `Sources/swiftmoji/Info.plist`

**Step 1: Update Info.plist with required fields**

Replace the current minimal Info.plist with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Swiftmoji</string>
    <key>CFBundleDisplayName</key>
    <string>Swiftmoji</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Swiftmoji. All rights reserved.</string>
</dict>
</plist>
```

Key fields:
- `LSUIElement = true` — keeps the app as a background agent (no Dock icon)
- `CFBundleIdentifier` uses Xcode variable `$(PRODUCT_BUNDLE_IDENTIFIER)`
- Version fields use Xcode variables for single source of truth

**Step 2: Commit**

```bash
git add Sources/swiftmoji/Info.plist
git commit -m "feat: complete Info.plist with bundle metadata"
```

---

### Task 4: Update Package.swift

**Files:**
- Modify: `Package.swift`

**Step 1: Remove the executable target**

The executable target moves to the Xcode project. Keep SwiftmojiCore as a library (now needs to be a `products` export so the Xcode project can depend on it) and the test target.

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftmoji",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftmojiCore", targets: ["SwiftmojiCore"]),
    ],
    targets: [
        .target(
            name: "SwiftmojiCore",
            resources: [.copy("Resources/emoji-test.txt")]
        ),
        .testTarget(
            name: "swiftmojiTests",
            dependencies: ["SwiftmojiCore"]
        ),
    ]
)
```

**Step 2: Verify tests still pass**

```bash
swift test
```

Expected: All 39 tests pass.

**Step 3: Commit**

```bash
git add Package.swift
git commit -m "refactor: export SwiftmojiCore as library product, remove executable target"
```

---

### Task 5: Build and Verify

**Step 1: Build the Xcode project from command line**

```bash
xcodebuild -project Swiftmoji.xcodeproj -scheme Swiftmoji -configuration Debug build
```

Expected: BUILD SUCCEEDED. Produces `Swiftmoji.app` in derived data.

**Step 2: Verify the .app bundle structure**

```bash
# Find the built app
APP_PATH=$(xcodebuild -project Swiftmoji.xcodeproj -scheme Swiftmoji -configuration Debug -showBuildSettings 2>/dev/null | grep " BUILT_PRODUCTS_DIR" | awk '{print $3}')
ls "$APP_PATH/Swiftmoji.app/Contents/"
cat "$APP_PATH/Swiftmoji.app/Contents/Info.plist"
```

Expected: Contains `MacOS/`, `Resources/`, `Info.plist` with correct bundle ID and version.

**Step 3: Verify SPM tests still pass**

```bash
swift test
```

Expected: All 39 tests pass.

**Step 4: Commit any fixes needed**

If build issues arise, fix and commit.
