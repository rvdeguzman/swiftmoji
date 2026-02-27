# Emoji Combos Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let users create multi-emoji shortcuts ("combos") that appear alongside regular search results.

**Architecture:** A `ComboStore` manages CRUD + JSON persistence for `Combo` structs. `EmojiSearcher` accepts combos and converts them to virtual `Emoji` structs for unified fuzzy search. A `ComboFormView` SwiftUI view handles creation. `FloatingPanel` intercepts Cmd+N (create) and Cmd+Backspace (delete).

**Tech Stack:** Swift 6.2, SwiftUI, AppKit (NSPanel), swift-testing (TDD)

---

### Task 1: ComboStore with TDD

**Files:**
- Create: `Sources/SwiftmojiCore/ComboStore.swift`
- Create: `Tests/swiftmojiTests/ComboStoreTests.swift`

**Step 1: Write the failing tests**

```swift
// Tests/swiftmojiTests/ComboStoreTests.swift
import Testing
import Foundation
@testable import SwiftmojiCore

@Suite("ComboStore")
struct ComboStoreTests {

    @Test func addAndListCombos() {
        let store = ComboStore()
        let combo = store.add(names: ["ackshuwally", "nerd"], characters: "☝️🤓")

        let all = store.all()
        #expect(all.count == 1)
        #expect(all[0].names == ["ackshuwally", "nerd"])
        #expect(all[0].characters == "☝️🤓")
        #expect(all[0].id == combo.id)
    }

    @Test func deleteCombo() {
        let store = ComboStore()
        let combo = store.add(names: ["shrug"], characters: "🤷")
        store.delete(id: combo.id)

        #expect(store.all().isEmpty)
    }

    @Test func deleteNonexistentIsNoOp() {
        let store = ComboStore()
        store.delete(id: UUID())
        #expect(store.all().isEmpty)
    }

    @Test func persistenceRoundTrip() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("combo-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = ComboStore(storageURL: tempURL)
        store.add(names: ["lenny"], characters: "( ͡° ͜ʖ ͡°)")
        store.save()

        let loaded = ComboStore(storageURL: tempURL)
        #expect(loaded.all().count == 1)
        #expect(loaded.all()[0].names == ["lenny"])
    }

    @Test func toEmojis() {
        let store = ComboStore()
        store.add(names: ["ackshuwally", "nerd"], characters: "☝️🤓")

        let emojis = store.toEmojis()
        #expect(emojis.count == 1)
        #expect(emojis[0].character == "☝️🤓")
        #expect(emojis[0].name == "ackshuwally")
        #expect(emojis[0].keywords == ["nerd"])
    }

    @Test func toEmojisWithSingleName() {
        let store = ComboStore()
        store.add(names: ["shrug"], characters: "🤷")

        let emojis = store.toEmojis()
        #expect(emojis[0].name == "shrug")
        #expect(emojis[0].keywords.isEmpty)
    }

    @Test func isCombo() {
        let store = ComboStore()
        store.add(names: ["ackshuwally"], characters: "☝️🤓")

        #expect(store.isCombo(character: "☝️🤓") == true)
        #expect(store.isCombo(character: "🐶") == false)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter ComboStore 2>&1 | tail -5`
Expected: Compilation error — `ComboStore` not found.

**Step 3: Write minimal implementation**

```swift
// Sources/SwiftmojiCore/ComboStore.swift
import Foundation

public struct Combo: Codable, Sendable {
    public let id: UUID
    public var names: [String]
    public var characters: String
}

public class ComboStore: @unchecked Sendable {
    private var combos: [Combo] = []
    private let storageURL: URL?

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        if let url = storageURL {
            load(from: url)
        }
    }

    @discardableResult
    public func add(names: [String], characters: String) -> Combo {
        let combo = Combo(id: UUID(), names: names, characters: characters)
        combos.append(combo)
        return combo
    }

    public func delete(id: UUID) {
        combos.removeAll { $0.id == id }
    }

    public func all() -> [Combo] {
        combos
    }

    public func isCombo(character: String) -> Bool {
        combos.contains { $0.characters == character }
    }

    public func toEmojis() -> [Emoji] {
        combos.map { combo in
            Emoji(
                character: combo.characters,
                name: combo.names[0],
                keywords: Array(combo.names.dropFirst())
            )
        }
    }

    public func save() {
        guard let url = storageURL else { return }
        if let data = try? JSONEncoder().encode(combos) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func load(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Combo].self, from: data)
        else { return }
        combos = decoded
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter ComboStore 2>&1 | tail -10`
Expected: All 7 tests PASS.

