---
name: search-page-professional-redesign
description: Professional redesign spec for SearchPage with dynamic recommendations, search history, and delete confirmation.
metadata:
  type: project
---

# SearchPage professional redesign

## Goal
Redesign `entry/src/main/ets/pages/SearchPage.ets` so it feels like a professional reading product rather than an AI-styled demo page.

## User intent
- Search bar placeholder must read: `搜索你感兴趣的内容`
- Show recommended books below the search bar
- Recommendations must be dynamic, based on reading habits and question habits rather than fixed user personas
- Show search history below the recommendation area
- Add a trash icon beside the search history title
- Deleting search history must require confirmation first

## Design direction
Use a restrained, premium reading-app aesthetic:
- calm neutral palette
- low-contrast surfaces
- thin borders instead of heavy glow
- clear section hierarchy
- small, trustworthy actions rather than decorative UI

Avoid:
- neon gradients
- oversized shadows
- generic AI-card styling
- overly playful or futuristic decoration

## Recommendation model
Recommendations should be derived from available signals and rendered as explainable cards.

### Signal sources
Use the strongest available signals in this order:
1. Reading history: recently opened books, chapters, progress, revisit frequency
2. Search history: repeated themes, repeated terms, topical clusters
3. Question history: topics asked in chat/伴读 flow, repeated concern areas
4. Reading depth: completion level, chapter progression, recency

### Behavior
- Do not hard-code a persona such as student, office worker, or exam prep reader.
- Build a lightweight scoring model from observed behavior.
- If signals are sparse, fall back to broader theme similarity from recent search and reading activity.
- Show 3 to 6 recommendations.
- Each recommendation card should include a short reason such as `基于你最近频繁关注的算法主题` or `你最近在阅读更偏实用方法类内容`.

## Search history
- Place search history below the recommendation section.
- Display history in compact chips or small cards.
- The trash icon sits on the right side of the search history header.
- When tapped, show a confirmation dialog before clearing history.
- Only clear history after the user confirms.

## Interaction states
- Empty search state: prompt the user to enter content of interest.
- Empty recommendation state: fall back to recent-trend or recently engaged themes.
- Empty history state: show a calm placeholder instead of leaving the area blank.

## Implementation notes
- Reuse existing page patterns where possible.
- Keep the search experience first; recommendations should support the search flow, not replace it.
- Add only the minimum state needed for dynamic recommendations and history deletion confirmation.
- Keep the code maintainable inside `SearchPage.ets` unless a small helper extraction is clearly necessary.

## Testing checklist
- Search input placeholder is correct.
- Recommendations render below the search bar.
- Recommendation text changes when the underlying signals change.
- Search history renders with a trash icon.
- Delete flow always asks for confirmation first.
- Canceling deletion preserves history.
- Confirming deletion clears history.
- Layout remains readable on narrow screens.
