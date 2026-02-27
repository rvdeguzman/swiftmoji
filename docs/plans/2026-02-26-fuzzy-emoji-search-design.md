# Fuzzy Emoji Search Design

## Overview

Add fuzzy search over ~1,800 standard Unicode emojis. Users type in the search field, results appear instantly below as a scrollable list.

## Emoji Data

Hardcoded Swift array of `Emoji` structs (character, name, keywords). No external files or dependencies. Keywords provide aliases so emojis are discoverable by multiple terms.

## Fuzzy Matching

Custom scorer, no dependencies. Scoring tiers (highest to lowest):

1. Exact match on name
2. Name starts with query (prefix)
3. Substring match on name
4. Fuzzy match on name (letters in order, not adjacent)
5. Same tiers for keyword matches, scored slightly lower than name

Results sorted by score descending, capped at 50. Matching is case-insensitive.

## UI Integration

- SearchView filters on every keystroke via an EmojiSearcher
- Results displayed as vertical list below search field (emoji character + name)
- Panel grows vertically to fit results, max ~8 visible rows
- Keyboard navigation (up/down/enter) is a separate future task

## Decisions

- Hardcoded data (no JSON, no CLDR)
- Fuzzy match with substring matches ranked higher
- 50 result cap for performance
