# Copilot / Contributor Guidelines — UI & Overlay conventions

These guidelines are for any automated edits (Copilot) or contributors working on the UI and overlay flow.

Core rules
- Add UI elements directly into the main scene (`game.tscn`). Do not create UI only from code unless unavoidable.
- Style new UI nodes to match existing theme resources (use the project's `StyleBoxFlat` resources).
- Prefer simple, explicit implementations over clever/reflection-based code.

Overlay & panel behaviour
- Each overlay (chat, `quest_panel`, `cancel_quest`, `upgrade_talent`, `perks_panel`, etc.) must implement its own `show()`/`hide()` (or `show_overlay()`/`hide_overlay()`) methods and handle animations locally.
- Centralized logic (`TogglePanel`) must:
  - Call the overlay's show/hide methods only (no internal animations).
  - Always hide the currently active overlay before showing a new one.
  - Use `GameInfo.current_panel_overlay` for storing the active overlay.
- Avoid runtime capability checks like `has_method()` where possible — require the overlay to implement and expose the expected method.

Node references & assignment
- All external references to other scene nodes must be exported:
  - Use `@export var my_node: Control` (or specific type) and assign the node in the editor.
  - Do not hardcode NodePaths or search the tree at runtime for required UI nodes.
- Signals should be connected in the editor when possible. If connected in code, use clear `@onready var` or `@export var` references.

UI layout & styling
- New UI elements go into `game.tscn`.
- Use existing theme/style resources (`StyleBoxFlat_*`) for backgrounds and buttons.
- Inner panels should use square/rectangular `StyleBoxFlat` (no rounded corners inside unless explicitly desired).
- Keep padding consistent with project defaults (copy offsets from nearby panels if unsure).

Stock data (websocket) and GameInfo
- Stock/ticker data must be stored in a dedicated websocket autoload (singleton) — e.g. `Websocket` or `WebsocketClient`.
  - The websocket singleton should expose a simple field like `var stock_data: Dictionary = {}` and a method `update_stock_data(data: Dictionary)`.
  - On every websocket message that contains updated stock data, call `update_stock_data()` which should also write the latest data into `GameInfo`.
    - Example (simple, explicit):
      - `Websocket.stock_data = new_data`
      - `GameInfo.stock_data = new_data`
  - Keep this logic intentionally simple: store the incoming payload as-is (or with a minimal parse step), then assign it to `GameInfo` so UI code reads from `GameInfo` directly.
- Do not scatter parsing across UI panels — centralize it in the websocket autoload and push updates into `GameInfo`.

Simplicity preference
- Prefer straightforward solutions (explicit visibility toggles, simple animations inside the panel) over complicated manager logic or reflection.
- If multiple approaches are possible, choose the simpler and easier-to-maintain one.

Examples

1) Exported reference in scripts (preferred)
```gdscript
# filepath: c:\Users\halym\Documents\game\scripts\SomePanel.gd
@export var toggle_panel: Control
@export var quest_panel: Control

func _on_some_button_pressed():
    # Use TogglePanel.show_overlay(quest_panel) — TogglePanel handles hiding any active overlay.
    toggle_panel.show_overlay(quest_panel)
```

2) Overlay show/hide contract (inside overlay Control)
```gdscript
# filepath: c:\Users\halym\Documents\game\scripts\QuestPanel.gd
extends Control

func show_overlay():
    visible = true
    # run local show animation if needed

func hide_overlay():
    # run local hide animation if needed, then:
    visible = false
```

3) Websocket -> GameInfo (very small, explicit contract)
```gdscript
# Websocket autoload (example)
var stock_data: Dictionary = {}

func update_stock_data(new_data: Dictionary):
    stock_data = new_data
    # Mirror to GameInfo for UI usage
    GameInfo.stock_data = new_data
```

Do not
- Do not rely on `has_method()` or scanning the scene to decide how to hide panels — require the overlay interface described above.
- Do not create UI nodes from pure code unless the node is dynamic and impossible to place in the scene editor.
- Avoid global `get_node` searches at runtime; use `@export` + editor assignment.

If in doubt, add the UI node to `game.tscn`, style it using existing `StyleBoxFlat` resources, export references in the script, and prefer explicit `show_overlay`/`hide_overlay` calls.
