import Testing
@testable import SwiftmojiCore

@Suite("EmojiDataParser")
struct EmojiDataParserTests {

    @Test func parsesFullyQualifiedEmoji() {
        let line = "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face"
        let result = EmojiDataParser.parseLine(line, currentSubgroup: "face-smiling")
        #expect(result != nil)
        #expect(result!.character == "😀")
        #expect(result!.name == "grinning face")
    }

    @Test func skipsNonFullyQualified() {
        let line = "263A                                                   ; unqualified         # ☺ E0.6 smiling face"
        let result = EmojiDataParser.parseLine(line, currentSubgroup: "face-affection")
        #expect(result == nil)
    }

    @Test func skipsCommentLines() {
        let line = "# subgroup: face-smiling"
        let result = EmojiDataParser.parseLine(line, currentSubgroup: "face-smiling")
        #expect(result == nil)
    }

    @Test func skipsEmptyLines() {
        let line = ""
        let result = EmojiDataParser.parseLine(line, currentSubgroup: "")
        #expect(result == nil)
    }

    @Test func parsesMultiCodepointEmoji() {
        let line = "1F469 200D 2764 FE0F 200D 1F468                       ; fully-qualified     # 👩‍❤️‍👨 E2.0 couple with heart: woman, man"
        let result = EmojiDataParser.parseLine(line, currentSubgroup: "family")
        #expect(result != nil)
        #expect(result!.name == "couple with heart: woman, man")
    }

    @Test func includesSubgroupAsKeyword() {
        let line = "1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face"
        let result = EmojiDataParser.parseLine(line, currentSubgroup: "face-smiling")
        #expect(result != nil)
        // subgroup words become keywords
        #expect(result!.keywords.contains("face"))
        #expect(result!.keywords.contains("smiling"))
    }

    @Test func loadsFromBundledResource() {
        let emojis = EmojiDataParser.loadAll()
        // Should have hundreds of emojis
        #expect(emojis.count > 500)
        // First emoji should be grinning face
        #expect(emojis[0].character == "😀")
        #expect(emojis[0].name == "grinning face")
    }
}
