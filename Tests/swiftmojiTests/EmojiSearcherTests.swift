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

        let fireIndex = results.firstIndex { $0.character == "🔥" }!
        let campingIndex = results.firstIndex { $0.character == "🏕️" }
        if let ci = campingIndex {
            #expect(fireIndex < ci)
        }
    }

    @Test func resultsCappedAt50() {
        let manyEmojis = (0..<100).map { i in
            Emoji(character: "😀", name: "a\(i)")
        }
        let searcher = EmojiSearcher(emojis: manyEmojis)
        let results = searcher.search(query: "a")
        #expect(results.count <= 50)
    }

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
}
