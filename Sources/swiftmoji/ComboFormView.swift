import SwiftUI
import SwiftmojiCore

struct ComboFormView: View {
    @State private var name: String = ""
    @State private var aliases: [String] = []
    @State private var newAlias: String = ""
    @State private var characters: String = ""
    @State private var showingAliasField: Bool = false
    @FocusState private var isNameFocused: Bool

    var onSave: ([String], String) -> Void
    var onCancel: () -> Void

    private var allNames: [String] {
        let primary = name.trimmingCharacters(in: .whitespaces)
        let extras = aliases.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !primary.isEmpty else { return [] }
        return [primary] + extras
    }

    private var canSave: Bool {
        !allNames.isEmpty && !characters.trimmingCharacters(in: .whitespaces).isEmpty
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
                // Name field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("e.g. ackshuwally", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16))
                            .focused($isNameFocused)
                        Button(action: { showingAliasField = true }) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Add alias")
                    }
                }

                // Aliases
                if showingAliasField || !aliases.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aliases")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        ForEach(aliases.indices, id: \.self) { i in
                            HStack {
                                Text(aliases[i])
                                    .font(.system(size: 14))
                                Spacer()
                                Button(action: { aliases.remove(at: i) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if showingAliasField {
                            HStack {
                                TextField("alias", text: $newAlias)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14))
                                    .onSubmit {
                                        let trimmed = newAlias.trimmingCharacters(in: .whitespaces)
                                        if !trimmed.isEmpty {
                                            aliases.append(trimmed)
                                            newAlias = ""
                                        }
                                        showingAliasField = false
                                    }
                            }
                        }
                    }
                }

                // Emoji field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emojis")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField("e.g. ☝️🤓", text: $characters)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24))
                }

                // Save button
                HStack {
                    Spacer()
                    Button("Save") {
                        if canSave {
                            onSave(allNames, characters.trimmingCharacters(in: .whitespaces))
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [])
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
            isNameFocused = true
        }
    }
}
