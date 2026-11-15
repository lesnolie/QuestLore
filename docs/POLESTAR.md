# Polestar integration investigation

Investigated on 2026-11-15 against the public `next` branch at [commit 19bd636e7d6f33231770f6029c76d2d4dfc63798](https://github.com/fitzforge/polestar/commit/19bd636e7d6f33231770f6029c76d2d4dfc63798), with a comparison to the locally installed addon. This is a source-based feasibility investigation, not an in-game test or a direct integration shipped in QuestLore 0.14.0.

## Finding

**Yes: QuestLore can follow the quest associated with Polestar's current navigation target.** The source exposes a global `Polestar` namespace, a target getter, and a message bus. No modification or copied source from Polestar is needed.

- [Core/Init.lua](https://github.com/fitzforge/polestar/blob/19bd636e7d6f33231770f6029c76d2d4dfc63798/addon/Polestar/Core/Init.lua) exposes `Polestar = ns` and defines `ns.On(message, callback)` / `ns.Off(handle)`.
- [Nav/Nav.lua](https://github.com/fitzforge/polestar/blob/19bd636e7d6f33231770f6029c76d2d4dfc63798/addon/Polestar/Nav/Nav.lua) defines `Nav.GetTarget()` and announces `WAYPOINT_CHANGED` with the current target. A quest-associated target can carry `quest` and `kind` fields; manual targets need not carry a quest.
- [Nav/Bridges.lua](https://github.com/fitzforge/polestar/blob/19bd636e7d6f33231770f6029c76d2d4dfc63798/addon/Polestar/Nav/Bridges.lua) calls `C_SuperTrack.SetSuperTrackedQuestID(q)` for certain accepted, trackable quest targets. It rejects acceptance targets and some area/search/spawn targets; route legs may instead use a user waypoint. Therefore game super-tracking does not represent every Polestar target.

QuestLore already follows game super-tracking through its existing quest API and hook. That provides partial incidental synchronization where Polestar sets it, not a complete guarantee.

## Proposed direct bridge

Add a per-character **Follow Polestar's active quest** option, with a soft dependency only. On initialization and late `ADDON_LOADED`, feature-detect `Polestar.On`, `Polestar.Off`, and `Polestar.Nav.GetTarget`. Read the initial target, then subscribe once to `WAYPOINT_CHANGED`; remove the subscription when disabling the feature.

Accept `tonumber(target.quest)` only when it is a positive, ordinary value and `C_QuestLog.GetLogIndexForQuestID` confirms that the quest is currently in the player's log. Reject absent/manual targets and acceptance targets. Do not read or render a recommended future quest before it is accepted. Read narrative data from QuestLore's local corpus, not from a later guide step.

Give an explicit player quest click priority until the next genuine Polestar target change. For a manual target, cleared target, missing addon, missing API, or unaccepted quest, fall back to QuestLore's ordinary selected/super-tracked/watched quest resolution. Never call Polestar setters, change its route, or force a quest to be tracked merely to display a narrative.

Use the target's quest association rather than the temporary travel-stop label: a flight master or boat is not itself the quest whose context should be explained. Subscribe to target changes instead of polling every frame, and coalesce repeated same-target events through QuestLore's refresh queue.

## Checks before enabling

Test initial load, late load, disable/re-enable without duplicate listeners, accepted quest objectives, turn-ins, acceptance recommendations, unrelated manual pins, travel legs, cleared targets, quest removal, same-ID objective changes, journal-click precedence, and absent or changed Polestar APIs.

These namespace functions are visible in current source but are not a versioned compatibility contract. Feature detection and a fallback remain necessary. This release deliberately documents feasibility while keeping the player's requested quest-list selection behavior intact.
