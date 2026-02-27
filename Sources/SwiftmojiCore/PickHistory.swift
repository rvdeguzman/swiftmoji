import Foundation

public class PickHistory: @unchecked Sendable {
    private var counts: [String: [String: Int]] = [:]
    private let storageURL: URL?

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        if let url = storageURL {
            load(from: url)
        }
    }

    public func record(query: String, emojiCharacter: String) {
        let key = query.lowercased()
        counts[key, default: [:]][emojiCharacter, default: 0] += 1
    }

    public func pickCount(query: String, emojiCharacter: String) -> Int {
        counts[query.lowercased()]?[emojiCharacter] ?? 0
    }

    public func save() {
        guard let url = storageURL else { return }
        if let data = try? JSONEncoder().encode(counts) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func load(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data)
        else { return }
        counts = decoded
    }
}
