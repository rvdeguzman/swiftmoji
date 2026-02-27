# Emoji Combos Design

## Overview

User-defined multi-emoji shortcuts that appear alongside regular emoji search results. A combo maps one or more trigger names to a multi-character emoji string (e.g. "ackshuwally" -> ☝️🤓).

## Data Model

```swift
struct Combo: Codable {
    let id: UUID
    var names: [String]       // ["ackshuwally", "nerd"] — aliases
    var characters: String    // "☝️🤓"
}
```

Persisted as JSON at `~/Library/Application Support/Swiftmoji/combos.json`. A `ComboStore` class handles CRUD and file I/O (same pattern as `PickHistory`).

## Search Integration

Combos are converted to virtual `Emoji` structs at search time:
- First name becomes `Emoji.name`
- Remaining names become `Emoji.keywords`
- `characters` becomes `Emoji.character`

Virtual emojis are appended to the real emoji list in `EmojiSearcher` and ranked by the same `FuzzyMatcher`. Pick history works automatically since it keys on `(query, character)`.

## Display

Combos look identical to regular emoji results — no visual distinction. The multi-character string renders naturally in the emoji column.

## Combo Creation (Cmd+N)

1. Panel content swaps to a "New Combo" form (same panel, different view)
2. Form fields:
   - **Name**: text input for trigger name, "+" button to add aliases
   - **Emoji**: text input for typing/pasting emojis, "+" button opens mini search picker
   - **Save / Cancel** (Enter / Escape)
3. Escape returns to normal search view

## Combo Deletion (Cmd+Backspace)

When a combo result is selected, Cmd+Backspace deletes it with a brief confirmation. Regular emojis ignore this shortcut.

## Operations (v1)

- Create and Delete only
- Edit by deleting and recreating
