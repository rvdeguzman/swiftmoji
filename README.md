# Swiftmoji

A native macOS emoji and kaomoji picker with fuzzy search, activated by a global hotkey.

## Features

- **Global hotkey** (Opt+E) opens a floating search panel
- **Fuzzy search** across emoji names and keywords
- **Kaomoji support** — switch modes with Tab
- **Custom combos** — create and save your own emoji combinations
- **Smart ranking** — frequently picked results float to the top

## Requirements

- macOS 13+
- Accessibility permissions (for global hotkey)

## Install

```bash
git clone https://github.com/rvdeguzman/swiftmoji.git
cd swiftmoji
swift build -c release
```

Or open `Swiftmoji.xcodeproj` in Xcode and build.

## Usage

1. Launch Swiftmoji
2. Grant Accessibility permissions when prompted
3. Press **Opt+E** anywhere to open the picker
4. Type to search, arrow keys to navigate, Enter to select
5. The selected emoji is copied to your clipboard

## License

[MIT](LICENSE)
