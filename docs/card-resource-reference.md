# Card Resource Reference

How to create and configure card `.tres` resources, plus a complete catalog of implemented effects and existing cards.

---

## 1. Resource Type Hierarchy

```
Resource
├── CardData              (scripts/resources/card_data.gd)
│   ├── card_name: String
│   ├── type: Enums.CardTypeEnum
│   ├── mana_cost: int
│   └── effects: Array[EffectData]
│
├── MarbleData extends CardData   (scripts/resources/marble_data.gd)
│   └── physics: PhysicsObjectData
│
├── PhysicsObjectData      (scripts/resources/physics_object_data.gd)
│   ├── friction: float          (1.0 default)
│   ├── stickiness: float        (0.0 default, unused — deferred)
│   ├── gravity_modifier: float  (1.0 default)
│   ├── elasticity: float        (0.5 default)
│   └── weight: float            (1.0 default)
│
└── EffectData             (scripts/resources/effect_data.gd)
	├── effect_id: String
	├── value: float
	├── target: Enums.TargetEnum
	└── trigger: Enums.TriggerEnum
```

All enums live in `autoloads/enums.gd` (autoloaded as `Enums`).

---

## 2. Creating a New `.tres` Card Resource

### Step-by-Step

1. **Pick the base script.** Use `CardData` for non-marble cards (tricks, power-ups, terrain, AOE). Use `MarbleData` for marbles that appear on the field — it extends `CardData` with a `physics` sub-resource.

2. **Determine `load_steps`.** Count the number of `[ext_resource]` entries + `[sub_resource]` entries + the main resource. For a marble with one effect:
   - `ext_resource`: MarbleData script + PhysicsObjectData script + EffectData script = **3**
   - `sub_resource`: physics block + effect block = **2**
   - Main `[resource]` = **1**
   - Total: **6**... wait, `load_steps` is the number of Resource objects being loaded, which is ext_resources + sub_resources + main resource. The existing `marble_standard.tres` (with 0 effects) has `load_steps=3` (2 ext_resources + 1 sub_resource). The main `[resource]` is counted too? Let me check: marble_standard has 2 ext, 1 sub, 1 resource = 4, but load_steps says 3. So the main resource is NOT counted in load_steps. `load_steps = ext_resources + sub_resources`.

   Actually, looking at Godot's documentation, `load_steps` includes ext_resources and sub_resources but not the main resource. So:
   - marble_standard.tres: load_steps=3 (1_marble, 2_phys, phys_1) ✓
   - New effect marble: load_steps=5 (1_marble, 2_phys, 3_efx, phys_1, efx_1) ✓

3. **Write the `[ext_resource]` headers.** Each script the resource depends on:
   ```ini
   [ext_resource type="Script" path="res://scripts/resources/marble_data.gd" id="1_marble"]
   [ext_resource type="Script" path="res://scripts/resources/physics_object_data.gd" id="2_phys"]
   [ext_resource type="Script" path="res://scripts/resources/effect_data.gd" id="3_efx"]
   ```

4. **Write the physics `[sub_resource]`** (marble cards only):
   ```ini
   [sub_resource type="Resource" id="phys_1"]
   script = ExtResource("2_phys")
   friction = 1.0
   stickiness = 0.0
   gravity_modifier = 1.0
   elasticity = 0.5
   weight = 1.0
   ```

5. **Write the effect `[sub_resource]`** (one per effect):
   ```ini
   [sub_resource type="Resource" id="efx_1"]
   script = ExtResource("3_efx")
   effect_id = "deal_damage"
   value = 15.0
   target = 4
   trigger = 1
   ```
   Multiple effects need one `[sub_resource]` block each with unique `id` values.

6. **Write the `[resource]` block:**
   ```ini
   [resource]
   script = ExtResource("1_marble")
   card_name = "My Marble"
   type = 0
   mana_cost = 1
   effects = Array[ExtResource("3_efx")]([SubResource("efx_1")])
   physics = SubResource("phys_1")
   ```
   For non-marble cards, omit the `physics` line and use `script = ExtResource("1")` pointing to `card_data.gd`.

