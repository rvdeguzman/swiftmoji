import Testing
import Foundation
@testable import SwiftmojiCore

@Suite("PickHistory")
struct PickHistoryTests {

    @Test func recordAndRetrieve() {
        let history = PickHistory()
        history.record(query: "dog", emojiCharacter: "🐕")
        history.record(query: "dog", emojiCharacter: "🐕")
        history.record(query: "dog", emojiCharacter: "🐶")

        #expect(history.pickCount(query: "dog", emojiCharacter: "🐕") == 2)
        #expect(history.pickCount(query: "dog", emojiCharacter: "🐶") == 1)
        #expect(history.pickCount(query: "dog", emojiCharacter: "🦮") == 0)
    }

    @Test func querySpecific() {
        let history = PickHistory()
        history.record(query: "dog", emojiCharacter: "🐕")

        // Different query should not be affected
        #expect(history.pickCount(query: "cat", emojiCharacter: "🐕") == 0)
    }

    @Test func caseInsensitive() {
        let history = PickHistory()
        history.record(query: "Dog", emojiCharacter: "🐕")

        #expect(history.pickCount(query: "dog", emojiCharacter: "🐕") == 1)
    }

    @Test func boostAffectsSearchRanking() {
        let emojis = [
            Emoji(character: "🐕", name: "dog"),
            Emoji(character: "🐶", name: "dog face"),
        ]
        let history = PickHistory()
        // "dog face" would normally rank lower (prefix match vs exact)
        // but picking it repeatedly should boost it to the top
        history.record(query: "dog", emojiCharacter: "🐶")
        history.record(query: "dog", emojiCharacter: "🐶")
        history.record(query: "dog", emojiCharacter: "🐶")

        let searcher = EmojiSearcher(emojis: emojis)
        let results = searcher.search(query: "dog", pickHistory: history)

        #expect(results[0].character == "🐶")
    }

    @Test func persistenceRoundTrip() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pick-history-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let history = PickHistory(storageURL: tempURL)
        history.record(query: "fire", emojiCharacter: "🔥")
        history.record(query: "fire", emojiCharacter: "🔥")
        history.save()

        let loaded = PickHistory(storageURL: tempURL)
        #expect(loaded.pickCount(query: "fire", emojiCharacter: "🔥") == 2)
    }
}
