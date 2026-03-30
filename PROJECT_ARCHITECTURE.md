# Project Architecture — Shakes & Fidget–Style Browser RPG

> **Engine:** Godot 4.4 (GL Compatibility renderer)
> **Platform:** Mobile-first (portrait 405×900 base, scales 21:9 → 16:9)
> **Networking:** HTTP REST (auth) + WebSocket (real-time gameplay)
> **Data Pipeline:** Versioned JSON → local cache → Godot Resource objects + S3-hosted assets

---

## Table of Contents

1. [Game Overview](#1-game-overview)
2. [High-Level Architecture](#2-high-level-architecture)
3. [Project Structure](#3-project-structure)
4. [Autoload Singletons](#4-autoload-singletons)
5. [Data Model & Inner Classes](#5-data-model--inner-classes)
6. [Networking Layer](#6-networking-layer)
7. [Data Pipeline & Versioning](#7-data-pipeline--versioning)
8. [Game Systems](#8-game-systems)
9. [UI Architecture](#9-ui-architecture)
10. [Scene Graph & Key Scenes](#10-scene-graph--key-scenes)
11. [Resource Database Schema](#11-resource-database-schema)
12. [Server ↔ Client Sync Status](#12-server--client-sync-status)
13. [Formulas & Game Math](#13-formulas--game-math)
14. [Coding Conventions](#14-coding-conventions)
15. [File Reference Index](#15-file-reference-index)

---

## 1. Game Overview

This is a **Shakes & Fidget–style idle/adventure RPG** built in Godot 4. Players create a character, explore a world of settlements, fight enemies, complete quests and expeditions, collect loot, and climb rankings.

### Core Gameplay Loop

```
Login → Lobby (character select) → Home Village
    ├── Travel to settlements (timed, skippable)
    ├── Accept & complete quests (branching dialogue + combat)
    ├── Run expeditions (slide-based adventures with stat checks)
    ├── Fight arena opponents (PvP)
    ├── Manage inventory (equip, socket gems, temper, enchant)
    ├── Train stats at the Trainer (spend silver)
    ├── Brew elixirs at the Alchemist (combine ingredients)
    ├── Choose blessings at the Church (temporary buffs)
    ├── Upgrade talents & bind perks
    └── Climb the rankings leaderboard
```

### Feature Map

| Feature | Description |
|---------|-------------|
| **Authentication** | Email/password, Google, Discord, Facebook, Apple, Google Play |
| **Character Creation** | Name, faction (Order/Guild/Companions), avatar customization (face/hair/eyes/nose/mouth), optional VIP |
| **Settlements** | Multiple locations with unique vendors, utilities, arenas, and expeditions |
| **Quests** | Branching dialogue with stat-gated options, combat encounters, and multi-reward outcomes |
| **Expeditions** | Slide-based adventures with stat checks, health depletion, combat, and loot |
| **Combat** | Turn-based log playback (server-resolved), PvP and PvE |
| **Inventory** | 9 equipment slots + 5 bag slots; drag-and-drop with type validation |
| **Crafting** | Gem socketing, hammer tempering (+10% stats), scroll enchanting, elixir brewing |
| **Talents** | Tree-based progression with stat bonuses and perk slot unlocks |
| **Perks** | Dual-effect passive abilities bound to unlocked talent perk slots |
| **Blessings** | Single active buff from the Church utility |
| **Consumables** | Potions (instant use), Elixirs (brewed from 1-3 ingredients, time-limited) |
| **Arena** | 3-opponent carousel, PvP combat |
| **Rankings** | Paginated leaderboard sorted by honor, with fight integration |
| **Chat** | Global and local text chat with timestamp grouping |
| **Monetization** | Mushrooms (premium currency), coupon redemption, invite referral (placeholder) |

---

## 2. High-Level Architecture

```
┌──────────────────────────────────────────────────────────┐
│                       CLIENT (Godot 4)                   │
│                                                          │
│  ┌──────────┐  ┌───────────┐  ┌────────────┐            │
│  │  Login    │  │  Lobby    │  │   Game     │ ← Scenes   │
│  │ (login   │→ │ (char     │→ │ (game.tscn)│            │
│  │  .tscn)  │  │  select)  │  │            │            │
│  └──────────┘  └───────────┘  └─────┬──────┘            │
│                                     │                    │
│  ┌──────────────────────────────────┼───────────────┐    │
│  │            UI Layer              │               │    │
│  │  UIManager (TogglePanel)         │               │    │
│  │  ├── Panel switching             │               │    │
│  │  ├── Overlay stack management    │               │    │
│  │  ├── Back-button priority        │               │    │
│  │  └── State refresh coordination  │               │    │
│  └──────────────────────────────────┼───────────────┘    │
│                                     │                    │
│  ┌──────────────────────────────────┼───────────────┐    │
│  │         Autoload Singletons      │               │    │
│  │                                  ▼               │    │
│  │  GameInfo ◄──── Websocket ◄──── Server           │    │
│  │     ▲              ▲                             │    │
│  │     │              │                             │    │
│  │  DataManager    Http (auth only)                 │    │
│  │     │                                            │    │
│  │     ▼                                            │    │
│  │  TooltipManager    SettingsManager               │    │
│  └──────────────────────────────────────────────────┘    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │         Data Layer (Resource Databases)           │    │
│  │  EffectDB · ItemDB · PerkDB · EnemyDB            │    │
│  │  ExpeditionsDB · SettlementsDB · TalentsDB        │    │
│  │  QuestsDB · CosmeticDB · NpcDB                   │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
            │                        ▲
            ▼                        │
┌────────────────────┐    ┌──────────────────┐
│   REST API Server  │    │   S3 Asset CDN   │
│   (port 8080)      │    │   (eu-north-1)   │
│   /login           │    │   /images/items/  │
│   /lobby           │    │   /images/perks/  │
│   /create-character│    │   /images/enemies/│
│   /logout          │    │   /images/quests/ │
└────────────────────┘    └──────────────────┘
            │
            ▼
┌────────────────────┐
│  WebSocket Server  │
│  (port 3000)       │
│  All gameplay msgs │
└────────────────────┘
```

### Data Flow Summary

```
Server → Websocket.gd → GameInfo.gd → UI Panels read from GameInfo
                                    → UI Panels call Websocket.send() for actions
Server ← Websocket.gd ← UI Panels (user actions)
```

All game state lives in `GameInfo`. UI reads from `GameInfo`, never from the network layer directly. The `Websocket` autoload parses server messages and writes into `GameInfo`.

---

## 3. Project Structure

```
project.godot              # Engine config, autoloads, display settings
COPILOT_GUIDELINES.md      # UI/overlay coding conventions
QUEST_EXAMPLE.md           # Quest system design documentation

scripts/
├── global/                # 6 Autoload singletons
│   ├── GameInfo.gd        # Central game state + inner data classes
│   ├── Websocket.gd       # WebSocket client (all in-game actions)
│   ├── Http.gd            # REST API (auth, character CRUD)
│   ├── DataManager.gd     # JSON versioning, download, database loading
│   ├── TooltipManager.gd  # Item/perk tooltip positioning
│   └── SettingsManager.gd # Per-character local settings
│
├── resources/             # ~28 Resource & Database class definitions
│   ├── *Database.gd       # Collection classes (ItemDatabase, PerkDatabase, etc.)
│   └── *Resource.gd       # Individual data records (ItemResource, PerkResource, etc.)
│
├── TogglePanel.gd         # UIManager — panel/overlay orchestration
├── LoginPanel.gd          # Auth flow (email, social, auto-login)
├── LobbyPanel.gd          # Character select, server join, data sync
├── Quest.gd               # Branching quest dialogue system
├── ExpeditionPanel.gd     # Slide-based expedition runner
├── CombatPanel.gd         # Combat log playback & animation
├── Arena.gd               # PvP opponent carousel
├── MapPanel.gd            # Travel timer & destination management
├── InventorySlot.gd       # Drag-and-drop slot validation
├── ItemDrag.gd            # Drag preview, double-click, tooltips
├── ItemDescription.gd     # Item tooltip content rendering
├── Equip.gd               # Equipment slot display (read-only)
├── CharacterDisplay.gd    # Player/enemy stat sheet
├── VendorPanel.gd         # Buy/sell items from NPCs
├── BlacksmithPanel.gd     # Temper items (+10% stats)
├── EnchanterPanel.gd      # Apply enchantment effects
├── AlchemistPanel.gd      # Brew elixirs from ingredients
├── ChurchPanel.gd         # Choose blessings
├── TrainerPanel.gd        # Purchase stat increases
├── PerkScreen.gd          # Perk binding to talent slots
├── Talent.gd              # Individual talent node behaviour
├── SetTalents.gd          # Talent grid layout
├── Rankings.gd            # Leaderboard with pagination
├── ChatPanel.gd           # Global/local text chat
├── Avatar.gd              # Layered avatar rendering
├── AvatarPanel.gd         # Avatar customization screen
├── Building.gd            # Clickable building wrapper
├── ChatBubble.gd          # NPC dialogue bubble
├── Payment.gd             # Monetization (placeholder)
├── LogoutPanel.gd         # Logout confirmation
├── CharacterInfoPanel.gd  # Character creation form
├── ResolutionManager.gd   # Portrait responsive scaling
└── ... (supporting UI scripts)

Scenes/
├── login.tscn             # Entry scene (main_scene in project.godot)
├── game.tscn              # Primary gameplay scene (all panels live here)
├── avatar_creation.tscn   # Character customization
├── avatar.tscn            # Layered avatar prefab
├── item.tscn              # Draggable item prefab
├── ItemSlot.tscn          # Inventory slot prefab
├── item_description.tscn  # Item tooltip popup
├── perk.tscn              # Perk display node
├── perk_tooltip.tscn      # Perk tooltip popup
├── quest_option.tscn      # Quest dialogue option button
├── enchant_option.tscn    # Enchanter effect row
├── arena_opponent.tscn    # Arena opponent card
├── ranking_row.tscn       # Rankings table row
├── healthbar.tscn         # Health bar prefab
├── bubble.tscn            # Chat message bubble
├── ChatBubble.tscn        # NPC dialogue bubble
├── character_display.tscn # Stats screen
├── playercard.tscn        # Lobby character card
├── Building.tscn          # Clickable building
├── bag.tscn               # Bag grid container
├── Utility.tscn           # Utility building interior
└── perk_mini.tscn         # Compact perk icon

assets/
├── images/                # Static UI images, icons
├── phone_theme.tres       # Global Godot theme resource
└── Spectral-Regular.ttf   # Primary font

data/
├── cosmetics.tres         # Cosmetic textures
├── item_textures/         # Cached item images
├── npcs_textures/         # Cached NPC images
└── perk_texture/          # Cached perk images

addons/
└── SmoothScroll/          # Smooth scroll plugin for ScrollContainers
```

---

## 4. Autoload Singletons

Registered in `project.godot` under `[autoload]`. Available globally by name.

### GameInfo

**Role:** Central data store. All game state — players, items, databases, chat, combat — lives here. UI reads from GameInfo; the websocket writes to it.

**Key data held:**
- `lobby_data: Dictionary` — account info, server list, characters
- `all_characters: Array[GameCurrentPlayer]` — all player characters
- `current_character_id: int` — active character
- `current_player: GameCurrentPlayer` — computed property → current character
- `enemy_players: Array[GamePlayer]` — other world players
- `rankings_players: Array[GamePlayer]` — unified leaderboard
- `arena_opponents: Array[int]` — arena opponent character IDs
- `chat_messages: Array[ChatMessage]` — chat history
- `current_combat_log: CombatResponse` — latest combat result
- `talent_registry: Dictionary` — talent metadata (populated by Talent.gd nodes)
- Database references: `effects_db`, `items_db`, `perks_db`, `settlements_db`, `quests_db`, `enemies_db`, `expeditions_db`, `talents_db`, `cosmetics_db`

**Key methods:**
- `load_databases()` — initialize all database references from DataManager
- `load_character_from_server(data)` — transform server format → client model
- `update_rankings()` — merge current player into enemy list, sort by honor
- `complete_quest(quest_id)` — emit `quest_completed` signal

### Websocket

**Role:** WebSocket client for all in-game communication after login.

**Connection:** `ws://localhost:3000` (configurable)

**Signal:** `player_data_received(character_data)`

**Inbound message routing** (by `function` field):
| Server Message | Handler | Effect |
|---|---|---|
| `playerData` | `_handle_player_data()` | Full character refresh → GameInfo |
| `startExpeditionResponse` | `_handle_start_expedition_response()` | Start expedition travel timer |
| `expeditionOptionResponse` | `_handle_expedition_option_response()` | Advance expedition slide or show combat |
| `localChat` / `globalChat` | `_handle_chat_message()` | Append to GameInfo.chat_messages |
| `combatLog` | `_handle_combat_log()` | Populate GameInfo.current_combat_log, show CombatPanel |

**Outbound API** (actions the client sends):
| Category | Methods |
|---|---|
| **Items** | `move_item()`, `sell_item()`, `buy_item()`, `socket_item()`, `enchant_item()`, `temper_item()` |
| **Consumables** | `use_potion()`, `use_elixir()`, `use_hammer()`, `use_scroll()`, `brew_elixir()` |
| **Stats** | `train_stat()` |
| **Talents/Perks** | `add_talent()`, `reset_talents()`, `activate_perk()` |
| **Blessings** | `choose_blessing()` |
| **Quests** | `accept_quest()`, `quest_option()`, `quest_cancel()` |
| **Expeditions** | `start_expedition()`, `expedition_option()`, `expedition_cancel()` |
| **Travel** | `skip_travel()` |
| **Combat** | `fight_player()`, `load_enemy()` |
| **Chat** | `send_chat(type, message)` — 0=local, 1=global |
| **Lobby** | `join_lobby(server_id, character_id, token)` |
| **Rankings** | `load_rankings(direction, reference_rank)` — 1=up, 2=down, 3=center |

### Http

**Role:** HTTP REST client for authentication and account management only.

**Base URL:** `http://localhost:8080`

**Signals:**
- `login_completed(success, data, error)`
- `create_character_completed(success, character_id, error)`

**Endpoints:**
| Method | Endpoint | Purpose |
|---|---|---|
| POST | `/login` | Email/password authentication |
| GET | `/lobby` | Fetch lobby data (requires Bearer token) |
| POST | `/create-character` | Create new character |
| POST | `/logout` | End session |

### DataManager

**Role:** Data versioning, downloading, caching, and converting JSON to Godot Resource databases.

**Storage paths:**
- `user://data_versions.cfg` — version tracking
- `user://data/` — cached JSON files
- `user://images/` — cached asset textures
- S3 base: `https://gamedata-assets.s3.eu-north-1.amazonaws.com/images/`

**Flow:**
1. On login, compare `server_data_versions` vs `local_versions`
2. Download outdated JSON data + related image assets from S3
3. Convert JSON → Godot Resource databases (lazy-loaded)

**Databases produced:** EffectDatabase, ItemDatabase, PerkDatabase, EnemyDatabase, ExpeditionsDatabase, SettlementsDatabase, TalentsDatabase, QuestsDatabase

### TooltipManager

**Role:** Spawn, position, and manage item and perk tooltips. Layer 100 (always on top).

**Positioning logic:**
- Equipment slots (left): tooltip appears to the right
- Equipment slots (right): tooltip appears to the left
- Bag slots: tooltip appears above (fallback below)
- All positions clamped to viewport edges

### SettingsManager

**Role:** Per-character local settings stored as `user://settings/character_{id}.cfg`.

**Default settings:**
```gdscript
{
  "gameplay": { "disable_ads": false, "language": "English" },
  "audio":    { "master_volume": 100.0, "music_volume": 100.0 },
  "video":    { "ui_size": "Medium" }
}
```

---

## 5. Data Model & Inner Classes

All defined as inner classes inside `GameInfo.gd`.

### Item

Represents an inventory item (weapon, armor, gem, potion, elixir, ingredient, etc.).

**Server-persisted properties:**
| Property | Type | Description |
|---|---|---|
| `id` | int | Item ID (maps to ItemResource in items_db) |
| `bag_slot_id` | int | Slot position (0=unequipped, 1-9=equip, 10-14=bag) |
| `day` | int | Day acquired (for stat scaling) |
| `tempered` | int | Tempering level (0+, each adds 10% stats) |
| `effect_overdrive` | int | Enchanted effect ID override |
| `socket_id` | int | Socketed gem item ID (-1=empty) |
| `socket_day` | int | Day value for socketed gem |
| `ingredients` | Array[int] | Ingredient item IDs (for elixirs, id=1000) |

**Database-lookup properties:** `item_name`, `type`, `price`, `has_socket`

**Calculated stats** (scaled by day + tempered): `strength`, `stamina`, `agility`, `luck`, `armor`, `damage_min`, `damage_max`

**Effect properties:** `effect_id`, `effect_factor`, `effect_name`, `effect_description`

**Key method:**
```gdscript
static func calculate_scaled_value(base: int, day: int, tempered: int) -> int
    # result = base × 1.02^day
    # for each temper level: result += ceil(result × 0.1)
```

### Perk

| Property | Type | Description |
|---|---|---|
| `id` | int | Perk ID |
| `active` | bool | Currently active |
| `slot` | int | Talent slot it's bound to |
| `perk_name` | String | From database |
| `effect1_id`, `factor1` | int, float | First effect |
| `effect2_id`, `factor2` | int, float | Second effect |
| `texture` | Texture2D | From database |

### Talent

| Property | Type | Description |
|---|---|---|
| `talent_id` | int | Talent ID |
| `points` | int | Points invested |

### ChatMessage

| Property | Type | Description |
|---|---|---|
| `sender` | String | Character name |
| `timestamp` | String | ISO 8601 |
| `status` | String | "peasant" or "lord" |
| `message` | String | Content |
| `type` | String | "global" or "local" |

### CombatLogEntry

| Property | Type | Description |
|---|---|---|
| `turn` | int | Turn number |
| `character_id` | int | Who acted |
| `action` | String | Action description |
| `factor` | int | Damage/heal amount |

### CombatResponse

**Player fields:** `player_id`, `player_name`, `player_max_hp`, `player_depleted_health`, `player_avatar`
**Enemy fields:** `enemy_id`, `enemy_name`, `enemy_max_hp`, `enemy_avatar`, `enemy_asset_id`, `enemy_npc_id`
**Result:** `winner_id`, `combat_log: Array[CombatLogEntry]`
**Methods:** `has_won()`, `is_enemy_npc()`

### GamePlayer (base class for all players)

| Category | Properties |
|---|---|
| **Identity** | `character_id`, `name`, `rank`, `faction`, `profession`, `honor` |
| **Base Stats** | `strength`, `stamina`, `agility`, `luck`, `armor`, `damage_min`, `damage_max` |
| **Avatar** | `avatar_face`, `avatar_hair`, `avatar_eyes`, `avatar_nose`, `avatar_mouth` |
| **Active Effects** | `blessing`, `potion`, `potion_day`, `elixir`, `elixir_day`, `elixir_ingredients`, `depleted_health` |
| **Collections** | `bag_slots: Array[Item]`, `perks: Array[Perk]`, `talents: Array[Talent]` |

**Key methods:**

- `get_total_stats()` — Base stats + equipped item stats + gem stats + effect bonuses
- `get_total_effects()` — Sum effects from: equipment, potion, blessing, perks, elixir ingredients, talents
- `get_damage_range()` — `{min: damage_min × strength, max: damage_max × strength}`
- `get_faction_name()` — 1="Order", 2="Guild", 3="Companions"

### GameCurrentPlayer (extends GamePlayer)

| Category | Properties |
|---|---|
| **World State** | `location`, `traveling` (unix timestamp), `traveling_destination`, `dungeon`, `destination`, `slide`, `slides` |
| **Progression** | `talent_points`, `quest_log`, `daily_quests`, `expedition` |
| **Server Context** | `server_timezone`, `server_day`, `weather` |
| **Economy** | `silver`, `vip` |
| **Time-limited** | `potion_until`, `elixir_until` (unix timestamps) |
| **Settlement Data** | `enchanter_effects`, `vendor_items` |

**Key methods:**
- `add_perk_if_new(perk_id)` — adds perk if not owned
- `add_item_to_bag(item_id)` — insert into first empty bag slot (10-14)
- `check_expired_effects()` — remove expired potions/elixirs (both timestamp and day-based)

---

## 6. Networking Layer

### Authentication Flow

```
LoginPanel                  Http                    Server (REST :8080)
    │                        │                           │
    ├─ _on_login() ─────────►│                           │
    │                        ├─ POST /login ────────────►│
    │                        │◄──── session_id + lobby ──┤
    │◄── login_completed ────┤                           │
    │                        │                           │
    ├─ show LobbyPanel       │                           │
```

### Gameplay Session Flow

```
LobbyPanel              Websocket                Server (WS :3000)
    │                       │                          │
    ├─ connect_to_server()─►│                          │
    │                       ├─ WS connect ────────────►│
    │                       │                          │
    ├─ join_lobby() ───────►│                          │
    │                       ├─ {joinLobby, ...} ──────►│
    │                       │◄── {playerData, ...} ────┤
    │◄── player_data_received│                          │
    │                       │                          │
    ├─ load into GameInfo   │                          │
    ├─ show game.tscn       │                          │
    │                       │                          │
    │  (gameplay actions)   │                          │
    ├─ Websocket.fight()───►│                          │
    │                       ├─ {fight, enemy_id} ─────►│
    │                       │◄── {combatLog, ...} ─────┤
    │                       ├─ GameInfo.combat_log = ..│
    │                       ├─ show CombatPanel        │
```

### Server Data Transformation

The server sends data in its own format. `GameInfo._transform_server_player_data()` maps it to client format:

| Server Field | Client Field |
|---|---|
| `character_name` | `name` |
| `honnor` | `honor` |
| `settlement_id` | `location` |
| `avatar` (object) | `avatar_face/hair/eyes/nose/mouth` |
| `stats` (object) | `strength/stamina/agility/luck/armor/damage_min/damage_max` |
| ISO 8601 timestamps | Unix timestamps (float) |

---

## 7. Data Pipeline & Versioning

```
Login Response
    │
    ├─ server_data_versions: { effects: 3, items: 5, world: 2, ... }
    │
    ▼
DataManager.needs_download()
    │
    ├─ Compare against local_versions (user://data_versions.cfg)
    │
    ▼ (if outdated)
DataManager.sync_data()
    │
    ├─ HTTP GET each outdated data type
    ├─ Merge with existing local JSON
    ├─ Save to user://data/{type}.json
    ├─ Download related images from S3 → user://images/{folder}/
    └─ Update local_versions.cfg
    │
    ▼ (on demand, lazy-loaded)
DataManager.get_{type}_database()
    │
    ├─ Parse local JSON
    ├─ Create Resource objects (ItemResource, PerkResource, etc.)
    ├─ Attach cached textures
    └─ Return Database object
    │
    ▼
GameInfo.load_databases()
    │
    └─ Store references: GameInfo.items_db = DataManager.get_items_database()
```

**Data type → server key mapping:**
| Local Key | Server Key | JSON Path |
|---|---|---|
| effects | effects | `user://data/effects.json` |
| items | items | `user://data/items.json` |
| perks | perks | `user://data/perks.json` |
| enemies | enemies | `user://data/enemies.json` |
| expeditions | expedition | `user://data/expeditions.json` |
| settlements | world | `user://data/settlements.json` |
| talents | talents | `user://data/talents.json` |
| quests | quests | `user://data/quests.json` |

---

## 8. Game Systems

### 8.1 Inventory & Item Management

**Slot Layout:**

| Slot Range | Purpose | Count |
|---|---|---|
| 1–9 | Equipment (head, chest, hands, foot, belt, legs, ring, amulet, weapon) | 9 |
| 10–14 | Bag (general inventory) | 5 |
| 15–19 | Utility panel slots | 5 |
| 20–28 | Vendor display slots | 9 |
| 29 | Consume/use slot | 1 |

**Item Types (16 total):**

| ID | Type | Equip Slot |
|---|---|---|
| 0 | Head | 1 |
| 1 | Chest | 2 |
| 2 | Hands | 3 |
| 3 | Foot | 4 |
| 4 | Belt | 5 |
| 5 | Legs | 6 |
| 6 | Ring | 7 |
| 7 | Amulet | 8 |
| 8 | Weapon | 9 |
| 9 | Gem | (socketed into equipment) |
| 10 | Potion | (used from bag) |
| 11 | Elixir | (brewed, time-limited) |
| 12 | Scroll | (enchants equipment) |
| 13 | Hammer | (tempers equipment) |
| 14 | Ration | (consumed) |
| 15 | Ingredient | (used in alchemy) |

**Drag-and-drop rules** (InventorySlot.gd):
- Equipment slots accept only matching item types
- Bag → Vendor = sell (gain silver)
- Vendor → Bag = buy (spend silver × 2)
- Gem + Equipment with socket = socket_item
- Hammer + Temperable item = temper (+10% stats, costs silver)
- Scroll + Enchantable item = enchant (costs silver)
- Double-click: auto-equip, auto-consume, or auto-move

### 8.2 Quest System

Flat option-based dialogue system. Each quest has a top-level text and a flat array of options (no slide grouping on server).

**Structure:**
- `QuestData` → flat Array of `QuestOption`
- Options are linked by `requirements` (which options must be clicked first) and `start` flags
- Options have: `node_text` (text shown when reached), `option_text` (button label), requirement checks, rewards

**Option requirement types:**
- **Stat check:** `stat_type` + `stat_required` (scales with server day)
- **Silver check:** `silver_required`
- **Faction check:** `faction_required` (1=Order, 2=Guild, 3=Companions)
- **Effect check:** `effect_id_required` + `effect_amount_required`
- **Dependency:** `requirements` array of option IDs that must be clicked first
- **Combat:** `enemy_id` triggers a fight

**Option effects:**
- `effect_applied` + `effect_applied_factor` — applies an effect to the player on selection
- `quest_end: true` — marks the option as ending the quest

**Rewards** (nested `reward` object): silver, items, perks, talent points, potions, blessings, stat boosts

**Combat integration:** Options with `enemy_id > 0` trigger server combat, resolved via `combatLog` message

### 8.3 Expedition System

Slide-based adventures. Each expedition is a collection of slides linked to a settlement.

**Structure:**
- Slides are stored flat in `ExpeditionsDatabase` (not grouped per expedition)
- Each slide has `settlement_id` to identify which settlement it belongs to
- `is_start: true` marks the entry slide for an expedition
- Slides can have effects (damage/heal), rewards, and branching options

**Flow:**
1. Player starts expedition at a settlement
2. Server returns first `slide_id` (the `is_start` slide for that settlement) + travel timer
3. Each slide shows text, optional reward, and options
4. Options can have requirements: stat, silver, faction, effect checks
5. Server validates choice, returns next slide or combat
6. Health can deplete via effects during expedition
7. Ends when reaching a terminal slide

**Option requirement types** (same as quests):
- Stat check, silver check, faction check, effect check, combat

**Rewards** (nested `reward` object): silver, items, perks, talent points, potions, blessings, stat boosts

**Deletion support:** Server sends `deleted_slide_ids` during sync to remove stale slides from client cache.

**Server communication:**
- `Websocket.start_expedition()` → `startExpeditionResponse`
- `Websocket.expedition_option(option_id)` → `expeditionOptionResponse`

### 8.4 Combat System

**Server-authoritative.** Client receives the full combat log and plays it back visually.

**CombatPanel playback:**
1. Parse `CombatResponse` from server
2. Set up player/enemy avatars and health bars
3. Animate through `CombatLogEntry` array sequentially
4. Health bars decrease/increase per entry's `factor`
5. Show winner at end
6. Skip button available to jump to result

**Health formula:** `max_hp = stamina × 10`, `current_hp = max_hp × (1 - depleted_health / 100)`

### 8.5 Talent Tree

Grid-based talent system with perk slot unlocking.

**TalentResource properties:** `talent_id`, `name`, `description`, `max_points`, `perk_slot` (bool), `effect_id`, `factor`, `row`, `col`

**Upgrade rules:**
1. Points < max_points
2. Player has unspent talent_points
3. At least one neighbor talent is maxed (or talent is a starter)

**Two talent types:**
- **Stat talents:** Each point grants `effect_id` bonus × `factor`
- **Perk slot talents:** Unlocks a perk slot where the player can bind a perk

**Visual states:** White (active, has points) → Light gray (upgradeable) → Dark gray (locked)

### 8.6 Perk System

Passive dual-effect abilities bound to unlocked talent perk slots.

**Flow:**
1. Unlock perk slot via talent tree
2. Acquire perks through quests/expeditions
3. Open PerkScreen for a specific talent slot
4. Bind a perk to that slot → `Websocket.activate_perk(talent_id, perk_id)`
5. Only one perk active per slot

**Each perk provides two effects** (effect1 + effect2), factored into total player stats.

### 8.7 Crafting Systems

**Blacksmith (Tempering):**
- Cost: 10 silver
- Effect: +10% to all item stats (iterative, compounds)
- Increments `item.tempered` counter

**Enchanter:**
- Cost: 10 silver
- Applies an effect (from `enchanter_effects` list) to an item
- Only effects matching the item type/slot are available
- Sets `item.effect_overdrive`

**Alchemist (Elixir Brewing):**
- Cost: 10 silver
- Combines 1–3 ingredient items
- Creates an elixir (id=1000) with combined effects
- Elixir has time-limited duration

### 8.8 Settlement Services

Each settlement provides different sub-locations:

| Service | Script | Purpose |
|---|---|---|
| Vendor | VendorPanel.gd | Buy/sell items (NPC-specific inventory) |
| Trainer | TrainerPanel.gd | Train stats (5 silver/stat, 100 silver/talent point) |
| Church | ChurchPanel.gd | Choose 1 of 3 blessings (10 silver) |
| Blacksmith | BlacksmithPanel.gd | Temper items (10 silver) |
| Enchanter | EnchanterPanel.gd | Enchant items (10 silver) |
| Alchemist | AlchemistPanel.gd | Brew elixirs (10 silver) |
| Arena | Arena.gd | PvP fights |
| Expedition | ExpeditionPanel.gd | Adventure runs |

### 8.9 Travel

- Traveling between settlements takes time (server-provided unix timestamp)
- `MapPanel` shows countdown progress bar
- Skip button accelerates travel (costs mushrooms)
- VIP = instant travel
- On arrival: load quest or expedition depending on destination

### 8.10 Chat

- Two channels: global (all servers) and local (current settlement)
- Timestamp separators appear if 10+ minutes between messages
- "Lord" status = gold name color, "Peasant" = white
- Messages stored in `GameInfo.chat_messages`

### 8.11 Rankings

- Leaderboard sorted by honor
- Paginated: loads 20 rows at a time (direction: up/down/center)
- Clicking a row shows a player card with stats
- Can initiate PvP fight from the rankings

---

## 9. UI Architecture

### Panel & Overlay System (UIManager / TogglePanel.gd)

The game has a single `game.tscn` scene with all panels. UIManager orchestrates visibility.

**8 main panels:** Home, Arena, Quest, Expedition, Character, Rankings, Map, Combat

**Overlay stack:** Z-indexed overlays that push/pop above the active panel (BASE_Z_INDEX = 200).

**Overlay contract** — every overlay must implement:
```gdscript
func show_overlay():
    visible = true
    # local animations

func hide_overlay():
    # local animations
    visible = false
```

**Back button priority (5 levels):**
1. Chat panel (if open)
2. Sub-overlays (modals within overlays)
3. Overlay stack (pop top overlay)
4. Panel-specific back (quest cancel, etc.)
5. Default (return to home)

**State blocking:** UIManager prevents navigation away from active quests, expeditions, or travel.

### Responsive Scaling (ResolutionManager.gd)

Portrait-only mobile scaling:
- Base: 405×900 (21:9 aspect — tallest phone)
- Max width: 16:9 aspect ratio
- Scales via Godot's `CANVAS_ITEMS` stretch mode with `KEEP_HEIGHT`
- User font scale preference (emits `user_font_scale_changed` signal)

### Node References

Per COPILOT_GUIDELINES.md:
- All external node references use `@export var` + editor assignment
- No hardcoded NodePaths or runtime tree searches
- Signals connected in editor when possible, otherwise via `@onready var`

---

## 10. Scene Graph & Key Scenes

### login.tscn (Main Scene)
Entry point. Contains LoginPanel for authentication → transitions to game.tscn.

### game.tscn (Primary Gameplay)
All game panels and overlays exist as children. UIManager controls visibility.

```
game.tscn
├── UIManager (TogglePanel.gd)
│   ├── TopUI (header bar: silver, mushrooms, avatar)
│   ├── HomePanel (VillagePanel.gd - buildings)
│   ├── MapPanel
│   ├── QuestPanel (Quest.gd)
│   ├── ExpeditionPanel
│   ├── CombatPanel
│   ├── ArenaPanel
│   ├── CharacterPanel
│   │   ├── CharacterDisplay
│   │   ├── Equip (bag + equipment slots)
│   │   └── TalentGrid (SetTalents.gd)
│   ├── RankingsPanel
│   ├── ChatPanel (overlay)
│   ├── VendorPanel (overlay)
│   ├── TrainerPanel (overlay)
│   ├── BlacksmithPanel (overlay)
│   ├── EnchanterPanel (overlay)
│   ├── AlchemistPanel (overlay)
│   ├── ChurchPanel (overlay)
│   ├── PerkScreen (overlay)
│   ├── SettingsPanel (overlay)
│   ├── LogoutPanel (overlay)
│   └── PaymentPanel (overlay)
```

### Prefab Scenes
| Scene | Purpose | Script |
|---|---|---|
| `item.tscn` | Draggable item visual | ItemDrag.gd |
| `ItemSlot.tscn` | Inventory slot container | InventorySlot.gd |
| `item_description.tscn` | Item tooltip | ItemDescription.gd |
| `perk.tscn` | Perk display node | (PerkMini.gd) |
| `perk_tooltip.tscn` | Perk tooltip | — |
| `quest_option.tscn` | Quest dialogue button | QuestOption.gd |
| `enchant_option.tscn` | Enchanter effect row | EnchantOption.gd |
| `arena_opponent.tscn` | Arena opponent card | ArenaOpponent.gd |
| `ranking_row.tscn` | Leaderboard row | RankingRow.gd |
| `healthbar.tscn` | Health bar | — |
| `bubble.tscn` | Chat message | bubble.gd |
| `ChatBubble.tscn` | NPC dialogue bubble | ChatBubble.gd |
| `avatar.tscn` | Layered avatar (5 layers) | Avatar.gd |
| `playercard.tscn` | Lobby character card | PlayerCard.gd |
| `Building.tscn` | Clickable building | Building.gd |
| `bag.tscn` | Bag grid | Equip.gd |
| `Utility.tscn` | Utility building | Utility.gd |

---

## 11. Resource Database Schema

All loaded from JSON via DataManager. Each database is a Godot Resource with an array of resources.

The schemas below reflect the **current server SQL functions** (`download_*`). Fields marked with ⚠️ are sent by the server but **not yet read by the client**.

### EffectDatabase / EffectResource

✅ Fully synced — client matches server.

```
effect_id: int
name: String
description: String
slot: int             # EffectSlot enum (0=ANY, 1=HEAD, ..., 9=WEAPON)
factor: int
```

### ItemDatabase / ItemResource

✅ Fully synced — client matches server.

```
item_id: int
item_name: String
type: String          # "head", "chest", etc. → mapped to ItemType enum on client
strength, stamina, agility, luck, armor: int
min_damage, max_damage: int
effect_id: int
effect_factor: int
socket: bool
silver: int           # Base price
asset_id: int
texture: Texture2D    # Loaded from cache at runtime
```

### PerkDatabase / PerkResource

```
perk_id: int
perk_name: String
description: String
effect_id_1: int, factor_1: float
effect_id_2: int, factor_2: float
asset_id: int
is_blessing: bool     # ⚠️ NEW — marks perk as a blessing (not yet read by client)
texture: Texture2D
```

### EnemyDatabase / EnemyResource

✅ Fully synced — client matches server.

```
enemy_id: int
enemy_name: String
description: String
asset_id: int
texture: Texture2D
```

### TalentsDatabase / TalentResource

✅ Fully synced — client matches server.

```
talent_id: int
name: String
description: String
max_points: int
perk_slot: bool       # Unlocks a perk slot
effect_id: int
factor: float
row: int, col: int    # Grid position
```

### SettlementsDatabase / Settlement (download_world)

Faction is numeric: **1 = Order, 2 = Guild, 3 = Companions**.

```
settlement_id: int
settlement_name: String
settlement_asset_id: int
faction: int                         # 1=Order, 2=Guild, 3=Companions
description: String

# Expedition
expedition_asset_id: int
expedition_description: String
expedition_failure: Array[String]    # ⚠️ NEW — failure texts (not yet read by client)

# Arena
arena_asset_id: int

# Vendor (nested object)
vendor:
  vendor_asset_id: int
  on_entered: Array[String]
  on_sold: Array[String]
  on_bought: Array[String]

# Utility (nested object)
utility:
  type: String                       # "blacksmith"|"alchemist"|"enchanter"|"trainer"|"church"
  utility_asset_id: int
  on_entered: Array[String]
  on_placed: Array[String]
  on_action: Array[String]
  blessing1, blessing2, blessing3: int   # Church-only perk IDs
```

### QuestsDatabase / QuestData (download_quests)

Flat option-based structure (no slides). Each quest has top-level fields and a flat array of options.

```
quest_id: int
name: String
settlement_id: int
asset_id: int
start_text: String                   # → mapped to initial_text on client
travel_text: String
failure_text: String                 # ⚠️ NEW — text shown on quest failure (not yet read)

options: Array[QuestOption]          # Flat array, no slide grouping
```

**QuestOption** (server JSON keys → client field names):

```
option_id: int
node_text: String                    # Text displayed when this option's node is reached
option_text: String                  # Button label
start: bool                          # → is_start on client; marks initially visible options
quest_end: bool                      # ⚠️ NEW — marks option as quest-ending (not yet read)

# Requirements (what the player needs to choose this option)
stat_type: int                       # 1=STR, 2=STA, 3=AGI, 4=LCK
stat_required: int
silver_required: int                 # ⚠️ NEW — silver cost gate (not yet read)
faction_required: int                # ⚠️ NEW — faction gate: 1=Order, 2=Guild, 3=Companions (not yet read)
effect_id_required: int              # ⚠️ RENAMED from effect_id (client reads old key)
effect_amount_required: int          # ⚠️ RENAMED from effect_amount (client reads old key)
enemy_id: int                        # Enemy to fight (0 = no combat)

# Effects applied when option is chosen
effect_applied: int                  # ⚠️ NEW — effect ID applied to player (not yet read)
effect_applied_factor: float         # ⚠️ NEW — effect magnitude applied (not yet read)

# Reward (nested "reward" object from server)
reward:
  reward_stat_type: int
  reward_stat_amount: int
  silver: int                        # ⚠️ NEW — silver reward (not yet read; nested under reward)
  item: int                          # Item ID
  perk: int                          # Perk ID
  blessing: int                      # Blessing ID
  potion: int                        # Potion ID
  talent: int                        # Talent points

# Dependencies
requirements: Array[int]             # Option IDs that must be clicked first
```

> **Note:** Client currently reads reward fields flat (e.g. `opt.get("reward_stat_type")`) but server now nests them inside a `reward` object. The DataManager needs to unwrap: `opt.get("reward", {}).get("reward_stat_type", 0)`.

### ExpeditionsDatabase / ExpeditionSlide (download_expedition)

Expeditions are a flat collection of slides (no ExpeditionData grouping). Slides are linked to settlements via `settlement_id`.

Server supports **soft-delete** via `deleted_slide_ids` array.

```
version: int
slides: Array[ExpeditionSlide]
deleted_slide_ids: Array[int]        # ⚠️ NEW — IDs to remove from local cache (not yet handled)
```

**ExpeditionSlide:**

```
slide_id: int
slide_text: String
asset_id: int
is_start: bool                       # ⚠️ NEW — marks this as a starting slide (not yet read)
settlement_id: int                   # ⚠️ NEW — which settlement this slide belongs to (not yet read)
effect_id: int
effect_factor: float

# Reward (nested "reward" object from server)
reward:
  reward_stat_type: int
  reward_stat_amount: int
  silver: int                        # ⚠️ NEW — silver reward (not yet read)
  talent: int
  item: int
  perk: int
  blessing: int
  potion: int

options: Array[ExpeditionOption]
```

> **Note:** Client currently reads reward fields flat (`item.get("reward_stat_type")`) but server now nests them inside a `reward` object.

**ExpeditionOption:**

```
option_id: int
option_text: String
stat_type_required: String           # ⚠️ RENAMED from stat_type (client reads old key)
stat_required: int
silver_required: int                 # ⚠️ NEW — silver cost gate (not yet read)
faction_required: int                # ⚠️ NEW — faction gate: 1/2/3 (not yet read)
effect_id_required: int              # ⚠️ RENAMED from effect_id (client reads old key)
effect_amount_required: float        # ⚠️ RENAMED from effect_amount (client reads old key)
enemy_id: int
```

---

## 12. Server ↔ Client Sync Status

This section tracks differences between the current server SQL functions and the Godot client code. Items marked ⚠️ require client-side changes.

### Fully Synced (no changes needed)

| Database | Status |
|---|---|
| Effects | ✅ All fields match |
| Items | ✅ All fields match |
| Enemies | ✅ All fields match |
| Talents | ✅ All fields match |

### Requires Client Updates

#### Perks — `is_blessing` field
| Change | Detail |
|---|---|
| New field | `is_blessing: bool` — distinguishes blessings from regular perks |
| Client file | `PerkResource.gd` — add `@export var is_blessing: bool = false` |
| DataManager | `_load_perks_database()` — add `perk.is_blessing = item.get("is_blessing", false)` |

#### Settlements — `expedition_failure` field
| Change | Detail |
|---|---|
| New field | `expedition_failure: Array[String]` — failure texts for expeditions |
| Client file | `Settlement.gd` — add `@export var expedition_failure: Array[String] = []` |
| DataManager | `_load_settlements_database()` — read from settlement JSON |

#### Quests — Multiple changes
| Change | Detail |
|---|---|
| New field | `failure_text: String` on QuestData |
| New option field | `quest_end: bool` — marks quest-ending option |
| New option field | `silver_required: int` — silver cost requirement |
| New option field | `faction_required: int` — faction gate (1=Order, 2=Guild, 3=Companions) |
| New option field | `effect_applied: int` — effect applied on choosing option |
| New option field | `effect_applied_factor: float` — effect magnitude |
| Renamed field | `effect_id` → `effect_id_required` (option requirement) |
| Renamed field | `effect_amount` → `effect_amount_required` (option requirement) |
| Structural | Rewards now nested in `reward` object — client reads flat |
| New reward field | `reward.silver` — silver reward |
| Removed field | `ending` on QuestData — no longer sent by server |
| Removed field | `default_entry` — replaced by `start: true` on options |

#### Expeditions — Multiple changes
| Change | Detail |
|---|---|
| New slide field | `is_start: bool` — marks starting slides |
| New slide field | `settlement_id: int` — links slide to settlement |
| New option field | `silver_required: int` |
| New option field | `faction_required: int` |
| Renamed field | `stat_type` → `stat_type_required` (option) |
| Renamed field | `effect_id` → `effect_id_required` (option) |
| Renamed field | `effect_amount` → `effect_amount_required` (option) |
| Structural | Rewards now nested in `reward` object — client reads flat |
| New reward field | `reward.silver` — silver reward |
| Deletion support | `deleted_slide_ids: Array[int]` — must remove from local cache |

### Shared Requirement Types (Quests & Expeditions)

Both quest and expedition options now support the same requirement types:

| Requirement | JSON Key | Type | Description |
|---|---|---|---|
| Stat check | `stat_type` + `stat_required` | int + int | Player stat ≥ required |
| Silver check | `silver_required` | int | Player silver ≥ required |
| Faction check | `faction_required` | int | Player faction must match (1/2/3) |
| Effect check | `effect_id_required` + `effect_amount_required` | int + int/float | Player has effect ≥ amount |
| Combat | `enemy_id` | int | Must defeat enemy (0 = no combat) |

### Shared Reward Types (Quests & Expeditions)

Both now use a nested `reward` object with:

| Reward | JSON Key | Type |
|---|---|---|
| Stat increase | `reward_stat_type` + `reward_stat_amount` | int + int |
| Silver | `silver` | int |
| Item | `item` | int (item ID) |
| Perk | `perk` | int (perk ID) |
| Blessing | `blessing` | int (blessing/perk ID) |
| Potion | `potion` | int (potion item ID) |
| Talent points | `talent` | int |

### Faction Values (Numeric)

Factions are stored and transmitted as integers everywhere:

| Value | Faction |
|---|---|
| 1 | Order |
| 2 | Guild |
| 3 | Companions |

---

## 13. Formulas & Game Math

### Item Stat Scaling

$$\text{stat} = \text{base} \times 1.02^{\text{day}}$$

$$\text{tempered\_stat} = \text{stat} + \lceil \text{stat} \times 0.1 \rceil \quad \text{(applied iteratively per temper level)}$$

### Total Player Stats

$$\text{total\_stat} = \left( \text{base} + \sum_{\text{equipped items}} \text{item\_stat} + \sum_{\text{socketed gems}} \text{gem\_stat} \right) \times \left( 1 + \frac{\text{total\_effects}[\text{effect\_id}]}{100} \right)$$

### Total Effects Aggregation

$$\text{total\_effects}[\text{id}] = \sum_{\text{equipment}} f_{\text{equip}} + f_{\text{potion}} + f_{\text{blessing}} + \sum_{\text{active perks}} (f_1 + f_2) + \sum_{\text{elixir ingredients}} f_{\text{ingr}} + \sum_{\text{talents}} (\text{points} \times \text{factor})$$

### Damage Range

$$\text{damage\_min} = \text{min\_damage} \times \text{strength}$$
$$\text{damage\_max} = \text{max\_damage} \times \text{strength}$$

### Health

$$\text{max\_hp} = \text{stamina} \times 10$$
$$\text{current\_hp} = \text{max\_hp} \times \left(1 - \frac{\text{depleted\_health}}{100}\right)$$

### Quest Stat Scaling (per server day)

$$\text{requirement} = \text{base\_req} \times 1.02^{(\text{server\_day} - 1)}$$
$$\text{reward} = \text{base\_reward} \times 1.02^{(\text{server\_day} - 1)}$$

### Training Costs

| Target | Cost |
|---|---|
| Strength / Stamina / Agility / Luck | 5 silver |
| Talent Point | 100 silver |

### Crafting Costs

| Action | Cost |
|---|---|
| Temper (Blacksmith) | 10 silver |
| Enchant | 10 silver |
| Brew Elixir | 10 silver |
| Choose Blessing | 10 silver |
| Skip Travel | 1 mushroom |
| Start Expedition | 100 silver |
| Vendor Purchase | item.price × 2 |
| Vendor Sell | item.price |

---

## 14. Coding Conventions

Extracted from `COPILOT_GUIDELINES.md` and observed patterns:

1. **Node references:** Always `@export var` + editor assignment. No runtime `get_node()` or tree searches.
2. **Overlay contract:** Every overlay implements `show_overlay()` / `hide_overlay()`.
3. **State centralization:** All game state in `GameInfo`. UI reads from GameInfo, websocket writes to it.
4. **Simplicity:** Prefer explicit, straightforward solutions. No reflection (`has_method()`), no clever patterns.
5. **UI placement:** All UI lives in `game.tscn`. No dynamically created UI nodes unless truly dynamic.
6. **Styling:** Use existing `StyleBoxFlat` resources from the theme. Match existing padding.
7. **Signals:** Connect in editor when possible. Use `@onready var` or `@export var` for code connections.
8. **Typed GDScript 4.x:** Uses `class_name`, `@export`, `@onready`, typed arrays, static methods.
9. **Websocket parsing:** Centralized in Websocket autoload. Parsed data pushed to GameInfo. UI panels never parse network data.

---

## 15. File Reference Index

### Autoloads (scripts/global/)
| File | Singleton Name | Purpose |
|---|---|---|
| GameInfo.gd | `GameInfo` | Central data store + data classes |
| Websocket.gd | `Websocket` | WebSocket client |
| Http.gd | `Http` | REST API client |
| DataManager.gd | `DataManager` | Data versioning & caching |
| TooltipManager.gd | `TooltipManager` | Tooltip spawn & positioning |
| SettingsManager.gd | `SettingsManager` | Per-character settings |

### Core Gameplay Scripts
| File | System |
|---|---|
| Quest.gd | Branching quest dialogue |
| ExpeditionPanel.gd | Slide-based expeditions |
| CombatPanel.gd | Combat log playback |
| Arena.gd | PvP opponent selection |
| MapPanel.gd | Travel timer & destination |
| InventorySlot.gd | Drag-and-drop inventory |
| ItemDrag.gd | Drag preview & double-click |
| Equip.gd | Equipment display |
| CharacterDisplay.gd | Stat sheet |
| Talent.gd | Talent tree node |
| SetTalents.gd | Talent grid layout |
| PerkScreen.gd | Perk binding |

### Service Panels
| File | Service |
|---|---|
| VendorPanel.gd | Buy/sell items |
| TrainerPanel.gd | Train stats |
| BlacksmithPanel.gd | Temper items |
| EnchanterPanel.gd | Enchant items |
| AlchemistPanel.gd | Brew elixirs |
| ChurchPanel.gd | Blessings |

### UI & Navigation
| File | Purpose |
|---|---|
| TogglePanel.gd | UIManager (panel/overlay orchestration) |
| LoginPanel.gd | Authentication flow |
| LobbyPanel.gd | Character select, server join |
| ChatPanel.gd | Global/local chat |
| Rankings.gd | Leaderboard |
| ResolutionManager.gd | Responsive scaling |
| Avatar.gd | Layered avatar rendering |
| AvatarPanel.gd | Avatar customization |
| Building.gd | Clickable building |
| ItemDescription.gd | Item tooltip content |
| CharacterInfoPanel.gd | Character creation form |
| Payment.gd | Monetization (placeholder) |
| LogoutPanel.gd | Logout confirmation |

### Resources (scripts/resources/)
| Databases | Resources |
|---|---|
| EffectDatabase.gd | EffectResource.gd |
| ItemDatabase.gd | ItemResource.gd |
| PerkDatabase.gd | PerkResource.gd |
| EnemyDatabase.gd | EnemyResource.gd |
| ExpeditionsDatabase.gd | ExpeditionData.gd, ExpeditionSlide.gd, ExpeditionOption.gd |
| SettlementsDatabase.gd | Settlement.gd |
| TalentsDatabase.gd | TalentResource.gd |
| QuestsDatabase.gd | QuestData.gd, QuestSlide.gd, QuestOption.gd, QuestReward.gd |
| CosmeticDatabase.gd | CosmeticResource.gd |
| NpcDatabase.gd | NpcResource.gd |
