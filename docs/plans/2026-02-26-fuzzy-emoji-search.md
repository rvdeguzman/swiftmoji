# Fuzzy Emoji Search Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add fuzzy search over ~1,800 emojis with ranked results displayed in the spotlight panel.

**Architecture:** An `Emoji` model holds character/name/keywords. A `FuzzyMatcher` scores query-vs-string matches across tiers (exact > prefix > substring > fuzzy). An `EmojiSearcher` filters the emoji array and returns ranked results. The `SearchView` displays results in a list that grows the panel vertically.

**Tech Stack:** Swift 6.2, SwiftUI, XCTest

---

### Task 1: Emoji Model + Test Target

**Files:**
- Modify: `Package.swift`
- Create: `Sources/swiftmoji/Emoji.swift`
- Create: `Tests/swiftmojiTests/FuzzyMatcherTests.swift`

**Step 1: Add test target to Package.swift**

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftmoji",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "swiftmoji",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "swiftmojiTests",
            dependencies: ["swiftmoji"]
        ),
    ]
)
```

**Note:** This will fail to link tests against an executable target. To fix, extract the searchable logic into a library target:

```swift
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftmoji",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SwiftmojiCore"
        ),
        .executableTarget(
            name: "swiftmoji",
            dependencies: ["SwiftmojiCore"],
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "swiftmojiTests",
            dependencies: ["SwiftmojiCore"]
        ),
    ]
)
```

Move testable code (Emoji, FuzzyMatcher, EmojiSearcher) into `Sources/SwiftmojiCore/`. Keep App.swift, Panel.swift, SearchView.swift, HotkeyManager.swift in `Sources/swiftmoji/`.

**Step 2: Create the Emoji model**

Create `Sources/SwiftmojiCore/Emoji.swift`:

```swift
public struct Emoji: Sendable {
    public let character: String
    public let name: String
    public let keywords: [String]

    public init(character: String, name: String, keywords: [String] = []) {
        self.character = character
        self.name = name
        self.keywords = keywords
    }
}
```

**Step 3: Create a placeholder test file**

Create `Tests/swiftmojiTests/FuzzyMatcherTests.swift`:

```swift
import Testing
@testable import SwiftmojiCore

@Test func placeholderTest() {
    let emoji = Emoji(character: "🔥", name: "fire", keywords: ["flame", "hot"])
    #expect(emoji.character == "🔥")
    #expect(emoji.name == "fire")
    #expect(emoji.keywords == ["flame", "hot"])
}
```

**Step 4: Add `import SwiftmojiCore` to existing source files**

In `Sources/swiftmoji/SearchView.swift`, add `import SwiftmojiCore` at the top (will be needed soon). Same for `App.swift`.

**Step 5: Build and run tests**

Run: `swift build 2>&1`
Expected: Build succeeds

Run: `swift test 2>&1`
Expected: 1 test passes

**Step 6: Commit**

```bash
git add Package.swift Sources/SwiftmojiCore/ Tests/ Sources/swiftmoji/
git commit -m "feat: add SwiftmojiCore library target with Emoji model and test infrastructure"
```

---

### Task 2: FuzzyMatcher — Scoring Algorithm (TDD)

**Files:**
- Create: `Sources/SwiftmojiCore/FuzzyMatcher.swift`
- Modify: `Tests/swiftmojiTests/FuzzyMatcherTests.swift`

**Step 1: Write failing tests for all scoring tiers**

Replace `Tests/swiftmojiTests/FuzzyMatcherTests.swift`:

```swift
import Testing
@testable import SwiftmojiCore

@Suite("FuzzyMatcher")
struct FuzzyMatcherTests {

    // MARK: - Exact match (highest score)

    @Test func exactMatch() {
        let score = FuzzyMatcher.score(query: "fire", against: "fire")
        #expect(score != nil)
        #expect(score! >= 100)
    }

    @Test func exactMatchCaseInsensitive() {
        let score = FuzzyMatcher.score(query: "Fire", against: "fire")
        #expect(score != nil)
        #expect(score! >= 100)
    }

    // MARK: - Prefix match

    @Test func prefixMatch() {
        let score = FuzzyMatcher.score(query: "fire", against: "fire extinguisher")
        #expect(score != nil)
        #expect(score! >= 75)
        #expect(score! < 100)
    }

    // MARK: - Substring match

    @Test func substringMatch() {
        let score = FuzzyMatcher.score(query: "fire", against: "campfire")
        #expect(score != nil)
        #expect(score! >= 50)
        #expect(score! < 75)
    }

    // MARK: - Fuzzy match (letters in order)

