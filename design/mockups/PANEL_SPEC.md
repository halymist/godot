# Wilds mockup — panel spec and refactor checklist

Companion to `README.md` (what the mockup file is, how to open it) and `CODEX_HANDOFF.md`
(project conventions, mockup→script map, definition of done). This document covers what
those two do not: **what each screen actually shows and does**, and **which game mechanics
changed in the mockup and therefore have to change in Godot too**.

Read order for a refactor task: `CODEX_HANDOFF.md` → the relevant section here → the panel
in the mockup → the existing scene/script.

> **Scope note.** The mockup is a behavioural and visual target. Pixel values quoted here are
> the mockup's 390-unit logical frame; treat them as proportions and intent, not literal
> Godot coordinates. Anything marked **[verify]** is a Godot-side assumption I did not
> confirm by reading the code — check before relying on it.

---

## Part 1 — Cross-cutting systems

These are not owned by any one panel and should be built once, first. Most per-panel work
becomes small if these land properly.

### 1.1 Design tokens

Defined on `:root` in the mockup; port to theme resources rather than per-scene constants.

| Token | Value | Meaning |
| --- | --- | --- |
| `--bg` | `#0f0f0d` | app background base |
| `--ink` / `--ink-dim` / `--ink-faint` | `#e4ddc9` / `#a49a86` / `#6e6553` | text primary / secondary / tertiary |
| `--hair` | `#3a352b` | hairline dividers |
| `--accent` | `#8fa06e` | the single accent (selection, price, confirm) |
| `--panel-surface` | `#17140f` | **opaque** surface for all bottom panels |
| `--btn-border` | `rgba(240,235,220,0.32)` | one border alpha for every tappable thing |
| `--btn-radius` / `--btn-radius-pill` | `6px` / `20px` | corner radii |
| `--btn-hover-bg` / `--btn-selected-bg` | `rgba(240,235,220,0.07)` / `rgba(143,160,110,0.12)` | hover / selected fills |
| `--slot-border` | `rgba(231,224,207,0.2)` | quieter border for slots (containers, not actions) |

**Rule that matters:** buttons, chips, tiles and list options all share one border/radius/hover
language. Slots get the quieter token. Panels do not invent their own.

### 1.2 The shell — top bar and dock

- **Top bar** (injected into every in-game phone): silver + label, mushrooms + label + `+`
  (taps to Payment), settings gear pushed right. Plain icons, no circular button chrome.
  Absent on pre-game screens (Login, Lobby, Create Char, Avatar).
- **Dock** (`--dock-h: 108px`), two rows:
  - utility row (44px): `Day N · <Settlement>`, HP bar, character portrait button
  - main row (64px): Back (own zone, divider) then Chat, Arena, Rank, Map, Home
- Quest hides the **dock only** and keeps the top bar — the only way out of a quest is
  through its own options.

### 1.3 Bottom panel surface

`.overlay-panel` is a **solid** `--panel-surface`, not a translucent wash over scene art.
A shared 24px overhanging band above it blurs and darkens the artwork into the surface so
there is no hard photographic cut. Quest is the deliberate exception (true full-screen modal).

Utility rooms share one footprint: **240px tall**, with the primary content locked to the
top **126px** band and the five-slot bag shelf below it in identical coordinates across
Vendor / Blacksmith / Alchemist / Enchanter / Church. Panels without a bag may use the lower
band for breathing room but must not move their actions.

### 1.4 Action rail (shared confirm control)

Utility rooms put their single confirm action in the same place: a circular button pinned to
the right edge of the content band with its price beneath, separated from the content by a
vertical hairline. `.util-body` reserves the right gutter so content never runs under it.

- States: enabled, `disabled` (dimmed, non-interactive), busy (`is-tempering` /
  `is-brewing` / `is-blessing` / `is-enchanting` — icon animates), max-level (price hidden).
- **Hidden entirely** when the action is impossible because nothing is selected (Blacksmith
  with an empty slot shows no button at all, not a dead one).

