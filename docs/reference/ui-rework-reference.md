# UI Rework Reference

How the card and marble rendering system is built — layered, asset-driven visuals with node-based architecture editable in the Godot editor.

---

## Asset Integration Guide for Artists

This section is the quick-start for creating and dropping in visual assets. The game uses **procedural fallbacks** everywhere — you'll see placeholder textures until real assets land, and the game runs fine either way.

### Directory Structure

```
res://assets/sprites/
├── marbles/            # Marble sprites — auto-loaded by card_name
├── cards/              # Card sprite textures (auto-loaded, type-separated)
│   ├── marbles/        # Marble card-in-hand sprites
│   ├── power_ups/      # Buff card sprites
│   ├── tricks/         # Trick card sprites
│   ├── terrain/        # Terrain card sprites
│   └── aoe/            # AoE card sprites
├── frames/             # Per-card-type frame textures
└── ui/                 # Other UI textures
    └── card_back.png   # Shared card-back texture
```

### 1. Marble Sprites (auto-loaded, ready now)

Marbles **automatically** load a PNG based on the card name. No code changes needed — just drop files into the right folder.

| Property | Value |
|---|---|
| **Directory** | `res://assets/sprites/marbles/` |
| **Format** | PNG, RGBA8 (transparency supported) |
| **Display size** | ~34×34 px (renders inside a 15px-radius RigidBody2D; sprite can be larger and will scale down) |
| **Recommended** | 64×64 px for crisp rendering at 2x |
| **Fallback** | Procedural circle in neutral light-gray (`Color(0.82, 0.82, 0.85)`) with darker outline |

**Filenames** — use exactly these names (snake_case derived from card name):

| Card Name | Filename |
|---|---|
| Cat's Eye | `cat_s_eye.png` |
| Chrome Ball | `chrome_ball.png` |
| Ping Pong Ball | `ping_pong_ball.png` |
| Gumball | `gumball.png` |
| Orbeez | `orbeez.png` |
| Jackstone | `jackstone.png` |
| 8 Pool Ball | `8_pool_ball.png` |
| Rambutan | `rambutan.png` |
| Marble Siphon | `marble_siphon.png` |
| Dragon Ball | `dragon_ball.png` |
| Hello Kitty Marble | `hello_kitty_marble.png` |

**How it works:** `Marble.setup()` builds the path `res://assets/sprites/marbles/{card_name.to_snake_case()}.png`, checks if it exists, loads it, and assigns it to the `%Sprite` node. If the file doesn't exist, the procedural circle fallback renders instead. You can add files incrementally — each marble type falls back independently.

**Color note:** Marbles are public (shared deck). They do NOT show team/owner colors. Visual identity comes entirely from the sprite asset, not from player ID.

### 2. Card Frame Textures (needs code wiring)

Card frames are 150×210 px textures with a **transparent rectangular hole** from (10,10) to (140,120). A card-type sprite renders through the hole.

| Property | Value |
|---|---|
| **Directory** | `res://assets/sprites/cards/frames/` |
| **Format** | PNG, RGBA8 |
| **Size** | 150×210 px |
| **Hole** | Transparent rectangle at pixel rect (10, 10, 130, 110) |
| **5 files needed** | One per card type (see below) |
| **Fallback** | Procedural solid fill + accent border, cached statically |

| Card Type | Recommended Frame Fill | Recommended Accent | Suggested Filename |
|---|---|---|---|
| Marble | Dark red-brown | Orange-red | `frame_marble.png` |
| Power-Up | Dark blue | Blue | `frame_power_up.png` |
| Trick | Dark green | Green | `frame_trick.png` |
| Terrain | Dark brown | Gold-brown | `frame_terrain.png` |
| AoE | Dark purple | Purple | `frame_aoe.png` |

**How it works today:** `CardVisualController._make_frame(type)` generates an `ImageTexture` procedurally (solid fill with transparent hole, 2px outer/inner accent borders). The result is cached per type.

**To wire up real assets:** In `card_visual_controller.gd`, change `_make_frame(type)` from procedural generation to `load("res://assets/sprites/cards/frames/frame_{type_name}.png")`. The static cache logic stays the same — just the texture source changes.

### 3. Card Sprite Textures (needs code wiring)

Each card has a 130×110 px sprite that fills the transparent hole in the frame.