    @Test func fuzzyMatch() {
        let score = FuzzyMatcher.score(query: "fre", against: "fire")
        #expect(score != nil)
        #expect(score! > 0)
        #expect(score! < 50)
    }

    @Test func fuzzyMatchAllLettersPresent() {
        let score = FuzzyMatcher.score(query: "hrt", against: "heart")
        #expect(score != nil)
    }

    // MARK: - No match

    @Test func noMatch() {
        let score = FuzzyMatcher.score(query: "xyz", against: "fire")
        #expect(score == nil)
    }

    @Test func noMatchPartialLetters() {
        let score = FuzzyMatcher.score(query: "zf", against: "fire")
        #expect(score == nil)
    }

    // MARK: - Score ordering

    @Test func exactBeatsPrefixBeatsSubstringBeatsFuzzy() {
        let exact = FuzzyMatcher.score(query: "fire", against: "fire")!
        let prefix = FuzzyMatcher.score(query: "fire", against: "fire truck")!
        let substring = FuzzyMatcher.score(query: "fire", against: "campfire")!
        let fuzzy = FuzzyMatcher.score(query: "fre", against: "fire")!

        #expect(exact > prefix)
        #expect(prefix > substring)
        #expect(substring > fuzzy)
    }

    // MARK: - Edge cases

    @Test func emptyQuery() {
        let score = FuzzyMatcher.score(query: "", against: "fire")
        #expect(score == nil)
    }