### 1.5 Inventory: bag, slots, drag/drop

One shared inventory model. Every `.char-bag` is the same five-slot shelf and shows the same
items. Two interaction paths, both required:

- **Drag and drop** — bag item → target slot, with `is-drag-over` highlight.
- **Click to select, click to place** — `is-selected` on the source, `is-target` on every
  legal destination, `is-invalid` shake on an illegal one.

Slots declare what they accept (`data-accepts="equipment" | "ingredient"`). An incompatible
drop is a silent no-op, not an error. Character panel additionally supports equip↔bag moves
with legality checks.

### 1.6 Item tooltips

Hover (not click) on anything with `data-item` / `data-effect` shows one floating card per
phone: name, price with silver icon, stat lines, damage range, effect line, socket row.
Effects use a shorter card (name + description only).

### 1.7 Audio

A small synth (`playUiSound(kind)`); no audio files. Kinds currently defined:

`tap` (default), `confirm`, `navigate`, `reset`, `buy`, `sell`, `equipment`, `ingredient`,
`combat-start`, `combat-swing`, `combat-hit`, `combat-dodge`, `combat-status`, `combat-stun`,
`combat-resist`, `combat-tick`, `combat-victory`.

Routing: action rail and confirm-ish controls → `confirm`; `[data-goto]` / dock / tabs →
`navigate`; talent reset → `reset`; everything else tappable → `tap`.

### 1.8 Motion and reduced motion

Screen changes cross-fade; quest steps have a leave (280ms) → enter (720ms) sequence with
staggered option reveals. Combat has an opening ceremony (fighters slide in, VS mark).
`prefers-reduced-motion` is respected for spinning/pulsing decorations — honour it in Godot too.

### 1.9 Responsive frame

The mockup phone is a **390-unit logical canvas** whose height varies; the preview shell is
resizable with a drag handle and live size readout. Width sets one uniform UI scale; height
expands to real portrait aspect ratios. Godot targets 405 × 900 — build with anchors and
containers and check both proportions. Do not port the mockup's pixel coordinates literally.

### 1.10 States every panel owes

Empty, loading, disabled, affordable vs unaffordable, and long-text overflow. The mockup
demonstrates several of these explicitly (Blacksmith empty slot, Alchemist placeholders,
Perks empty slot, disabled action rail).

---

## Part 2 — Mechanics changes (do these deliberately)

**This is the part that is not just visual.** These change game rules and touch data,
server payloads and balance — not only scenes.

### 2.1 Armor → Resolve  *(replaces a stat everywhere)*

The **Armor** stat is gone. **Resolve** replaces it as the core defensive stat.

- **Meaning changed, not just the name.** Armor blunted incoming damage. Resolve is a
  *resist* stat: it turns aside stun / bleed / poison outright.
- Icon: warded shield (`ic-resolve`) — outline shield with a filled rune. The old plain
  outline shield (`ic-armor`) is deleted from the mockup.
- Appears as a stat on: Character sheet, Trainer (trainable, 10 silver), Talents (the
  `Bulwark` node, reworded to "Steadies you against stuns, bleeds and poisons"), item
  tooltips, Rankings rows, Arena opponent stats.
- **It is not a status effect** and must not appear in the combat effect row.

Godot touch points (confirmed unless noted):
- `scripts/resources/ItemResource.gd` → `@export var armor: int`
- `scripts/resources/QuestReward.gd` → `@export var armor_boost: int`
- `scripts/resources/QuestOption.gd` → `RequirementType.ARMOR`, `RewardType.ARMOR`
- `scripts/Quest.gd` → `STAT_REWARD_MAP` maps `ARMOR` → property `armor`, display name `"armor"`
- Player stat field, stat refresh, character sheet, trainer, rankings, arena **[verify]**
- Server payload field naming and any balance tied to armor **[verify — likely a server change too]**

### 2.2 Combat status effects are one turn, always

No durations, no stack counts anywhere in the UI.