### Enum Values for `.tres` Files

| Enum | Field | Values |
|---|---|---|
| `CardTypeEnum` | `type` | MARBLE=0, POWER_UP=1, TRICK=2, TERRAIN=3, AREA_OF_EFFECT=4 |
| `TriggerEnum` | `trigger` | PLAY=0, SIMULATION=1 |
| `TargetEnum` | `target` | SELF=0, OPPONENT=1, CURR_MARBLE=2, KNOCKER=3, KNOCKER_OPP=4, BOTH=5, FIELD_MAP=6, FIELD_MARBLES=7 |

---

## 3. Effect Reference

All effects are dispatched by `scripts/managers/effect_handler.gd` (autoloaded). It uses a `Callable` dictionary registry keyed by `effect_id` — no hardcoded logic on cards.

### 3.1 Effect Dispatch Pipeline

```
Card played (PLAY) or marble knocked out (SIMULATION)
  → EffectHandler.dispatch_play_effects() / dispatch_simulation_effects()
  → Filter effects by trigger enum
  → Resolve targets (player IDs, field nodes, etc.)
  → Apply multiplier (SIMULATION only, via effect.duplicate())
  → Call registered handler via _registry[effect_id]
```

### 3.2 All Implemented Effects

| # | effect_id | Category | What It Does | Valid Targets | Valid Triggers |
|---|---|---|---|---|---|
| 1 | `deal_damage` | Player stat | Subtracts `value` (int) from `MatchManager.player_health[pid]`, clamped to 0. | SELF, OPPONENT, BOTH (PLAY) / KNOCKER, KNOCKER_OPP, BOTH (SIM) | PLAY, SIMULATION |
| 2 | `heal` | Player stat | Adds `value` (int) to `MatchManager.player_health[pid]`, clamped to `character.health` (max HP). | Same as deal_damage | PLAY, SIMULATION |
| 3 | `drain_mana` | Player stat | Subtracts `value` (int) from `MatchManager.player_mana[pid]`, clamped to 0. | Same as deal_damage | PLAY, SIMULATION |
| 4 | `restore_mana` | Player stat | Adds `value` (int) to `MatchManager.player_mana[pid]`, clamped to `character.mana * 2` (max mana). | Same as deal_damage | PLAY, SIMULATION |
| 5 | `set_linear_damp` | Field physics | Sets terrain delta on `FieldStateManager` for key `"linear_damp"`. Affects marble friction additively: `Effective = map_base + terrain_delta + sum(aoe_deltas)`. | FIELD_MAP | PLAY |
| 6 | `set_gravity` | Field physics | Sets terrain delta on `FieldStateManager` for key `"gravity_magnitude"`. Affects gravity strength additively. | FIELD_MAP | PLAY |
| 7 | `apply_aoe` | Field physics | Applies an AOE delta `{"linear_damp": value}` with a **2-turn duration**. Auto-expires via `FieldStateManager.tick_aoe_durations()` at end-turn. Stacks with other AOE layers. | FIELD_MAP | PLAY |
| 8 | `clear_terrain` | Field physics | Clears **both** `"linear_damp"` and `"gravity_magnitude"` terrain deltas. Does not affect AOE or map-base layers. `value` is ignored. | FIELD_MAP | PLAY |

### 3.3 Multiplier System (SIMULATION Only)

On marble knockout, the active threshold multiplier is applied. Multiplier is computed from `MatchManager.knockouts_this_turn`:

| Knockouts This Turn | Multiplier |
|---|---|
| 0–2 | 1.0× |
| 3–4 | 1.5× |
| 5–6 | 2.0× |
| 7+ | 3.0× |

The multiplier scales `effect.value` via `effect.duplicate()` before calling the handler — original resources are never mutated.

### 3.4 Target Routing

#### PLAY Context (`dispatch_play_effects`)

| Target | Resolves To |
|---|---|
| SELF | `[active_player_id]` |
| OPPONENT | `[opponent_player_id]` |
| CURR_MARBLE | `[current_marble]` (MarbleData, if present) |
| BOTH | `[active_player_id, opponent_player_id]` |
| FIELD_MAP | `[FieldStateManager]` singleton |
| FIELD_MARBLES | All nodes in group `"field_marbles"` |

