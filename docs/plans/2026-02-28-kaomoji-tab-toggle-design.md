# Kaomoji Tab Toggle Design

## Summary

Add kaomoji support to the emoji search panel. Users press Tab to toggle between emoji and kaomoji modes. The search query persists across mode switches, and tab labels at the top indicate the active mode.

## Data

Two JSON files provide kaomoji data:
- `kaomoji-lib.json` — 1822 entries, each with `name`, `entry` (the kaomoji string), `keywords`, and `category`
- `kaomoji-ordered.json` — ordered list of ~291 keys defining display order

These are bundled as resources in `SwiftmojiCore`.

## Data Layer (SwiftmojiCore)

### KaomojiDataParser

Loads `kaomoji-lib.json` and `kaomoji-ordered.json`. Produces `[Emoji]` by mapping each kaomoji entry to the existing `Emoji` model:
- `character` = kaomoji `entry` (e.g. `( ͡° ͜ʖ ͡°)`)
- `name` = kaomoji `name`
- `keywords` = kaomoji `keywords`

Ordered entries appear first (in order), followed by remaining entries from lib.json.

### EmojiSearcher

Add a `kaomojis: [Emoji]` property loaded at init. New method `searchKaomoji(query:pickHistory:)` uses the same fuzzy matching logic as `search()` but against the kaomoji dataset.

## State

### SearchState

- New `SearchMode` enum: `.emoji`, `.kaomoji`
- New `@Published var mode: SearchMode = .emoji`
- `toggleMode()` flips between modes

## UI (SearchView)

- Tab labels bar at the top: `[Emoji]` and `[Kaomoji]`, active one visually highlighted
- Placeholder text changes per mode ("Search emoji..." / "Search kaomoji...")
- Results sourced from the appropriate search method based on `searchState.mode`
- On mode change, re-run search with current query

## Panel (FloatingPanel)

- Tab key triggers `onTabPressed()` callback instead of `onArrowDown()`
- `AppDelegate` wires `onTabPressed` to toggle `searchState.mode`
- Mode resets to `.emoji` when panel is shown

## Visual Layout

```
+-----------------------------------+
|  [Emoji]  [Kaomoji]               |  <- tab labels
+-----------------------------------+
|  magnifier Search emoji...        |  <- placeholder changes per mode
+-----------------------------------+
|  result row 1                     |
|  result row 2                     |
|  ...                              |
+-----------------------------------+
```
