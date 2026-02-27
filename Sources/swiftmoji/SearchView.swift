import SwiftUI

struct SearchView: View {
    @State private var query: String = ""
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))

                TextField("Search emoji...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .onSubmit {
                        // Will handle emoji selection later
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 500)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onExitCommand {
            onDismiss()
        }
    }
}
