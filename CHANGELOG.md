# Changelog

## 0.15.1

- Keep Polestar's accepted quest authoritative while following is enabled, including when the game selects a newly accepted side quest.
- Remove the manual-selection latch that could leave Lore on another quest until a guide goal changed.
- Add a one-second local target check to recover missed or late waypoint events.
- Reread the target on ordinary quest updates, acceptance, turn-in, and removal.
- Avoid repeated redraws for unchanged targets; cancel the safety timer on disable.
- Test side-quest acceptance/completion, silent target changes, idle redraws, and ticker lifecycle.

## 0.15.0

- Follow Polestar's accepted navigation quest directly through its target-change events.
- Add a bilingual per-character toggle, enabled by default, without requiring Polestar.
- Support initial and late addon load, area/search objectives, and accepted turn-in targets.
- Respect explicit manual quest selection until the next changed quest/guide goal.
- Fall back for manual pins, acceptance recommendations, unaccepted or removed quests, missing targets, and unavailable APIs.
- Unsubscribe on disable without changing Polestar's navigation or native quest tracking.
- Test subscription lifecycle, duplicate events, fallback, errors, re-enabling, and saved preferences.

## 0.14.0

- Remove all pagination, Current/History labels, and counters from live Lore.
- Keep live Lore on the active quest while archived stories are read independently.
- Add a native AddOns history subcategory, scrollable story list, and full narrative reader.
- Preserve existing per-character history and replace history navigation key bindings with an Open history action.
- Reduce reserved bottom space in the live section.
- Publish source, English documentation, MIT license, tests, and a standalone packaging command.
- Add project artwork and ready-to-paste CurseForge copy.
- Document Polestar integration feasibility and limits without enabling an untested direct bridge.

## 0.13.1

- Reread 5,259 bilingual quest narratives and 90 bilingual race/class openings.
- Correct 400 quest rows and three opening combinations for language, narrative quality, supported context, and current-step chronology.

## 0.13.0

- Complete the audited quest corpus: 5,259 bilingual narratives across 5,413 classified records.
- Preserve 154 evidence-backed exclusions, with no pending narratives.
