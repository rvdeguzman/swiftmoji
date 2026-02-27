import SwiftUI
import SwiftmojiCore

class ComboFormState: ObservableObject {
    @Published var emojiSelectedIndex: Int = 0
    var resultCount: Int = 0

    func moveUp() {
        guard resultCount > 0 else { return }
        emojiSelectedIndex = emojiSelectedIndex <= 0 ? resultCount - 1 : emojiSelectedIndex - 1
    }

    func moveDown() {
        guard resultCount > 0 else { return }
        emojiSelectedIndex = emojiSelectedIndex >= resultCount - 1 ? 0 : emojiSelectedIndex + 1
    }

    func reset() {
        emojiSelectedIndex = 0
    }
}

struct ComboFormView: View {
    @State private var names: String = ""
    @State private var characters: String = ""
    @State private var emojiQuery: String = ""
    @State private var emojiResults: [Emoji] = []
    @ObservedObject var formState: ComboFormState
    @FocusState private var focusedField: Field?

    let searcher: EmojiSearcher
    var onSave: ([String], String) -> Void
    var onCancel: () -> Void

    private func pickSelected() {
        let capped = Array(emojiResults.prefix(8))
        guard formState.emojiSelectedIndex < capped.count else { return }
        characters += capped[formState.emojiSelectedIndex].character
        emojiQuery = ""
        emojiResults = []
        formState.reset()
    }

    enum Field {
        case names, emojiSearch
    }

    private var parsedNames: [String] {
        names.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !parsedNames.isEmpty && !characters.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Combo")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("esc to cancel")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                // Names field (comma-separated)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Names (comma-separated)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("e.g. ackshuwally, nerd point", text: $names)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: .names)
                }

                // Emoji preview
                if !characters.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Combo")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text(characters)
                                .font(.system(size: 28))
                            Spacer()
                            Button(action: { characters = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear emojis")
                        }
                    }
                }

                // Emoji search
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search emojis")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("type to search...", text: $emojiQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: .emojiSearch)
                        .onChange(of: emojiQuery) { newValue in
                            emojiResults = newValue.isEmpty ? [] : searcher.search(query: newValue)
                            formState.resultCount = min(emojiResults.count, 8)
                            formState.reset()
                        }
                        .onSubmit {
                            pickSelected()
                        }

                    if !emojiResults.isEmpty {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(emojiResults.prefix(8).enumerated()), id: \.offset) { index, emoji in
                                    HStack(spacing: 12) {
                                        Text(emoji.character)
                                            .font(.system(size: 24))
                                        Text(emoji.name)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        if !emoji.keywords.isEmpty {
                                            Text(emoji.keywords.joined(separator: ", "))
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        index == formState.emojiSelectedIndex
                                            ? Color.white.opacity(0.1)
                                            : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        characters += emoji.character
                                        emojiQuery = ""
                                        emojiResults = []
                                        formState.reset()
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }

                // Save button
                HStack {
                    Spacer()
                    Button("Save (⌘⏎)") {
                        if canSave {
                            onSave(parsedNames, characters.trimmingCharacters(in: .whitespaces))
                        }
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!canSave)
                }
            }
            .padding(16)
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand {
            onCancel()
        }
        .onAppear {
            focusedField = .names
        }
    }
}
