# Kaomoji Tab Toggle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add kaomoji search mode toggled via Tab key, with tab labels showing active mode.

**Architecture:** Add kaomoji JSON files as SwiftmojiCore resources. New `KaomojiDataParser` loads them into `[Emoji]`. `EmojiSearcher` gains a `searchKaomoji()` method. `SearchState` tracks active mode. `SearchView` renders tab labels and switches data source. `FloatingPanel` routes Tab to mode toggle instead of arrow-down.

**Tech Stack:** Swift 6.2, SwiftUI, macOS 13+, Swift Testing

---

### Task 1: Add kaomoji JSON resources to SwiftmojiCore

**Files:**
- Create: `Sources/SwiftmojiCore/Resources/kaomoji-lib.json`
- Create: `Sources/SwiftmojiCore/Resources/kaomoji-ordered.json`
- Modify: `Package.swift:14`

**Step 1: Copy kaomoji JSON files into Resources**

Copy `.context/attachments/lib.json` to `Sources/SwiftmojiCore/Resources/kaomoji-lib.json` and `.context/attachments/ordered.json` to `Sources/SwiftmojiCore/Resources/kaomoji-ordered.json`.

**Step 2: Add resource declarations to Package.swift**

In `Package.swift`, change line 14 from:
```swift
            resources: [.copy("Resources/emoji-test.txt")]
```
to:
```swift
            resources: [
                .copy("Resources/emoji-test.txt"),
                .copy("Resources/kaomoji-lib.json"),
                .copy("Resources/kaomoji-ordered.json"),
            ]
```

**Step 3: Verify it builds**

Run: `swift build 2>&1 | tail -5`
Expected: Build Succeeded

**Step 4: Commit**

```bash
git add Sources/SwiftmojiCore/Resources/kaomoji-lib.json Sources/SwiftmojiCore/Resources/kaomoji-ordered.json Package.swift
git commit -m "feat: add kaomoji JSON data as bundle resources"
```

---

### Task 2: Create KaomojiDataParser with tests

**Files:**
- Create: `Sources/SwiftmojiCore/KaomojiDataParser.swift`
- Create: `Tests/swiftmojiTests/KaomojiDataParserTests.swift`

**Step 1: Write the failing tests**

Create `Tests/swiftmojiTests/KaomojiDataParserTests.swift`:

```swift
import Testing
import Foundation
@testable import SwiftmojiCore

@Suite("KaomojiDataParser")
struct KaomojiDataParserTests {

    @Test func parseLibEntry() {
        let json: [String: Any] = [
            "bear": [
                "name": "Bear",
                "entry": "ˁ(⦿ᴥ⦿)ˀ",
                "keywords": ["bear"],
                "category": "animal"
            ] as [String: Any]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let result = KaomojiDataParser.parseLib(data: data)

        #expect(result.count == 1)
        #expect(result["bear"]?.character == "ˁ(⦿ᴥ⦿)ˀ")
        #expect(result["bear"]?.name == "Bear")
        #expect(result["bear"]?.keywords == ["bear"])
    }

    @Test func loadAllReturnsNonEmpty() {
        let kaomojis = KaomojiDataParser.loadAll()
        #expect(kaomojis.count > 100)
    }

    @Test func orderedEntriesAppearFirst() {
        let kaomojis = KaomojiDataParser.loadAll()
        // "afraid" is the first entry in kaomoji-ordered.json
        // It should appear near the beginning
        guard let afraidIndex = kaomojis.firstIndex(where: { $0.name.lowercased() == "afraid" }) else {
            Issue.record("'afraid' not found in kaomojis")
            return
        }
        #expect(afraidIndex < 300) // ordered entries should be in the first portion
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter KaomojiDataParser 2>&1 | tail -10`
Expected: Compilation error — `KaomojiDataParser` not defined

**Step 3: Implement KaomojiDataParser**

Create `Sources/SwiftmojiCore/KaomojiDataParser.swift`:

```swift
import Foundation

public enum KaomojiDataParser {

    /// Parse the kaomoji library JSON data into a dictionary keyed by ID.
    public static func parseLib(data: Data) -> [String: Emoji] {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return [:]
        }

        var result: [String: Emoji] = [:]
        for (key, value) in raw {
            guard let name = value["name"] as? String,
                  let entry = value["entry"] as? String else { continue }
            let keywords = value["keywords"] as? [String] ?? []
            result[key] = Emoji(character: entry, name: name, keywords: keywords)
        }
        return result
    }

    /// Load all kaomojis from bundled resources.
    /// Ordered entries appear first, followed by remaining entries alphabetically.
    public static func loadAll() -> [Emoji] {
        guard let libURL = Bundle.module.url(forResource: "kaomoji-lib", withExtension: "json"),
              let libData = try? Data(contentsOf: libURL) else {
            print("Failed to load kaomoji-lib.json from bundle")
            return []
        }

        let lib = parseLib(data: libData)

        // Load ordering
        var orderedKeys: [String] = []
        if let orderURL = Bundle.module.url(forResource: "kaomoji-ordered", withExtension: "json"),
           let orderData = try? Data(contentsOf: orderURL),
           let keys = try? JSONDecoder().decode([String].self, from: orderData) {
            orderedKeys = keys
        }

        // Ordered entries first
        var result: [Emoji] = []
        var seen = Set<String>()
        for key in orderedKeys {
            if let emoji = lib[key] {
                result.append(emoji)
                seen.insert(key)
            }
        }

        // Remaining entries alphabetically
        for key in lib.keys.sorted() where !seen.contains(key) {
            result.append(lib[key]!)
        }

        return result
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `swift test --filter KaomojiDataParser 2>&1 | tail -10`
Expected: All 3 tests pass

**Step 5: Commit**

```bash
git add Sources/SwiftmojiCore/KaomojiDataParser.swift Tests/swiftmojiTests/KaomojiDataParserTests.swift
git commit -m "feat: add KaomojiDataParser with tests"
```

---

### Task 3: Add kaomoji search to EmojiSearcher with tests

**Files:**
- Modify: `Sources/SwiftmojiCore/EmojiSearcher.swift`
- Modify: `Tests/swiftmojiTests/EmojiSearcherTests.swift`

**Step 1: Write the failing tests**

Append to `Tests/swiftmojiTests/EmojiSearcherTests.swift`:

```swift
    @Test func searchKaomojiByName() {
        let kaomojis = [
            Emoji(character: "ˁ(⦿ᴥ⦿)ˀ", name: "Bear", keywords: ["bear"]),
            Emoji(character: "( ͡° ͜ʖ ͡°)", name: "Lenny Face", keywords: ["lenny", "face"]),
        ]
        let searcher = EmojiSearcher(emojis: testEmojis, kaomojis: kaomojis)
        let results = searcher.searchKaomoji(query: "bear")

        #expect(results.count == 1)
        #expect(results[0].character == "ˁ(⦿ᴥ⦿)ˀ")
    }

    @Test func searchKaomojiByKeyword() {
        let kaomojis = [
            Emoji(character: "( ͡° ͜ʖ ͡°)", name: "Lenny Face", keywords: ["lenny", "face"]),
        ]
        let searcher = EmojiSearcher(emojis: testEmojis, kaomojis: kaomojis)
        let results = searcher.searchKaomoji(query: "lenny")

        #expect(results.count == 1)
        #expect(results[0].character == "( ͡° ͜ʖ ͡°)")
    }

    @Test func searchKaomojiEmptyQueryReturnsEmpty() {
        let kaomojis = [
            Emoji(character: "ˁ(⦿ᴥ⦿)ˀ", name: "Bear", keywords: ["bear"]),
        ]
        let searcher = EmojiSearcher(emojis: testEmojis, kaomojis: kaomojis)
        let results = searcher.searchKaomoji(query: "")
        #expect(results.isEmpty)
    }
```

**Step 2: Run tests to verify they fail**

Run: `swift test --filter EmojiSearcher 2>&1 | tail -10`
Expected: Compilation error — no `kaomojis` parameter or `searchKaomoji` method

**Step 3: Add kaomojis to EmojiSearcher**

Modify `Sources/SwiftmojiCore/EmojiSearcher.swift`. Add a `kaomojis` property and `searchKaomoji` method:

```swift
public class EmojiSearcher: @unchecked Sendable {
    private let emojis: [Emoji]
    private let kaomojis: [Emoji]
    private let comboStore: ComboStore?
    private static let maxResults = 50