- Effect chips are **icon only** — presence is the entire state. Hover gives name + description.
- An effect applied on one turn is simply absent the next.
- Chips per fighter: **bleed, poison, stun** (three). Inactive chips leave the layout
  entirely so lit ones stay centred under their fighter.

### 2.3 Stun is a first-class event

- Shown twice: as a chip, **and** as a badge above the stunned fighter's portrait
  ("Stunned" + dazed stars), with the portrait desaturated.
- A stunned fighter **loses their turn** — a dedicated step with no swing and a
  "Turn lost" float.
- Has its own sound (`combat-stun`).

### 2.4 Resolve resists, visibly

When Resolve turns an effect aside: the hit still lands, the rider does not, and a green
"Resisted" float plus `combat-resist` chime fire. The mockup demonstrates both outcomes —
the same stun resisted by a Resolve-carrying fighter and landing on one without.

### 2.5 End-of-turn ticks

Bleed and poison deal explicit end-of-turn damage: coloured float, `combat-tick` sound, and
a second HP settle after the attack's own settle.

### 2.6 Combat pacing

Per-step delay is derived from what the step must communicate, not a flat interval:

| Step kind | Delay |
| --- | --- |
| plain exchange | 1450 ms |
| lost turn (stun) | 1700 ms |
| effect applied or resisted | 1750 ms |
| step with an end-of-turn tick | 2000 ms |
| opening beat after intro ceremony | 1050 ms |

> **Important Godot note.** The mockup authors its own fixed combat script. Godot's
> `scripts/CombatPanel.gd` plays back a **server-driven log** (`entry.action` ∈ `attack`,
> `crit`, `counterattack`, `damage`, `dodge`, `heal`, `bleed`, plus a generic fallback that
> currently covers *"stun, buff, etc."* with only a 0.3s pause). The real work is **mapping
> server log entries onto this new visual vocabulary** — especially promoting `stun` out of
> the generic fallback into a real event, and adding `resist` and per-turn effect state to
> whatever the server sends. Confirm the server log format before building the UI.

### 2.7 Quest: an option grants an effect **or** a reward, never both

Previously an applied effect rode along with the reward in one combined line. They are now
mutually exclusive, both narratively and in the UI.

- `scripts/Quest.gd` → `apply_option_reward()` currently builds a single `reward_text`
  string from all reward fields; `effect_applied` is a separate field on `QuestOption`.
  These need splitting so a step surfaces exactly one award.
- The reward row holds **exactly one award card** per step, or none for pure-dialogue steps.

### 2.8 Quest award presentation

One card: icon tile + kind label + name, with a description line **only where it earns one**.

| Kind | Icon | Shows description? |
| --- | --- | --- |
| Effect applied | effect glyph, warning tone | yes |
| Blessing | `ic-bless` | yes |
| Perk | `ic-perk` | yes |
| Item | real item art | no — name only |
| Silver / currency | `ic-silver` | no — amount only |

Applied effects render in the **warning tone** (red icon + name); rewards use the accent.
"Something happened *to* you" must not look like "you gained something".

**The award row must be content-sized, not a fixed height.** Descriptions run to two or three
lines and a fixed track clips them. In the mockup the quest body is a three-row grid —
`minmax(0, 1fr)` narration / `auto` award row / fixed options area — so the row grows with its
card, the narration absorbs the difference (it can shrink and scroll), and the option buttons
never move. Reproduce that behaviour in Godot with container sizing rather than a fixed
`custom_minimum_size`: narration expands/shrinks, award row hugs content, options stay pinned.

---

## Part 3 — Panel specs

23 panels. Pre-game panels (Login, Lobby, Create Char, Avatar) have no top bar and no dock.

### Login
Brand mark, **Login / Register** mode toggle, auth-method choice (email vs social provider),
email + password (+ confirm password in Register), password visibility toggle, Remember me,
Forgot password, status line, and a guarded loading state on submit ("Enter Wilds") that
disables the form while in flight. Social path shows an explanatory message instead of fields.

