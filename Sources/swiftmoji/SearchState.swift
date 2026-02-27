import SwiftUI

class SearchState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var deleteRequested: Bool = false

    func moveUp(resultCount: Int) {
        guard resultCount > 0 else { return }
        selectedIndex = selectedIndex <= 0 ? resultCount - 1 : selectedIndex - 1
    }

    func moveDown(resultCount: Int) {
        guard resultCount > 0 else { return }
        selectedIndex = selectedIndex >= resultCount - 1 ? 0 : selectedIndex + 1
    }

    func reset() {
        selectedIndex = 0
    }
}