| Property | Value |
|---|---|
| **Directory** | `res://assets/sprites/cards/{type_subdir}/` (see below) |
| **Format** | PNG, RGBA8 |
| **Size** | 130×110 px |
| **10 files needed** | One per non-marble card name (see below) |
| **Fallback** | Procedural gradient circle in the card type's accent color |

**Code wiring already done.** `CardVisualController._get_card_sprite(card_data)` builds the path `res://assets/sprites/cards/{type_subdir}/{card_name.to_snake_case()}.png`, loads it if it exists, and falls back to the procedural gradient circle. Just drop PNGs into the right directory.

**Filenames** — snake_case of card name, organized by type subdirectory:

**`cards/power_ups/`** (type=1):
| Card Name | Filename |
|---|---|
| Miks Vaporub | `miks_vaporub.png` |
| Mylo | `mylo.png` |
| Peak Dew | `peak_dew.png` |

**`cards/tricks/`** (type=2):
| Card Name | Filename |
|---|---|
| Asian Nanay | `asian_nanay.png` |
| Datu Aslum | `datu_aslum.png` |
| Jamming Session | `jamming_session.png` |

**`cards/terrain/`** (type=3):
| Card Name | Filename |
|---|---|
| Electric Fan | `electric_fan.png` |
| Turning on the Hose | `turning_on_the_hose.png` |

**`cards/aoe/`** (type=4):
| Card Name | Filename |
|---|---|
| Elemar's Glue | `elemar_s_glue.png` |
| Oil | `oil.png` |

**`cards/marbles/`** (type=0) — same filenames as Section 1 marble table above.

### 4. Card Back Texture (needs code wiring)

| Property | Value |
|---|---|
| **Path** | `res://assets/sprites/ui/card_back.png` |
| **Format** | PNG, RGBA8 |
| **Size** | 150×210 px |
| **Fallback** | Procedural dark-blue fill with centered diamond pattern |

**To wire up:** In `card_visual_controller.gd`, change `_get_back()` to `load("res://assets/sprites/ui/card_back.png")` with a fallback to the procedural `_make_back()`.

### 5. Getting Started Checklist

**Step 1 — Marbles (zero code changes):**
- [ ] Create `res://assets/sprites/marbles/` directory
- [ ] Draw and export 11 marble PNGs using the exact filenames from section 1
- [ ] Drop them in the folder
- [ ] Launch game — each marble type that has a PNG uses it; missing ones fall back to procedural circles

**Step 2 — Card backs (one code change):**
- [ ] Create `res://assets/sprites/ui/card_back.png` (150×210)
- [ ] Update `_get_back()` in `card_visual_controller.gd` to load from file with procedural fallback

**Step 3 — Card frames (one code change, 5 assets):**
- [ ] Create `res://assets/sprites/cards/frames/` directory
- [ ] Draw 5 frame PNGs (150×210, transparent hole) using filenames from section 2
- [ ] Update `_make_frame(type)` in `card_visual_controller.gd` to load from file with procedural fallback

**Step 4 — Card sprites (zero code changes, 10 assets):**
- [ ] Create `res://assets/sprites/cards/` subdirectories: `power_ups/`, `tricks/`, `terrain/`, `aoe/`, `marbles/`
- [ ] Draw 10 sprite PNGs (130×110) for non-marble cards using filenames from section 3
- [ ] Drop them in their type subdirectories — code wiring is already done via `_get_card_sprite()`

---

## Architecture Reference

### Card Visual Architecture

**File:** `scenes/ui/card_visual.tscn`

```
Card (Control, script=res://addons/card-framework/card.gd)
│   front_face_texture = NodePath("FrontFace/FrameRect")
│   back_face_texture  = NodePath("BackFace/BackRect")
│
├── FrontFace (Control, script=CardVisualController)
│   └── FrameRect (TextureRect, 150×210)          [unique: %FrameRect]
│       ├── SpriteRect (TextureRect, 130×110)     [unique: %SpriteRect]
│       ├── ManaCostLabel (Label, 44×22)          [unique: %ManaCostLabel]
│       ├── CardNameLabel (Label, 150×24)         [unique: %CardNameLabel]
│       └── CardDescLabel (Label, 126×54)         [unique: %CardDescLabel]
│
└── BackFace (Control)
    └── BackRect (TextureRect, 150×210)
```

**Why FrameRect is the parent:** Godot renders children on top of parents. The frame has a transparent hole. SpriteRect (child) fills the hole. Labels (children) render on top. When the Card base class toggles `front_face_texture.visible`, all children inherit visibility automatically.