#### SIMULATION Context (`dispatch_simulation_effects`)

| Target | Resolves To |
|---|---|
| KNOCKER | `[knocker_player_id]` (the active shooter) |
| KNOCKER_OPP | `[knocker_opp_player_id]` (shooter's opponent) |
| BOTH | `[knocker_player_id, knocker_opp_player_id]` |
| FIELD_MAP | `[FieldStateManager]` singleton |
| FIELD_MARBLES | All nodes in group `"field_marbles"` |

Targets not valid in a given context (e.g., `KNOCKER` during PLAY) produce a warning and return an empty array — the effect is silently skipped.

---

## 4. Existing Card Catalog

### 4.1 Marble Cards (`type=0`)

Marbles use `MarbleData` (extends `CardData` with `PhysicsObjectData`).

| File | Card Name | Cost | Weight | Friction | Elasticity | Effect | Notes |
|---|---|---|---|---|---|---|---|
| `marble_normal.tres` | Cat's Eye | 0 | 1.0 | 1.0 | 0.5 | — | Baseline marble |
| `marble_heavy.tres` | Chrome Ball | 0 | 2.0 | 1.2 | 0.2 | — | Harder to knock out, slower shooter |
| `marble_light.tres` | Ping Pong Ball | 0 | 0.4 | 0.3 | 0.7 | — | Very light, moderate bounce |
| `marble_sticky.tres` | Gumball | 0 | 1.2 | 1.8 | 0.05 | — | Extreme friction, stops dead on impact |
| `marble_soft.tres` | Orbeez | 0 | 0.6 | 0.8 | 0.02 | — | Near-zero bounce, absorbs all impact |
| `marble_bouncy.tres` | Jackstone | 0 | 0.7 | 0.3 | 0.9 | — | Fast, extreme elasticity, wild ricochets |
| `marble_double_damage.tres` | 8 Pool Ball | 1 | 2.0 | 1.5 | 0.2 | deal_damage 15 to KNOCKER_OPP on SIM | Damages shooter's opponent on knockout |
| `marble_heal_ball.tres` | Rambutan | 1 | 1.8 | 1.4 | 0.25 | heal 10 to KNOCKER on SIM | Heals shooter on knockout |
| `marble_siphon.tres` | Marble Siphon | 1 | 1.8 | 1.4 | 0.2 | drain_mana 2 to KNOCKER_OPP on SIM | Drains shooter's opponent mana on knockout |
| `marble_energy_regen.tres` | Dragon Ball | 1 | 1.8 | 1.3 | 0.25 | restore_mana 2 to KNOCKER on SIM | Restores shooter mana on knockout |
| `marble_high_damage.tres` | Hello Kitty Marble | 2 | 2.2 | 1.6 | 0.15 | deal_damage 30 to KNOCKER_OPP on SIM | Heavy hitter; high knockout penalty |

### 4.2 Power-Up Cards (`type=1`)

Power-ups use `CardData`. PLAY trigger, SELF target — provide advantage to the casting player.

| File | Card Name | Cost | Effect | Notes |
|---|---|---|---|---|
| `buff_instant_heal.tres` | Miks Vaporub | 2 | heal 15 to SELF on PLAY | Instant health recovery |
| `buff_energy_regen.tres` | Mylo | 1 | restore_mana 2 to SELF on PLAY | Light energy regen |
| `buff_energy_regen_plus.tres` | Peak Dew | 2 | restore_mana 4 to SELF on PLAY | Strong energy regen |

### 4.3 Trick Cards (`type=2`)

Tricks use `CardData`. PLAY trigger, outward-targeted effects.

| File | Card Name | Cost | Effect | Notes |
|---|---|---|---|---|
| `trick_remove_terrain.tres` | Asian Nanay | 2 | clear_terrain to FIELD_MAP on PLAY | Clears all active field modifiers |
| `trick_energy_drain.tres` | Datu Aslum | 1 | drain_mana 2 to OPPONENT on PLAY | Drains opponent's mana |
| `trick_jamming_session.tres` | Jamming Session | 3 | restore_mana 3 to BOTH on PLAY | Restores mana to both players |

### 4.4 Terrain Cards (`type=3`)

Terrain cards use `CardData`. PLAY trigger, FIELD_MAP target. Only one terrain active at a time — terrain deltas overwrite each other.

| File | Card Name | Cost | Effect | Notes |
|---|---|---|---|---|
| `terrain_wind.tres` | Electric Fan | 2 | set_gravity -0.3 to FIELD_MAP on PLAY | Upward wind; marbles fall slowly |
| `terrain_hose.tres` | Turning on the Hose | 2 | set_linear_damp 0.6 to FIELD_MAP on PLAY | Wet ground; increased friction |

### 4.5 Area-of-Effect Cards (`type=4`)

AoE cards use `CardData`. PLAY trigger, FIELD_MAP target. Apply temporary physics deltas that stack additively and auto-expire after 2 turns.

| File | Card Name | Cost | Effect | Notes |
|---|---|---|---|---|
| `aoe_sticky_zone.tres` | Elemar's Glue | 2 | apply_aoe 0.8 to FIELD_MAP on PLAY | High-friction zone, 2-turn duration |
| `aoe_oil.tres` | Oil | 2 | apply_aoe -0.4 to FIELD_MAP on PLAY | Low-friction slick, 2-turn duration |

### 4.6 Archived Sample Cards

The following sample cards are archived at `resources/cards/archive/`. They are **not** in active rotation:

| File | Card Name | Type |
|---|---|---|
| `powerup_accuracy.tres` | Accuracy | Power-Up |
| `powerup_boost.tres` | Power Boost | Power-Up |
| `trick_swap.tres` | Swap | Trick |
| `terrain_ice.tres` | Ice Terrain | Terrain |
| `terrain_honey.tres` | Honey Terrain | Terrain |
| `aoe_sticky_zone.tres` | Sticky Zone | AoE |
| `aoe_gravity_well.tres` | Gravity Well | AoE |

---

## 5. Mana System

| Parameter | Value |
|---|---|
| Starting mana | `character.mana` (3 for Default, 4 for Aggressive) |
| Max mana (ceiling) | `character.mana * 2` (6 for Default, 8 for Aggressive) |
| Mana regen | `+character.mana` at end of own turn |
| Min mana | 0 (clamped) |
| Regen timing | `_on_end_turn_entered()` in `match_fsm.gd` |

Key functions in `autoloads/match_manager.gd`:
- `regenerate_mana(player_id)` — adds `character.mana` capped at `character.mana * 2`
- `spend_mana(player_id, amount)` — subtracts `amount`, returns `false` if insufficient

---

## 6. Adding a New Effect (Checklist)

When adding a wholly new `effect_id` (not just a new card using existing effects):

1. Add the handler method to `scripts/managers/effect_handler.gd` (follow `_efx_*` naming convention)
2. Register it in `_ready()`: `_registry["new_effect_id"] = _efx_new_effect`
3. If the effect needs new targets, add them to `TargetEnum` in `autoloads/enums.gd` and update both `_resolve_play_target()` and `_resolve_simulation_target()`
4. Create the card `.tres` resource following the format in Section 2
5. Add the card to `default_private_paths` or `default_public_paths` in `scripts/ui/deck_builder.gd` for auto-fill availability

---

## 7. Design Conventions

- **No card hardcoding.** Cards carry `Array[EffectData]` — all logic lives in `EffectHandler`.
- **Stateless handlers.** Effect methods read/write `MatchManager` dictionaries; they don't store state themselves.
- **Immutability.** SIMULATION dispatch uses `effect.duplicate()` before scaling values — original resources on disk are never mutated.
- **Trigger filtering.** Effects with mismatched triggers are silently skipped. A card can mix PLAY and SIMULATION effects.
- **Target validation.** Invalid targets for a given context produce a warning and skip execution — they don't crash.
- **Physics balancing.** Effect marbles should have higher weight and lower elasticity than standard marbles to offset their utility (see `docs/field-physics-reference.md` for tuning ranges).