    public init(emojis: [Emoji], kaomojis: [Emoji] = [], comboStore: ComboStore? = nil) {
        self.emojis = emojis
        self.kaomojis = kaomojis
        self.comboStore = comboStore
    }

    public func search(query: String, pickHistory: PickHistory? = nil) -> [Emoji] {
        guard !query.isEmpty else { return [] }

        let comboEmojis = comboStore?.toEmojis() ?? []
        let allEmojis = emojis + comboEmojis

        return rankedSearch(query: query, candidates: allEmojis, pickHistory: pickHistory)
    }

    public func searchKaomoji(query: String, pickHistory: PickHistory? = nil) -> [Emoji] {
        guard !query.isEmpty else { return [] }
        return rankedSearch(query: query, candidates: kaomojis, pickHistory: pickHistory)
    }

    private func rankedSearch(query: String, candidates: [Emoji], pickHistory: PickHistory?) -> [Emoji] {
        var scored: [(emoji: Emoji, score: Int)] = []

        for emoji in candidates {
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

**Step 4: Run all EmojiSearcher tests**

Run: `swift test --filter EmojiSearcher 2>&1 | tail -10`
Expected: All tests pass (existing + 3 new)

**Step 5: Commit**

```bash
git add Sources/SwiftmojiCore/EmojiSearcher.swift Tests/swiftmojiTests/EmojiSearcherTests.swift
git commit -m "feat: add kaomoji search to EmojiSearcher"
```

---

### Task 4: Add SearchMode to SearchState

**Files:**
- Modify: `Sources/swiftmoji/SearchState.swift`

**Step 1: Add SearchMode enum and mode property**

Replace the full contents of `Sources/swiftmoji/SearchState.swift` with:

```swift
import SwiftUI

enum SearchMode {
    case emoji
    case kaomoji
}

class SearchState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var deleteRequested: Bool = false
    @Published var mode: SearchMode = .emoji

    func moveUp(resultCount: Int) {
        guard resultCount > 0 else { return }
        selectedIndex = selectedIndex <= 0 ? resultCount - 1 : selectedIndex - 1
    }

    func moveDown(resultCount: Int) {
        guard resultCount > 0 else { return }
        selectedIndex = selectedIndex >= resultCount - 1 ? 0 : selectedIndex + 1
    }

    func toggleMode() {
        mode = mode == .emoji ? .kaomoji : .emoji
        selectedIndex = 0
    }

    func reset() {
        selectedIndex = 0
        mode = .emoji
    }
}
```

**Step 2: Verify it builds**

Run: `swift build 2>&1 | tail -5`
Expected: Build Succeeded

**Step 3: Commit**

```bash
git add Sources/swiftmoji/SearchState.swift
git commit -m "feat: add SearchMode enum and toggle to SearchState"
```

---

### Task 5: Update SearchView with tab labels and mode switching

**Files:**
- Modify: `Sources/swiftmoji/SearchView.swift`

**Step 1: Update SearchView**

Replace the full contents of `Sources/swiftmoji/SearchView.swift` with:

```swift
import SwiftUI
import SwiftmojiCore

struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [Emoji] = []
    @FocusState private var isSearchFocused: Bool
    @ObservedObject var searchState: SearchState

    let searcher: EmojiSearcher
    let pickHistory: PickHistory
    var onSelect: (Emoji, String) -> Void
    var onDismiss: () -> Void
    var onDeleteCombo: ((Emoji) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Tab labels
            HStack(spacing: 0) {
                tabLabel("Emoji", isActive: searchState.mode == .emoji)
                tabLabel("Kaomoji", isActive: searchState.mode == .kaomoji)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))

                TextField(
                    searchState.mode == .emoji ? "Search emoji..." : "Search kaomoji...",
                    text: $query
                )
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($isSearchFocused)
                .onChange(of: query) { newValue in
                    performSearch(newValue)
                }
                .onSubmit {
                    let index = searchState.selectedIndex
                    if index < results.count {
                        onSelect(results[index], query)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Results list
            if !results.isEmpty {
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.offset) { index, emoji in
                                HStack(spacing: 12) {
                                    Text(emoji.character)
                                        .font(.system(size: 24))
                                    Text(emoji.name)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    index == searchState.selectedIndex
                                        ? Color.white.opacity(0.1)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                                .id(index)
                                .onTapGesture {
                                    onSelect(emoji, query)
                                }
                            }
                        }
                    }
                    .frame(height: 280)
                    .onChange(of: searchState.selectedIndex) { newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: nil)
                        }
                    }
                }
            }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand {
            onDismiss()
        }
        .onChange(of: searchState.mode) { _ in
            performSearch(query)
        }
        .onChange(of: searchState.deleteRequested) { requested in
            if requested {
                searchState.deleteRequested = false
                let index = searchState.selectedIndex
                if index < results.count {
                    onDeleteCombo?(results[index])
                    performSearch(query)
                    if searchState.selectedIndex >= results.count {
                        searchState.selectedIndex = max(0, results.count - 1)
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private func performSearch(_ query: String) {
        switch searchState.mode {
        case .emoji:
            results = searcher.search(query: query, pickHistory: pickHistory)
        case .kaomoji:
            results = searcher.searchKaomoji(query: query, pickHistory: pickHistory)
        }
    }

    private func tabLabel(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                isActive
                    ? Color.white.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
    }
}
```

**Step 2: Verify it builds**

Run: `swift build 2>&1 | tail -5`
Expected: Build Succeeded

**Step 3: Commit**

```bash
git add Sources/swiftmoji/SearchView.swift
git commit -m "feat: add tab labels and mode switching to SearchView"
```

---

### Task 6: Wire Tab key and kaomoji data in FloatingPanel and AppDelegate

**Files:**
- Modify: `Sources/swiftmoji/Panel.swift`
- Modify: `Sources/swiftmoji/App.swift`

**Step 1: Add onTabPressed callback to FloatingPanel**

In `Sources/swiftmoji/Panel.swift`, add after line 8 (`onDeleteCombo`):

```swift
    nonisolated(unsafe) var onTabPressed: (() -> Void)?
```

Then change the Tab case (lines 53-58) from:

```swift
            case 48 where interceptsTab: // Tab
                if flags.contains(.shift) {
                    onArrowUp?()
                } else {
                    onArrowDown?()
                }
                return
```

to:

```swift
            case 48 where interceptsTab: // Tab
                onTabPressed?()
                return
```

**Step 2: Wire kaomoji data and tab callback in AppDelegate**

In `Sources/swiftmoji/App.swift`, modify `applicationDidFinishLaunching` to load kaomojis. After line 44 (`print("Loaded \(emojis.count) emojis")`), add:

```swift
        let kaomojis = KaomojiDataParser.loadAll()
        print("Loaded \(kaomojis.count) kaomojis")
```

Change line 52 from:

```swift
        emojiSearcher = EmojiSearcher(emojis: emojis, comboStore: comboStore)
```

to:

```swift
        emojiSearcher = EmojiSearcher(emojis: emojis, kaomojis: kaomojis, comboStore: comboStore)
```

In `showPanel()`, after the `panel.onDeleteCombo` callback setup (after line 93), add:

```swift
            panel.onTabPressed = { [weak self] in
                self?.searchState.toggleMode()
            }
```

**Step 3: Verify it builds**

Run: `swift build 2>&1 | tail -5`
Expected: Build Succeeded

**Step 4: Commit**

```bash
git add Sources/swiftmoji/Panel.swift Sources/swiftmoji/App.swift
git commit -m "feat: wire Tab key to mode toggle and load kaomoji data"
```

---

### Task 7: Run all tests and verify

**Step 1: Run full test suite**

Run: `swift test 2>&1 | tail -20`
Expected: All tests pass

**Step 2: Manual smoke test (optional)**

Run: `swift run` and press opt+e. Type a query, press Tab to switch to kaomoji, type a query, press Tab to switch back to emoji.