    @Test func singleCharQuery() {
        let score = FuzzyMatcher.score(query: "f", against: "fire")
        #expect(score != nil)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1`
Expected: Compilation fails — `FuzzyMatcher` not found

**Step 3: Implement FuzzyMatcher**

Create `Sources/SwiftmojiCore/FuzzyMatcher.swift`:

```swift
public enum FuzzyMatcher {

    /// Returns a score (higher = better match) or nil if no match.
    public static func score(query: String, against target: String) -> Int? {
        guard !query.isEmpty else { return nil }

        let q = query.lowercased()
        let t = target.lowercased()

        // Exact match
        if q == t {
            return 100
        }

        // Prefix match
        if t.hasPrefix(q) {
            return 75 + (25 * q.count / t.count)  // shorter targets score higher
        }

        // Substring match
        if t.contains(q) {
            return 50 + (25 * q.count / t.count)
        }

        // Fuzzy match: all query characters appear in order in target
        var targetIndex = t.startIndex
        var matched = 0

        for qChar in q {
            guard let foundIndex = t[targetIndex...].firstIndex(of: qChar) else {
                return nil
            }
            targetIndex = t.index(after: foundIndex)
            matched += 1
        }

        // Score based on how many characters matched relative to target length
        return max(1, 40 * matched / t.count)
    }
}
```

**Step 4: Run tests**

Run: `swift test 2>&1`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Sources/SwiftmojiCore/FuzzyMatcher.swift Tests/swiftmojiTests/FuzzyMatcherTests.swift
git commit -m "feat: add FuzzyMatcher with tiered scoring (exact/prefix/substring/fuzzy)"
```

---

### Task 3: EmojiSearcher (TDD)

**Files:**
- Create: `Sources/SwiftmojiCore/EmojiSearcher.swift`
- Create: `Tests/swiftmojiTests/EmojiSearcherTests.swift`

**Step 1: Write failing tests**

Create `Tests/swiftmojiTests/EmojiSearcherTests.swift`:

```swift
import Testing
@testable import SwiftmojiCore

@Suite("EmojiSearcher")
struct EmojiSearcherTests {
    let testEmojis: [Emoji] = [
        Emoji(character: "🔥", name: "fire", keywords: ["flame", "hot", "burn"]),
        Emoji(character: "🧯", name: "fire extinguisher", keywords: ["safety"]),
        Emoji(character: "🎆", name: "fireworks", keywords: ["celebration"]),
        Emoji(character: "❤️", name: "red heart", keywords: ["love", "valentine"]),
        Emoji(character: "💚", name: "green heart", keywords: ["love"]),
        Emoji(character: "😀", name: "grinning face", keywords: ["happy", "smile"]),
        Emoji(character: "🏕️", name: "camping", keywords: ["campfire", "outdoors"]),
    ]

    @Test func searchByName() {
        let searcher = EmojiSearcher(emojis: testEmojis)
        let results = searcher.search(query: "fire")

        #expect(results.count >= 3)
        // "fire" exact match should be first
        #expect(results[0].character == "🔥")
    }

    @Test func searchByKeyword() {
        let searcher = EmojiSearcher(emojis: testEmojis)
        let results = searcher.search(query: "love")

        #expect(results.count == 2)
        #expect(results.contains { $0.character == "❤️" })
        #expect(results.contains { $0.character == "💚" })
    }

    @Test func searchKeywordInName() {
        let searcher = EmojiSearcher(emojis: testEmojis)
        let results = searcher.search(query: "campfire")

        // Should match "camping" via keyword "campfire"
        #expect(results.contains { $0.character == "🏕️" })
    }

    @Test func emptyQueryReturnsEmpty() {
        let searcher = EmojiSearcher(emojis: testEmojis)
        let results = searcher.search(query: "")
        #expect(results.isEmpty)
    }

    @Test func noMatchReturnsEmpty() {
        let searcher = EmojiSearcher(emojis: testEmojis)
        let results = searcher.search(query: "zzzzz")
        #expect(results.isEmpty)
    }

    @Test func nameMatchRanksAboveKeywordMatch() {
        let searcher = EmojiSearcher(emojis: testEmojis)
        let results = searcher.search(query: "fire")

        // "fire" (name=fire) should rank above "camping" (keyword=campfire)
        let fireIndex = results.firstIndex { $0.character == "🔥" }!
        let campingIndex = results.firstIndex { $0.character == "🏕️" }
        if let ci = campingIndex {
            #expect(fireIndex < ci)
        }
    }

    @Test func resultsCappedAt50() {
        // Create 100 emojis that all match "a"
        let manyEmojis = (0..<100).map { i in
            Emoji(character: "😀", name: "a\(i)")
        }
        let searcher = EmojiSearcher(emojis: manyEmojis)
        let results = searcher.search(query: "a")
        #expect(results.count <= 50)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `swift test 2>&1`
Expected: Compilation fails — `EmojiSearcher` not found

**Step 3: Implement EmojiSearcher**

Create `Sources/SwiftmojiCore/EmojiSearcher.swift`:

```swift
public struct SearchResult: Sendable {
    public let emoji: Emoji
    public let score: Int
}

public class EmojiSearcher: @unchecked Sendable {
    private let emojis: [Emoji]
    private static let maxResults = 50

    public init(emojis: [Emoji]) {
        self.emojis = emojis
    }

    public func search(query: String) -> [Emoji] {
        guard !query.isEmpty else { return [] }

        var scored: [(emoji: Emoji, score: Int)] = []

        for emoji in emojis {
            var bestScore = 0

            // Score against name
            if let nameScore = FuzzyMatcher.score(query: query, against: emoji.name) {
                bestScore = nameScore
            }

            // Score against keywords (slightly lower than name)
            for keyword in emoji.keywords {
                if let kwScore = FuzzyMatcher.score(query: query, against: keyword) {
                    // Keyword matches get a small penalty vs name matches
                    let adjusted = max(1, kwScore - 5)
                    bestScore = max(bestScore, adjusted)
                }
            }

            if bestScore > 0 {
                scored.append((emoji, bestScore))
            }
        }

        scored.sort { $0.score > $1.score }

        return Array(scored.prefix(Self.maxResults).map(\.emoji))
    }
}
```

**Step 4: Run tests**

Run: `swift test 2>&1`
Expected: All tests pass

**Step 5: Commit**

```bash
git add Sources/SwiftmojiCore/EmojiSearcher.swift Tests/swiftmojiTests/EmojiSearcherTests.swift
git commit -m "feat: add EmojiSearcher with ranked fuzzy search over emojis"
```

---

### Task 4: Emoji Data (~1,800 emojis)

**Files:**
- Create: `Sources/SwiftmojiCore/EmojiData.swift`

**Step 1: Generate the emoji data file**

Create `Sources/SwiftmojiCore/EmojiData.swift` containing a public static array of all standard Unicode emojis. The file should look like:

```swift
// Auto-generated emoji data
public let allEmojis: [Emoji] = [
    Emoji(character: "😀", name: "grinning face", keywords: ["happy", "smile", "joy"]),
    Emoji(character: "😃", name: "grinning face with big eyes", keywords: ["happy", "smile"]),
    Emoji(character: "😄", name: "grinning face with smiling eyes", keywords: ["happy", "smile"]),
    // ... ~1,800 entries covering all standard emoji categories:
    // Smileys & Emotion, People & Body, Animals & Nature,
    // Food & Drink, Travel & Places, Activities,
    // Objects, Symbols, Flags
    Emoji(character: "🏁", name: "chequered flag", keywords: ["racing", "finish"]),
]
```

**Important notes for the implementer:**
- Use Unicode CLDR short names as the `name` field
- Include 2-5 keywords per emoji for discoverability
- Cover ALL major emoji categories (don't stop at smileys)
- Include skin-tone-neutral versions only (no skin tone variants)
- No ZWJ sequences (no compound emojis like 👨‍👩‍👧)
- This file will be large (~2000+ lines). That's expected.

**Step 2: Build and run existing tests**

Run: `swift test 2>&1`
Expected: All existing tests still pass (this task adds data, not logic)

**Step 3: Commit**

```bash
git add Sources/SwiftmojiCore/EmojiData.swift
git commit -m "feat: add hardcoded emoji data (~1,800 standard emojis)"
```

---

### Task 5: Wire Search to UI

**Files:**
- Modify: `Sources/swiftmoji/SearchView.swift`
- Modify: `Sources/swiftmoji/App.swift`

**Step 1: Update SearchView to accept an EmojiSearcher and display results**

Replace `Sources/swiftmoji/SearchView.swift`:

```swift
import SwiftUI
import SwiftmojiCore

struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [Emoji] = []
    @FocusState private var isSearchFocused: Bool

    let searcher: EmojiSearcher
    var onSelect: (Emoji) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))

                TextField("Search emoji...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($isSearchFocused)
                    .onChange(of: query) { _, newValue in
                        results = searcher.search(query: newValue)
                    }
                    .onSubmit {
                        if let first = results.first {
                            onSelect(first)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Results list
            if !results.isEmpty {
                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, emoji in
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(emoji)
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)  // ~8 rows
            }
        }
        .frame(width: 500)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand {
            onDismiss()
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}
```

**Step 2: Update App.swift to create EmojiSearcher and pass to SearchView**

In `App.swift`, add `import SwiftmojiCore` at the top. Add an `emojiSearcher` property to `AppDelegate`:

```swift
private let emojiSearcher = EmojiSearcher(emojis: allEmojis)
```

Update the `showPanel()` method where the hosting view is created — change:

```swift
let hostingView = NSHostingView(rootView: SearchView(onDismiss: { [weak self] in
    self?.hidePanel()
}))
```

to:

```swift
let hostingView = NSHostingView(rootView: SearchView(
    searcher: emojiSearcher,
    onSelect: { [weak self] emoji in
        print("Selected: \(emoji.character) \(emoji.name)")
        self?.hidePanel()
    },
    onDismiss: { [weak self] in
        self?.hidePanel()
    }
))
```

Also update the panel height to accommodate results. Change the initial panel creation from 44 height, and let the SwiftUI content drive the height by using `NSHostingView` with autoresizing:

Replace:
```swift
hostingView.frame = NSRect(x: 0, y: 0, width: 500, height: 44)
```

with:
```swift
hostingView.translatesAutoresizingMaskIntoConstraints = false
panel.contentView = hostingView
if let contentView = panel.contentView {
    hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
    hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
    hostingView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
    hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
}
```

And remove the duplicate `panel.contentView = hostingView` line that follows.

**Important:** The panel needs to resize when results appear. The simplest approach: set the panel's `contentView` to the hosting view and let SwiftUI's intrinsic content size drive the panel size. You may need to observe the hosting view's `fittingSize` and call `panel.setContentSize()` to resize the panel when results change, or use `NSHostingView`'s built-in sizing. Test this — if the panel doesn't resize automatically, add an `NSHostingView` subclass that overrides `invalidateIntrinsicContentSize` and resizes the panel.

**Step 3: Build and run**

Run: `swift build 2>&1`
Expected: Build succeeds

Run: `swift test 2>&1`
Expected: All tests still pass

**Step 4: Commit**

```bash
git add Sources/swiftmoji/SearchView.swift Sources/swiftmoji/App.swift
git commit -m "feat: wire emoji search to UI with results list"
```

---

### Task 6: Manual Integration Test

**Step 1: Build and run**

Run: `swift build && swift run swiftmoji`

**Step 2: Verify**

- [ ] Press opt+e → panel opens with search field focused
- [ ] Type "fire" → results appear: 🔥 fire, 🧯 fire extinguisher, 🎆 fireworks, etc.
- [ ] Exact match "fire" (🔥) is first result
- [ ] Type "heart" → ❤️ red heart, 💚 green heart, etc.
- [ ] Type "hpy" → fuzzy matches: emojis with "happy" in name/keywords
- [ ] Clear search → results disappear
- [ ] Panel resizes to fit results
- [ ] Click an emoji result → prints selected emoji, panel closes
- [ ] Press Enter with results → selects first result
- [ ] Escape still dismisses the panel
- [ ] Click outside still dismisses

**Step 3: Fix any issues found, commit**

```bash
git add -A
git commit -m "fix: integration test fixes for emoji search"
```