### Lobby
Title, mushroom balance, server header (`Server N`, `Day N`), character cards
(avatar + name + meta), create-character action, connection state in the footer.

### Create Char
Portrait preview with randomize control, name field, faction grid (3 factions) with a
description that updates on selection, patron row with a toggle and description, validation
status line, and a submit that stays disabled until the form is valid.

### Avatar
Two-part flow: a picker (tabbed library of choices, some **locked with a mushroom price**,
live preview, currency shown in the header) and a customiser (category tabs + colour swatch
grid, Back / Next). Locked-vs-owned is the state to get right.

### Home (settlement)
Scene art with a one-time world intro (title + flavour line, fades permanently after first
arrival). Bottom panel: a **row of four icon destinations** — Vendor, Healer, Blacksmith,
Alchemist (icon above label, no button chrome) — and a quest row with a green left accent
bar, compass icon, truncating quest name, `N of M` progress, and a cycle arrow that shuffles
the day's available quests.

### Expedition (map)
Nodes on an oversized **620 × 930 world canvas**; the phone is a crop window that pans over
it (animated camera recentre), and the artwork never zooms — a node stays attached to its
landmark at any screen size.

- **No connecting lines between nodes.** Each marker is a place, not a flowchart node.
- Each node: icon in a circle + name label beneath. Icons are per-node-theme
  (`ic-camp`, `ic-baths`, `ic-vents`, `ic-shrine`, `ic-ridge`, `ic-sump`).
- Completed / start nodes carry a **checkmark badge only** — no colour fill, no "new" dots.
- Only start, completed, and neighbours-of-completed render at all; the rest is fog.
- A bottom POI strip shows the selected node's name + description with an **Embark** action.

### Travel
Shares the Expedition map canvas. Bottom strip: quest name, flavour text, and a row with a
**filled progress bar carrying the countdown inside it** plus a Skip action priced in
mushrooms. Both controls are fully opaque; the panel behind them has no gradient because no
text sits on bare art here.

### Quest
Full-screen modal over scene art (dock hidden, top bar kept). Text centred, sitting well
down from the top. Reward row (see §2.7–2.8). Options pinned to the bottom, each with an
icon for its type — dialogue, combat, stat check, currency check, faction check, end-quest —
mirroring `Quest.gd`'s `add_option()` icon selection.

The mockup quest is a 7-step branching demo covering every award kind: a dialogue fork with
no award, an applied effect (Sulfur-sick), an item (Worn Longsword, real art), silver,
a blessing (Rejuvenation), and a perk (Second Wind).

### Vendor
NPC speech bubble, a shelf grid of purchasable items each showing its silver price, and the
shared bag row. Hover tooltips give full item detail.

### Healer
Row list, not buttons. Each row: icon, title, sub-line, price, chevron. Rows are uniform —
same structure whether the action is currently useful or not (Heal shows its price even at
full health, with the state in the sub-line).

### Blacksmith (Temper)
Item slot (equipment only) + name/level on one line, **stat comparison grid spanning the
full panel width** below it (2 columns, current → next with deltas), action rail on the right.

- Empty state: dashed slot, prompt copy, **no action button at all**.
- Temper level is shown as **pips (max 3)** — current lit, the one the action would buy
  shown as a "next" preview, remainder dim. No roman numerals.
- Panel height is fixed across empty/filled so nothing reflows when an item is placed.

### Alchemist
Two ingredient slots, each with placeholder copy ("Select an ingredient from your bag"),
resolving to name + description once filled. Brew on the shared action rail (10 silver).

### Enchanter
Item slot + equipment-category row, then a list of enchant offers — **Warded Mind** (reduces
chance to be stunned), **Clear Sight** (attack accuracy), **Steady Hand** (crit chance) —
with the selected offer's copy shown in a fixed description area. Enchant on the action rail
(12 silver). Note the offers are written against the new effect vocabulary.

