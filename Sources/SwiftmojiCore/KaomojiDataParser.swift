import Foundation

public enum KaomojiDataParser {

    public static func parseLib(data: Data) -> [String: Emoji] {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return [:]
        }

        var result: [String: Emoji] = [:]
        for (key, value) in raw {
            guard let name = value["name"] as? String,
                  let entry = value["entry"] as? String else { continue }
            let keywords = value["keywords"] as? [String] ?? []
            result[key] = Emoji(character: entry, name: name, keywords: keywords)
        }
        return result
    }

    public static func loadAll() -> [Emoji] {
        guard let libURL = Bundle.module.url(forResource: "kaomoji-lib", withExtension: "json"),
              let libData = try? Data(contentsOf: libURL) else {
            print("Failed to load kaomoji-lib.json from bundle")
            return []
        }

        let lib = parseLib(data: libData)

        var orderedKeys: [String] = []
        if let orderURL = Bundle.module.url(forResource: "kaomoji-ordered", withExtension: "json"),
           let orderData = try? Data(contentsOf: orderURL),
           let keys = try? JSONDecoder().decode([String].self, from: orderData) {
            orderedKeys = keys
        }

        var result: [Emoji] = []
        var seen = Set<String>()
        for key in orderedKeys {
            if let emoji = lib[key] {
                result.append(emoji)
                seen.insert(key)
            }
        }

        for key in lib.keys.sorted() where !seen.contains(key) {
            result.append(lib[key]!)
        }

        return result
    }
}
