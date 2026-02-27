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
