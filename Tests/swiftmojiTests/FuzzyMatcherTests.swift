import Testing
@testable import SwiftmojiCore

@Suite("FuzzyMatcher")
struct FuzzyMatcherTests {

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

    @Test func prefixMatch() {
        let score = FuzzyMatcher.score(query: "fire", against: "fire extinguisher")
        #expect(score != nil)
        #expect(score! >= 75)
        #expect(score! < 100)
    }

    @Test func substringMatch() {
        let score = FuzzyMatcher.score(query: "fire", against: "campfire")
        #expect(score != nil)
        #expect(score! >= 50)
        #expect(score! < 75)
    }

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

    @Test func noMatch() {
        let score = FuzzyMatcher.score(query: "xyz", against: "fire")
        #expect(score == nil)
    }

    @Test func noMatchPartialLetters() {
        let score = FuzzyMatcher.score(query: "zf", against: "fire")
        #expect(score == nil)
    }

    @Test func exactBeatsPrefixBeatsSubstringBeatsFuzzy() {
        let exact = FuzzyMatcher.score(query: "fire", against: "fire")!
        let prefix = FuzzyMatcher.score(query: "fire", against: "fire truck")!
        let substring = FuzzyMatcher.score(query: "fire", against: "campfire")!
        let fuzzy = FuzzyMatcher.score(query: "fre", against: "fire")!

        #expect(exact > prefix)
        #expect(prefix > substring)
        #expect(substring > fuzzy)
    }

    @Test func emptyQuery() {
        let score = FuzzyMatcher.score(query: "", against: "fire")
        #expect(score == nil)
    }

    @Test func singleCharQuery() {
        let score = FuzzyMatcher.score(query: "f", against: "fire")
        #expect(score != nil)
    }
}
