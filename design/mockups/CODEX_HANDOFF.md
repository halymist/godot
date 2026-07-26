# Codex handoff: implementing the mockup in Godot

## Goal

Use `panel_mockups.html` as the visual and interaction reference while incrementally improving the existing Godot UI. Preserve working networking, game state, and scene wiring. This is a reference-led renovation, not a rewrite of the client in HTML or a wholesale replacement of `Scenes/game.tscn`.

## Read before editing

1. `COPILOT_GUIDELINES.md` — the project's UI and overlay rules.
2. The relevant section of `PROJECT_ARCHITECTURE.md`.
3. `panel_mockups.html` — use the top review tabs to isolate the target screen.
4. The corresponding existing scene and script.

Check `git status` before every task. Existing changes are user work and must not be discarded or reformatted incidentally.

## Project conventions that remain authoritative

- Put persistent UI nodes in `Scenes/game.tscn`; create runtime nodes only when content is genuinely dynamic.
- Use existing `StyleBoxFlat` and theme resources where possible.
- Each overlay owns its show/hide animation.
- `TogglePanel` hides the active overlay before showing the next one.
- Store the active overlay in `GameInfo.current_panel_overlay`.
- Prefer exported typed node references assigned in the editor over hardcoded paths or tree scans.
- Connect signals in the editor when practical.
- Keep server and websocket payload handling out of presentation scripts.
- Treat 405 × 900 as the current project viewport and verify responsive behavior at the mockup's 390 × 800 frame too.

## Mockup-to-project map

| Mockup tab | Existing project entry point |
| --- | --- |
| Lobby | `Scenes/game.tscn`, `scripts/LobbyPanel.gd` |
| Create Char / Avatar | `Scenes/game.tscn`, `scripts/AvatarPanel.gd`, `Scenes/character_display.tscn` |
| Home | `Scenes/game.tscn`, `scripts/VillagePanel.gd` |
| Expedition | `Scenes/game.tscn`, `scripts/ExpeditionPanel.gd` |
| Travel | `Scenes/game.tscn`, `scripts/MapPanel.gd` |
| Quest | `Scenes/game.tscn`, `Scenes/quest_option.tscn`, `scripts/Quest.gd`, `scripts/QuestOption.gd` |
| Vendor | `Scenes/game.tscn`, `scripts/VendorPanel.gd` |
| Healer | `Scenes/game.tscn`, `scripts/HealerPanel.gd` |
| Blacksmith | `Scenes/game.tscn`, `scripts/BlacksmithPanel.gd` |
| Alchemist | `Scenes/game.tscn`, `scripts/AlchemistPanel.gd` |
| Enchanter | `Scenes/game.tscn`, `scripts/EnchanterPanel.gd` |
| Trainer | `Scenes/game.tscn`, `scripts/TrainerPanel.gd` |
| Church | `Scenes/game.tscn`, `scripts/ChurchPanel.gd` |
| Character | `Scenes/character_display.tscn`, `scripts/CharacterDisplay.gd`, `scripts/CharacterInfoPanel.gd` |
| Talents | `Scenes/game.tscn`, `scripts/Talent.gd`, `scripts/SetTalents.gd` |
| Perks | `Scenes/perk.tscn`, `Scenes/perk_mini.tscn`, `scripts/PerkScreen.gd` |
| Rankings | `Scenes/game.tscn` |
| Arena | `Scenes/arena_opponent.tscn`, `scripts/Arena.gd`, `scripts/ArenaOpponent.gd` |
| Combat | `Scenes/game.tscn`, `scripts/CombatPanel.gd` |
| Settings | `Scenes/game.tscn`, `scripts/Settings.gd`, `scripts/global/SettingsManager.gd` |
| Payment | `Scenes/game.tscn`, `scripts/Payment.gd` |

The map is a starting point, not permission to touch every listed file in one change.

## Recommended implementation slices

Work in narrow, reviewable vertical slices:

1. Shared shell: top HUD, bottom dock, spacing tokens, focus/pressed states.
2. Shared primary action and cost-button variants.
3. Shared empty state for Perks and Rankings.
4. Overlay lifecycle and Chat/Rankings stacking behavior.
5. One utility-panel template, then migrate Healer/Blacksmith/Alchemist/Enchanter/Trainer/Church.
6. Character equipment art wiring and item tooltip behavior.
7. Talent icon mapping and tree connections.
8. Expedition initialization, nodes, and edge rendering.

For each slice:

- Record the specific mockup tab and interaction being matched.
- Inspect live node names and existing signal connections before editing.
- Avoid unrelated scene reserialization.
- Run the project and exercise both opening and closing paths.
- Check editor and game logs after interaction.
- Capture a screenshot at the target viewport for visual comparison.

## Definition of done for a panel

- Opens and closes through the established overlay flow.
- Works at 405 × 900 and remains usable at 390 × 800.
- Handles empty, loading, disabled, affordable/unaffordable, and long-text states that apply to it.
- Has visible keyboard focus and clear touch pressed feedback.
- Uses real game data; no mockup-only placeholder state leaks into runtime.
- Produces no new editor/game errors.
- Leaves unrelated user changes intact.

## Good first Codex prompt

> Implement the shared primary action button from `design/mockups/panel_mockups.html` in the Godot project. First read `design/mockups/CODEX_HANDOFF.md` and `COPILOT_GUIDELINES.md`, inspect existing button theme resources and affected scenes, then make the smallest reusable change. Apply it to one representative utility panel only, run the project, check logs, and report the files changed plus any remaining visual differences.
