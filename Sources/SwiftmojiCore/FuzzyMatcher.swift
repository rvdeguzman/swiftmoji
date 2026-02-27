public enum FuzzyMatcher {

    /// Returns a score (higher = better match) or nil if no match.
    public static func score(query: String, against target: String) -> Int? {
        guard !query.isEmpty else { return nil }

        let q = query.lowercased()
        let t = target.lowercased()

        // Exact match
        if q == t {
            return 100
        }

        // Prefix match
        if t.hasPrefix(q) {
            return 75 + (25 * q.count / t.count)
        }

        // Substring match
        if t.contains(q) {
            return 50 + (25 * q.count / t.count)
        }

        // Fuzzy match: all query characters appear in order in target
        var targetIndex = t.startIndex
        var matched = 0

        for qChar in q {
            guard let foundIndex = t[targetIndex...].firstIndex(of: qChar) else {
                return nil
            }
            targetIndex = t.index(after: foundIndex)
            matched += 1
        }

        return max(1, 40 * matched / t.count)
    }
}
