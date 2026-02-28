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
    var onDeleteCombo: ((Emoji) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Tab labels
            HStack(spacing: 0) {
                tabLabel("Emoji", isActive: searchState.mode == .emoji)
                tabLabel("Kaomoji", isActive: searchState.mode == .kaomoji)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))

                TextField(
                    searchState.mode == .emoji ? "Search emoji..." : "Search kaomoji...",
                    text: $query
                )
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($isSearchFocused)
                .onChange(of: query) { newValue in
                    performSearch(newValue)
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
        .onChange(of: searchState.mode) { _ in
            performSearch(query)
        }
        .onChange(of: searchState.deleteRequested) { requested in
            if requested {
                searchState.deleteRequested = false
                let index = searchState.selectedIndex
                if index < results.count {
                    onDeleteCombo?(results[index])
                    performSearch(query)
                    if searchState.selectedIndex >= results.count {
                        searchState.selectedIndex = max(0, results.count - 1)
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    private func performSearch(_ query: String) {
        switch searchState.mode {
        case .emoji:
            results = searcher.search(query: query, pickHistory: pickHistory)
        case .kaomoji:
            results = searcher.searchKaomoji(query: query, pickHistory: pickHistory)
        }
    }

    private func tabLabel(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                isActive
                    ? Color.white.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
    }
}
