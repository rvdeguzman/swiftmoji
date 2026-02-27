import Testing
@testable import SwiftmojiCore

@Test func placeholderTest() {
    let emoji = Emoji(character: "🔥", name: "fire", keywords: ["flame", "hot"])
    #expect(emoji.character == "🔥")
    #expect(emoji.name == "fire")
    #expect(emoji.keywords == ["flame", "hot"])
}
