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
        guard let afraidIndex = kaomojis.firstIndex(where: { $0.name.lowercased() == "afraid" }) else {
            Issue.record("'afraid' not found in kaomojis")
            return
        }
        #expect(afraidIndex < 300)
    }
}