### Trainer
One row per trainable: **Talent point** (100 silver) then Strength, Stamina, Agility, Luck,
**Resolve** (10 silver each). Each row shows current → next and its cost. Not a bag panel.

### Church
Blessing list with icon + name + effect per option, single selection, Bless on the action
rail (10 silver). Current blessings: Pilgrim's Step (−10% expedition travel time), Quiet
Resolve (−8% damage below half health), Gentle Fortune (+5% expedition silver), Bloodied
Zeal (+10% damage vs bleeding targets).

### Character
Name + faction line, the five stats (Strength, Stamina, Agility, Luck, **Resolve**), active
effect icons (hover for detail), equipment grid with the portrait cell doubling as a
Talents link, and the bag row. Full drag/drop and click-to-place between equip slots and bag,
with legality checks.

### Talents
Grid of nodes (10 rows). Each node: availability diamond, stat icon, and **pip bar** for
rank. States: locked / ready / maxed, plus dedicated perk-slot nodes that route to Perks and
can show a bound perk. Bottom bar merges the available-points readout and the reset control
(reset costs **silver**) into one row. Tapping a node opens an upgrade popup (name, level,
description with current→next, Upgrade button shown only when eligible).

### Perks
List of perks, each with glyph, name, description, and explicit **+ upside / − downside**
lines. Includes an "Empty slot — leave this perk slot unused" option. Slot header, selection
state, and a bind action with a silver cost. Perk copy references the new vocabulary
(stun, bleeding, resolve).

### Rankings
Header with the title and a single **Honor** column label (not repeated per row). Rows:
position, name, honor value, plus faction and stat data used by the detail panel. The bottom
self/detail panel shows the selected player's avatar, faction, name and stats, and carries a
**Fight** button targeting whoever is selected.

### Arena
Opponent name + rank centred with browse arrows flanking the avatar, an icon stat row, a
2×5 grid of circular buff/debuff badges (green-bordered buffs, red-bordered debuffs, one
numeric stack badge), pagination dots directly above a standalone **Fight** button. A soft
dark vignette — not a bordered box — keeps name and stats legible over any background art.

### Combat
Two fighters (portrait, name, HP bar with value inside), opening ceremony with a VS mark,
per-fighter effect chip row, stun badge over the portrait, an FX layer (slash + floating
numbers), a rolling three-line log, and Skip → Continue on completion. See **Part 2** for the
mechanics — this panel carries most of the rule changes.

### Settings
Grouped cards: **Gameplay** (disable ads, skip combat animations, language), **Audio**
(master + music volume, each as label + live percentage above an icon + full-width slider,
speaker icon vs music-note icon), **Interface** (UI size as a Small/Medium/Large segmented
control). Language opens a real dropdown anchored to its row — it does not cycle on tap.

### Payment
Mushroom tier cards (icon over count over price, no "best value" highlight), an
**Invite a friend** card with icon and right-aligned Share / Copy actions, and a
**Redeem a code** row that opens a centred popup (close button, input, full-width Redeem
button below the input).

---

## Part 4 — Refactor checklist

Ordered so shared work lands before the panels that depend on it. Tick per slice, not per file.

### Stage 0 — Decisions before any code
- [ ] Confirm **Resolve** replaces Armor server-side too (field names, balance), not just in the client.
- [ ] Confirm the **combat log payload** can express: per-turn effect state, stun-skips-turn, resist outcomes, end-of-turn ticks. Extend the server format if not.
- [ ] Confirm quest options can express **effect-applied XOR reward** and that content is authored that way.
- [ ] Decide whether one-turn-only effects is a **balance change** that needs server enforcement, not just UI.

### Stage 1 — Shared shell
- [ ] Theme tokens (§1.1) as theme resources.
- [ ] Top bar: currency + labels, settings, no button chrome; absent pre-game.
- [ ] Dock: two rows, Back in its own zone; Quest hides dock but keeps top bar.
- [ ] Opaque `--panel-surface` bottom panel + the blurred blend band.
- [ ] Verify at 405 × 900 **and** 390 × 800.