**Step 5: Commit**

```bash
git add Sources/SwiftmojiCore/ComboStore.swift Tests/swiftmojiTests/ComboStoreTests.swift
git commit -m "feat: add ComboStore with CRUD and JSON persistence"
```

---

### Task 2: Integrate combos into EmojiSearcher

**Files:**
- Modify: `Sources/SwiftmojiCore/EmojiSearcher.swift:1-41`
- Modify: `Tests/swiftmojiTests/EmojiSearcherTests.swift`

**Step 1: Write the failing test**

Add to the existing `EmojiSearcherTests.swift`:

```swift
@Test func searchIncludesCombos() {
    let emojis = [
        Emoji(character: "🤓", name: "nerd face"),
    ]
    let store = ComboStore()
    store.add(names: ["ackshuwally", "nerd"], characters: "☝️🤓")

    let searcher = EmojiSearcher(emojis: emojis, comboStore: store)
    let results = searcher.search(query: "ackshuwally")

    #expect(results.contains { $0.character == "☝️🤓" })
}

@Test func comboMatchesByAlias() {
    let searcher = EmojiSearcher(emojis: [], comboStore: {
        let s = ComboStore()
        s.add(names: ["ackshuwally", "nerd"], characters: "☝️🤓")
        return s
    }())
    let results = searcher.search(query: "nerd")

    #expect(results.contains { $0.character == "☝️🤓" })
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter EmojiSearcher 2>&1 | tail -5`
Expected: Compilation error — `EmojiSearcher` has no `comboStore` parameter.

**Step 3: Modify EmojiSearcher to accept ComboStore**

Update `Sources/SwiftmojiCore/EmojiSearcher.swift`:

```swift
public class EmojiSearcher: @unchecked Sendable {
    private let emojis: [Emoji]
    private let comboStore: ComboStore?
    private static let maxResults = 50

    public init(emojis: [Emoji], comboStore: ComboStore? = nil) {
        self.emojis = emojis
        self.comboStore = comboStore
    }

    public func search(query: String, pickHistory: PickHistory? = nil) -> [Emoji] {
        guard !query.isEmpty else { return [] }

        let comboEmojis = comboStore?.toEmojis() ?? []
        let allEmojis = emojis + comboEmojis

        var scored: [(emoji: Emoji, score: Int)] = []

        for emoji in allEmojis {
            var bestScore = 0

            if let nameScore = FuzzyMatcher.score(query: query, against: emoji.name) {
                bestScore = nameScore
            }

            for keyword in emoji.keywords {
                if let kwScore = FuzzyMatcher.score(query: query, against: keyword) {
                    let adjusted = max(1, kwScore - 5)
                    bestScore = max(bestScore, adjusted)
                }
            }

            if bestScore > 0 {
                if let history = pickHistory {
                    let picks = history.pickCount(query: query, emojiCharacter: emoji.character)
                    bestScore += picks * 50
                }
                scored.append((emoji, bestScore))
            }
        }

        scored.sort { $0.score > $1.score }

        return Array(scored.prefix(Self.maxResults).map(\.emoji))
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter EmojiSearcher 2>&1 | tail -10`
Expected: All tests PASS (existing + 2 new).

**Step 5: Commit**

```bash
git add Sources/SwiftmojiCore/EmojiSearcher.swift Tests/swiftmojiTests/EmojiSearcherTests.swift
git commit -m "feat: integrate combos into emoji search as virtual emojis"
```

---

### Task 3: ComboFormView (SwiftUI)

