import SwiftUI
import SwiftmojiCore

struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [Emoji] = []
    @FocusState private var isSearchFocused: Bool

    let searcher: EmojiSearcher
    var onSelect: (Emoji) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))

                TextField("Search emoji...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($isSearchFocused)
                    .onChange(of: query) { newValue in
                        results = searcher.search(query: newValue)
                    }
                    .onSubmit {
                        if let first = results.first {
                            onSelect(first)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Results list
            if !results.isEmpty {
                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, emoji in
                            HStack(spacing: 12) {
                                Text(emoji.character)
                                    .font(.system(size: 24))
                                Text(emoji.name)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(emoji)
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .frame(width: 500)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand {
            onDismiss()
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}
