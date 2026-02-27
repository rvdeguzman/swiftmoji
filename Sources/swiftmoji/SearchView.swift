import SwiftUI
import SwiftmojiCore

struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [Emoji] = []
    @FocusState private var isSearchFocused: Bool
    @ObservedObject var searchState: SearchState

    let searcher: EmojiSearcher
    let pickHistory: PickHistory
    var onSelect: (Emoji, String) -> Void
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
                        results = searcher.search(query: newValue, pickHistory: pickHistory)
                        searchState.reset()
                    }
                    .onSubmit {
                        let index = searchState.selectedIndex
                        if index < results.count {
                            onSelect(results[index], query)
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Results list
            if !results.isEmpty {
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.offset) { index, emoji in
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
                                .background(
                                    index == searchState.selectedIndex
                                        ? Color.white.opacity(0.1)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                                .id(index)
                                .onTapGesture {
                                    onSelect(emoji, query)
                                }
                            }
                        }
                    }
                    .frame(height: 280)
                    .onChange(of: searchState.selectedIndex) { newIndex in
                        withAnimation {
                            proxy.scrollTo(newIndex, anchor: nil)
                        }
                    }
                }
            }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand {
            onDismiss()
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}