**Files:**
- Create: `Sources/swiftmoji/ComboFormView.swift`

This is a UI task — no unit tests, verified by manual testing later.

**Step 1: Create ComboFormView**

```swift
// Sources/swiftmoji/ComboFormView.swift
import SwiftUI
import SwiftmojiCore

struct ComboFormView: View {
    @State private var name: String = ""
    @State private var aliases: [String] = []
    @State private var newAlias: String = ""
    @State private var characters: String = ""
    @State private var showingAliasField: Bool = false
    @FocusState private var isNameFocused: Bool

    var onSave: ([String], String) -> Void
    var onCancel: () -> Void

    private var allNames: [String] {
        let primary = name.trimmingCharacters(in: .whitespaces)
        let extras = aliases.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !primary.isEmpty else { return [] }
        return [primary] + extras
    }

    private var canSave: Bool {
        !allNames.isEmpty && !characters.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Combo")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("esc to cancel")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Name field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("e.g. ackshuwally", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .focused($isNameFocused)
                        Button(action: { showingAliasField = true }) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Add alias")
                    }
                }

                // Aliases
                if showingAliasField || !aliases.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aliases")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        ForEach(aliases.indices, id: \.self) { i in
                            HStack {
                                Text(aliases[i])
                                    .font(.system(size: 14))
                                Spacer()
                                Button(action: { aliases.remove(at: i) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if showingAliasField {
                            HStack {
                                TextField("alias", text: $newAlias)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .onSubmit {
                                        let trimmed = newAlias.trimmingCharacters(in: .whitespaces)
                                        if !trimmed.isEmpty {
                                            aliases.append(trimmed)
                                            newAlias = ""
                                        }
                                        showingAliasField = false
                                    }
                            }
                        }
                    }
                }

                // Emoji field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emojis")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("e.g. ☝️🤓", text: $characters)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24))
                }

                // Save button
                HStack {
                    Spacer()
                    Button("Save") {
                        if canSave {
                            onSave(allNames, characters.trimmingCharacters(in: .whitespaces))
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(!canSave)
                }
            }
            .padding(16)
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand {
            onCancel()
        }
        .onAppear {
            isNameFocused = true
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add Sources/swiftmoji/ComboFormView.swift
git commit -m "feat: add ComboFormView for creating emoji combos"
```

---

### Task 4: Wire combos into App.swift and Panel

**Files:**
- Modify: `Sources/swiftmoji/App.swift:31-160`
- Modify: `Sources/swiftmoji/Panel.swift:1-62`

**Step 1: Add Cmd+N and Cmd+Backspace to FloatingPanel**

Add new callback properties and key handling to `Sources/swiftmoji/Panel.swift`. Add these properties after the existing `onArrowDown`:

```swift
nonisolated(unsafe) var onCreateCombo: (() -> Void)?
nonisolated(unsafe) var onDeleteCombo: (() -> Void)?
```

Add these cases in `sendEvent` before the `default:` case:

```swift
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
```

**Step 2: Add ComboStore and wiring to App.swift**

In `AppDelegate`, add a `comboStore` property:

```swift
private var comboStore: ComboStore?
```

In `applicationDidFinishLaunching`, after `pickHistory` initialization, add:

```swift
comboStore = ComboStore(storageURL: historyURL.appendingPathComponent("combos.json"))
```

Update the `EmojiSearcher` initialization to include comboStore:

```swift
emojiSearcher = EmojiSearcher(emojis: emojis, comboStore: comboStore)
```

Wire the panel callbacks in `showPanel()` after the existing arrow callbacks:

```swift
panel.onCreateCombo = { [weak self] in
    self?.showComboForm()
}
panel.onDeleteCombo = { [weak self] in
    self?.deleteSelectedCombo()
}
```

Add `showComboForm()` and `deleteSelectedCombo()` methods to AppDelegate:

