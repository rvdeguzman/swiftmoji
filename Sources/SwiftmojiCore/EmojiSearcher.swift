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