### Stage 2 — Shared controls
- [ ] One button language (border/radius/hover) applied everywhere; slots use the quieter token.
- [ ] Action rail: enabled / disabled / busy / max / hidden-when-impossible.
- [ ] Utility-room geometry: 240px panel, 126px content band, shared bag shelf coordinates.
- [ ] Item tooltip on hover, shared across panels.
- [ ] `playUiSound` equivalent with the kind list in §1.7 and the same routing.
- [ ] `prefers-reduced-motion` equivalent respected.

### Stage 3 — Armor → Resolve
- [ ] Rename stat and change its meaning to a resist stat (§2.1).
- [ ] `ItemResource.armor`, `QuestReward.armor_boost`, `QuestOption.RequirementType.ARMOR`, `RewardType.ARMOR`, `Quest.gd` `STAT_REWARD_MAP`.
- [ ] Player stat field + stat refresh + character sheet + trainer + rankings + arena.
- [ ] Swap the icon to the warded shield; delete the old armor glyph.
- [ ] Ensure Resolve never appears as a combat status effect.

### Stage 4 — Inventory
- [ ] Shared bag model across every panel that shows a bag.
- [ ] Drag/drop **and** click-select-then-place, both paths.
- [ ] `data-accepts` equivalent; incompatible drop is a silent no-op.
- [ ] Character equip↔bag legality checks.

### Stage 5 — Combat
- [ ] Map server log entries → new visual vocabulary; promote `stun` out of the generic fallback.
- [ ] Effect chips: icon-only, three kinds, no durations/counts, inactive collapse out of layout.
- [ ] Stun badge over portrait + desaturated portrait + lost-turn step.
- [ ] Resist outcome (hit lands, rider does not) with float + sound.
- [ ] End-of-turn bleed/poison ticks with float, sound and second HP settle.
- [ ] Pacing table from §2.6.
- [ ] Opening ceremony, VS mark, rolling 3-line log, Skip → Continue.

### Stage 6 — Quest
- [ ] Split `apply_option_reward()` so a step yields **one** award (effect XOR reward).
- [ ] Award card: icon + kind + name, description only for effect/blessing/perk.
- [ ] Award row **hugs its content** (2–3 line descriptions must not clip); narration absorbs the difference; option buttons stay pinned.
- [ ] Warning tone for applied effects vs accent for rewards.
- [ ] Full-screen modal: dock hidden, top bar kept, text centred and lowered.
- [ ] Option type icons wired to the existing `add_option()` selection logic.

### Stage 7 — Utility rooms (one template, then migrate)
- [ ] Template from the shared geometry + action rail.
- [ ] Healer (row list) · Blacksmith (temper, pips, fixed height, hidden button when empty) · Alchemist · Enchanter · Trainer · Church · Vendor.

### Stage 8 — Map screens
- [ ] Expedition world-canvas crop + camera pan; no connecting lines; icon nodes with labels; checkmark-only completion; fog for unreached.
- [ ] Travel reuses the canvas; countdown inside the progress bar; opaque controls; mushroom Skip.

### Stage 9 — Remaining screens
- [ ] Home (icon destination row, quest row with accent bar, one-time intro).
- [ ] Character · Talents (pips, merged bottom bar, upgrade popup) · Perks (±  lines, empty slot) · Rankings (single Honor label, Fight targets selection) · Arena.
- [ ] Settings (grouped cards, real language dropdown, segmented UI size, volume percentages).
- [ ] Payment (tier cards, invite card, redeem popup).
- [ ] Login · Lobby · Create Char · Avatar (no shell; locked/owned states in Avatar).

### Per-panel exit criteria
Use `CODEX_HANDOFF.md`'s definition of done, plus:
- [ ] No durations or stack counts leaked into any effect UI.
- [ ] No "Armor" strings or old shield glyph remaining.
- [ ] Action button is *absent*, not merely disabled, where the action is impossible.
- [ ] Panel height does not reflow between empty and filled states.
