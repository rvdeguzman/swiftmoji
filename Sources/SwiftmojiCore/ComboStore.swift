import Foundation

public struct Combo: Codable, Sendable {
    public let id: UUID
    public var names: [String]
    public var characters: String
}

public class ComboStore: @unchecked Sendable {
    private var combos: [Combo] = []
    private let storageURL: URL?

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        if let url = storageURL {
            load(from: url)
        }
    }

    @discardableResult
    public func add(names: [String], characters: String) -> Combo {
        let combo = Combo(id: UUID(), names: names, characters: characters)
        combos.append(combo)
        return combo
    }

    public func delete(id: UUID) {
        combos.removeAll { $0.id == id }
    }

    public func delete(character: String) {
        combos.removeAll { $0.characters == character }
    }

    public func all() -> [Combo] {
        combos
    }

    public func isCombo(character: String) -> Bool {
        combos.contains { $0.characters == character }
    }

    public func toEmojis() -> [Emoji] {
        combos.map { combo in
            Emoji(
                character: combo.characters,
                name: combo.names[0],
                keywords: Array(combo.names.dropFirst())
            )
        }
    }

    public func save() {
        guard let url = storageURL else { return }
        if let data = try? JSONEncoder().encode(combos) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func load(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Combo].self, from: data)
        else { return }
        combos = decoded
    }
}
