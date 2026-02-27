import Testing
import Foundation
@testable import SwiftmojiCore

@Suite("ComboStore")
struct ComboStoreTests {

    @Test func addAndListCombos() {
        let store = ComboStore()
        let combo = store.add(names: ["ackshuwally", "nerd"], characters: "☝️🤓")

        let all = store.all()
        #expect(all.count == 1)
        #expect(all[0].names == ["ackshuwally", "nerd"])
        #expect(all[0].characters == "☝️🤓")
        #expect(all[0].id == combo.id)
    }

    @Test func deleteCombo() {
        let store = ComboStore()
        let combo = store.add(names: ["shrug"], characters: "🤷")
        store.delete(id: combo.id)

        #expect(store.all().isEmpty)
    }

    @Test func deleteNonexistentIsNoOp() {
        let store = ComboStore()
        store.delete(id: UUID())
        #expect(store.all().isEmpty)
    }

    @Test func persistenceRoundTrip() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("combo-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = ComboStore(storageURL: tempURL)
        store.add(names: ["lenny"], characters: "( ͡° ͜ʖ ͡°)")
        store.save()

        let loaded = ComboStore(storageURL: tempURL)
        #expect(loaded.all().count == 1)
        #expect(loaded.all()[0].names == ["lenny"])
    }

    @Test func toEmojis() {
        let store = ComboStore()
        store.add(names: ["ackshuwally", "nerd"], characters: "☝️🤓")

        let emojis = store.toEmojis()
        #expect(emojis.count == 1)
        #expect(emojis[0].character == "☝️🤓")
        #expect(emojis[0].name == "ackshuwally")
        #expect(emojis[0].keywords == ["nerd"])
    }

    @Test func toEmojisWithSingleName() {
        let store = ComboStore()
        store.add(names: ["shrug"], characters: "🤷")

        let emojis = store.toEmojis()
        #expect(emojis[0].name == "shrug")
        #expect(emojis[0].keywords.isEmpty)
    }

    @Test func isCombo() {
        let store = ComboStore()
        store.add(names: ["ackshuwally"], characters: "☝️🤓")

        #expect(store.isCombo(character: "☝️🤓") == true)
        #expect(store.isCombo(character: "🐶") == false)
    }
}
