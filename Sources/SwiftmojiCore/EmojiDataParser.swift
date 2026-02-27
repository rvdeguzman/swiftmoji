import Foundation

public enum EmojiDataParser {

    /// Parse a single line from emoji-test.txt.
    /// Returns an Emoji if the line is a fully-qualified emoji, nil otherwise.
    public static func parseLine(_ line: String, currentSubgroup: String) -> Emoji? {
        // Skip comments and empty lines
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

        // Format: <codepoints> ; <status> # <emoji> <version> <name>
        guard line.contains("; fully-qualified") else { return nil }

        // Split at "#" to get the emoji + name part
        guard let hashIndex = line.firstIndex(of: "#") else { return nil }
        let afterHash = String(line[line.index(after: hashIndex)...]).trimmingCharacters(in: .whitespaces)

        // afterHash is like: "😀 E1.0 grinning face"
        // Find the version marker (E followed by digits and dot)
        guard let versionRange = afterHash.range(of: #"E\d+\.\d+"#, options: .regularExpression) else {
            return nil
        }

        let character = String(afterHash[afterHash.startIndex..<versionRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let name = String(afterHash[versionRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        guard !character.isEmpty, !name.isEmpty else { return nil }

        // Split subgroup into keywords (e.g., "face-smiling" → ["face", "smiling"])
        let keywords = currentSubgroup
            .split(separator: "-")
            .map(String.init)
            .filter { !$0.isEmpty }

        return Emoji(character: character, name: name, keywords: keywords)
    }

    /// Parse the subgroup name from a subgroup comment line.
    /// Returns the subgroup name, or nil if not a subgroup line.
    public static func parseSubgroup(_ line: String) -> String? {
        let prefix = "# subgroup: "
        guard line.hasPrefix(prefix) else { return nil }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    /// Load all emojis from the bundled emoji-test.txt resource.
    public static func loadAll() -> [Emoji] {
        guard let url = Bundle.module.url(forResource: "emoji-test", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("Failed to load emoji-test.txt from bundle")
            return []
        }

        var emojis: [Emoji] = []
        var currentSubgroup = ""

        for line in content.components(separatedBy: .newlines) {
            if let subgroup = parseSubgroup(line) {
                currentSubgroup = subgroup
                continue
            }

            if let emoji = parseLine(line, currentSubgroup: currentSubgroup) {
                emojis.append(emoji)
            }
        }

        return emojis
    }
}