```swift
func showComboForm() {
    guard let panel = panel else { return }

    let hostingView = NSHostingView(rootView: ComboFormView(
        onSave: { [weak self] names, characters in
            self?.comboStore?.add(names: names, characters: characters)
            self?.comboStore?.save()
            self?.showPanel() // Switch back to search view
        },
        onCancel: { [weak self] in
            self?.showPanel() // Switch back to search view
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

func deleteSelectedCombo() {
    let index = searchState.selectedIndex
    // We need to check if the currently selected result is a combo
    // Re-run search to get current results, then check
    // This is wired through SearchView which tracks results
}
```

**Step 3: Handle combo deletion through SearchView**

The deletion flow needs access to the current search results. Add an `onDeleteCombo` callback to `SearchView`:

In `Sources/swiftmoji/SearchView.swift`, add a new callback property:

```swift
var onDeleteCombo: ((Emoji) -> Void)?
```

This callback is invoked from App.swift's panel.onDeleteCombo by having SearchView expose the selected emoji. However, since SearchView's state is internal, a simpler approach: add an `onDeleteSelected` closure to SearchView that App.swift passes, and SearchView calls it with the currently selected emoji.

Actually, the cleanest approach: have `App.swift` store the current results in `SearchState` (or a shared state), so `deleteSelectedCombo()` can look up what's selected. But that couples things.

Simplest approach: pass `comboStore` to `SearchView`, and handle Cmd+Backspace deletion there by adding a callback. In `App.swift`'s `panel.onDeleteCombo`:

```swift
panel.onDeleteCombo = { [weak self] in
    // Post notification or use a shared callback
    self?.searchState.deleteRequested = true
}
```

Add to `SearchState.swift`:

```swift
@Published var deleteRequested: Bool = false
```

In `SearchView`, observe `deleteRequested` and handle:

```swift
.onChange(of: searchState.deleteRequested) { requested in
    if requested {
        searchState.deleteRequested = false
        let index = searchState.selectedIndex
        if index < results.count {
            onDeleteCombo?(results[index])
        }
    }
}
```

In `App.swift`'s `showPanel()`, add the `onDeleteCombo` handler:

```swift
onDeleteCombo: { [weak self] emoji in
    guard let self, let comboStore = self.comboStore else { return }
    if comboStore.isCombo(character: emoji.character) {
        comboStore.delete(character: emoji.character)
        comboStore.save()
        // Refresh results by re-triggering search
        // The query hasn't changed, so we need to manually refresh
    }
},
```

Add a `delete(character:)` convenience to `ComboStore`:

```swift
public func delete(character: String) {
    combos.removeAll { $0.characters == character }
}
```

**Step 4: Build and verify**

Run: `swift build 2>&1 | tail -5`
Expected: Build succeeds.

**Step 5: Commit**

```bash
git add Sources/swiftmoji/App.swift Sources/swiftmoji/Panel.swift Sources/swiftmoji/SearchView.swift Sources/swiftmoji/SearchState.swift Sources/SwiftmojiCore/ComboStore.swift
git commit -m "feat: wire combo creation (Cmd+N) and deletion (Cmd+Backspace) into app"
```

---

### Task 5: Manual integration test

**Files:** None (testing only)

**Step 1: Build and run**

Run: `swift build && .build/debug/swiftmoji`

**Step 2: Test combo creation**

1. Press opt+e to open panel
2. Press Cmd+N — should switch to combo form
3. Type "ackshuwally" in name field
4. Click "+" to add alias "nerd"
5. Type "☝️🤓" in emoji field (use macOS emoji picker: Ctrl+Cmd+Space)
6. Press Enter to save
7. Panel should switch back to search view

**Step 3: Test combo search**

1. Type "ackshuwally" — should see ☝️🤓 in results
2. Type "nerd" — should also see ☝️🤓 alongside 🤓
3. Select and press Enter — should paste ☝️🤓

**Step 4: Test combo deletion**

1. Search for "ackshuwally"
2. Select the combo result
3. Press Cmd+Backspace — combo should be removed
4. Search again — combo should no longer appear

**Step 5: Test persistence**

1. Create a combo, quit the app, relaunch
2. Search for the combo — should still exist

**Step 6: Commit if fixes needed**

```bash
git add -A && git commit -m "fix: address integration test findings for emoji combos"
```