### Marble Visual Architecture

```
Marble (RigidBody2D, script=marble.gd)
├── CollisionShape2D (CircleShape2D, radius=15)
└── Sprite (Sprite2D)          [unique: %Sprite]
```

Marble sprites are loaded by `marble.gd:setup()`:
1. Try: `res://assets/sprites/marbles/{card_name.to_snake_case()}.png`
2. Fallback: procedural `ImageTexture` circle with `MARBLE_COLOR` + darkened outline

### CardVisualController

**File:** `scripts/ui/card_visual_controller.gd`

Attached to `FrontFace`. Uses lazy node resolution (not `@onready`) because the factory calls `apply_card_data()` before the card enters the scene tree.

| Method | What It Does |
|---|---|
| `apply_card_data(card_data)` | Sets frame texture, sprite texture, and all three label texts + styles |
| `apply_back(back_rect)` | Sets the back-face texture on BackRect |
| `_make_frame(type)` | Procedural 150×210 frame — solid fill with transparent hole, 2px borders |
| `_make_sprite(type)` | Procedural 130×110 gradient circle in type accent color |
| `_make_back()` | Procedural 150×210 dark-blue with diamond pattern |

### Label Positioning (Relative to FrameRect 150×210)

| Label | Position | Size | Font | Color | Content |
|---|---|---|---|---|---|
| ManaCostLabel | (8, 4) | 44×22 | 16px | Cyan | `card_data.mana_cost` |
| CardNameLabel | (0, 125) | 150×24 | 12px | White | `card_data.card_name` |
| CardDescLabel | (12, 150) | 126×54 | 9px | Light gray | `card_data.description` |

All labels have 2px black outline for readability.

### CardData Schema

**File:** `scripts/resources/card_data.gd`

```gdscript
@export var card_name: String = ""
@export var type: Enums.CardTypeEnum = Enums.CardTypeEnum.TRICK
@export var mana_cost: int = 0
@export var description: String = ""
@export var effects: Array[EffectData] = []
```

### CardDataFactory Flow

**File:** `scripts/resources/card_data_factory.gd`

```
create_card_from_data()
  ├── instantiate card_visual.tscn
  ├── resolve front_face_texture / back_face_texture via get_node()  (before add_child)
  ├── set card_size → triggers _update_card_size()
  ├── apply_card_data() → textures + labels  (lazy-resolves % nodes)
  ├── apply_back()
  ├── add_child(card)  → _ready() fires
  └── add_card(card)
```

Face textures are explicitly resolved before `card_size` triggers the setter chain, avoiding the `@export` NodePath resolution timing issue.

### Key Constraints

- **Card Framework addon is read-only.** Never modify `addons/card-framework/`.
- **Card size is fixed at 150×210.** The Card class's `_update_card_size()` resizes `front_face_texture` and `back_face_texture` when `card_size` changes.
- **FrameRect must be the front_face_texture.** Visibility toggle in `card.gd` only hides/shows the assigned TextureRect nodes. All visual children must be descendants of these nodes.
- **Marble collision shape stays at radius 15.** Visual sprites can be larger — the physics body is always 15px.
- **No image assets exist yet.** All textures are procedurally generated. When real assets arrive, swap the generation methods — the node structure stays the same.
- **Marbles are owner-neutral.** No team-color tinting on field marbles. Visual identity comes from the sprite asset only.

---

## Related Files

| File | Role |
|---|---|
| `scenes/ui/card_visual.tscn` | Card template scene (node hierarchy) |
| `scripts/ui/card_visual_controller.gd` | Populates card visuals, generates placeholder textures |
| `scripts/resources/card_data.gd` | Card data resource (includes `description`) |
| `scripts/resources/card_data_factory.gd` | Factory — instantiates cards, wires controller, resolves face textures |
| `scenes/gameplay/marble.tscn` | Marble scene (RigidBody2D + Sprite2D) |
| `scripts/gameplay/marble.gd` | Marble script — physics setup + sprite loading with asset fallback |
| `scripts/gameplay/client_marble_visual.gd` | Client-side marble rendering |
| `addons/card-framework/card.gd` | Card base class — DO NOT MODIFY |
| `addons/card-framework/card_factory.gd` | Factory base class — DO NOT MODIFY |
| `docs/card-resource-reference.md` | Card `.tres` format and effect catalog |
