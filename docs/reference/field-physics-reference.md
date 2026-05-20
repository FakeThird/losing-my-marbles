# Field Physics Reference

Complete reference of all variables governing physics interactions inside the playing field. Use this to understand the current setup and tune for game balance.

---

## 1. Field Geometry

| Constant | Value | Source | Notes |
|---|---|---|---|
| `FIELD_CENTER` | (450, 250) | `field.gd:4` | Center of the circular field in world coordinates |
| `FIELD_RADIUS` | 220 px | `field.gd:3` | Radius of the visible playing field |
| `WALL_THICKNESS` | 12 px | `field.gd:5` | Thickness of the drawn boundary arc (visual only — no physical collider) |
| Visible field inner radius | 208 px | derived | `FIELD_RADIUS - WALL_THICKNESS` |
| `SHOOTER_SPAWN_DIST` | 241 px | `field.gd:10` | `FIELD_RADIUS + Marble.RADIUS + 6.0 = 220 + 15 + 6` — shooter marble center distance from field center (outside field) |
| Marble `RADIUS` | 15 px | `marble.gd:4` | Radius of every marble's `CircleShape2D` collider |

### Concentric Zones (all centered at FIELD_CENTER)

```
 FIELD_CENTER (450, 250)
     │
     │  radius 208 ─ visible inner edge of boundary arc
     │  radius 220 ─ outer edge of boundary arc (visual field edge) + BoundaryDetector Area2D (exit detection, aligned)
     │  radius 241 ─ shooter spawn position (outside field)
     │  radius 260 ─ GravityZone Area2D (space_override = REPLACE)
```

| Zone | Radius | Type | Purpose |
|---|---|---|---|
| Shooter spawn | 241 | Position | Where the shooter sample marble appears during AIM (outside field, with overlap detection) |
| Visual field + BoundaryDetector | 220 | `_draw()` arc + `Area2D` (monitoring) | Visual boundary and exit detection are aligned at same radius (D17). Tracks entries/exits; emits `marble_exited_boundary` on genuine exit |
| GravityZone | 260 | `Area2D` (REPLACE) | Overrides global gravity within this radius |
| Viewport walls | x=70/830, y=-80/580 | `StaticBody2D` rect | Off-screen walls; kill marble velocity on contact (`bounce=0`, zeros `linear_velocity` + `angular_velocity`) |

### Viewport Boundary Layout

```
          Top wall (y = -80)
    ┌─────────────────────────────────┐
    │                                 │
    │  FIELD_CENTER (450, 250)        │
    │     radius 220 (visual + detector) │
    │     radius 241 (shooter spawn)  │
    │                                 │
    │  Left wall       Right wall     │
    │  (x = 70)        (x = 830)      │
    │                                 │
    └─────────────────────────────────┘
         Bottom wall (y = 580)
```

### Marble Exit & Despawn Flow

1. Marble crosses `BoundaryDetector` (R=220, aligned with visual boundary) → `marble_exited_boundary` emitted, marble added to `_exited_marbles` array (preserves exit order for future effect resolution)
2. Marble continues until it hits a viewport wall or settles via `linear_damp`
3. Simulation completes (all remaining marbles below velocity threshold)
4. `_finish_simulation()` despawns all marbles in `_exited_marbles` via `queue_free()`, erases them from `final_state`
5. `SignalBus.simulation_complete` emitted → FSM transitions to PLAY
6. Effect handler (Phase 5) will process knockouts in exit order

---

## 2. Global Physics

| Setting | Value | Source | Notes |
|---|---|---|---|
| `2d/default_gravity` | 0 | `project.godot:34` | Zero global gravity — this is a top-down game |
| Physics ticks/sec | 60 (default) | Project Settings | Used for snapshot capture/replay interval |

---

## 3. Per-Marble Physics (PhysicsObjectData)

Each `.tres` marble resource carries a `PhysicsObjectData` sub-resource. These values are applied in `marble.gd:setup()`.

| Property | Applies to | Default | Standard | Heavy | Bouncy | Source |
|---|---|---|---|---|---|---|
| `friction` | `linear_damp` of marble | 1.0 | 1.0 | 1.2 | 0.3 | `physics_object_data.gd:4` |
| `stickiness` | (unused — deferred to Phase 5) | 0.0 | 0.0 | 0.0 | 0.0 | `physics_object_data.gd:5` |
| `gravity_modifier` | `gravity_scale` of marble | 1.0 | 1.0 | 1.2 | 0.8 | `physics_object_data.gd:6` |
| `elasticity` | `PhysicsMaterial.bounce` | 0.5 | 0.5 | 0.2 | 0.9 | `physics_object_data.gd:7` |
| `weight` | `mass` of `RigidBody2D` | 1.0 | 1.0 | 2.0 | 0.7 | `physics_object_data.gd:8` |

**Important:** Per-marble `linear_damp` is initially set from `friction`, but the `FieldStateManager` overrides it globally via `push_to_engine()` → `field.set_linear_damp()`. The per-marble value only matters during the gap between `spawn_marble()` and the next `recalculate()` call.

---

## 4. FieldStateManager Layer Stack

Governed by `autoloads/field_state_manager.gd`. Effective values are additive across three layers.

### Layer Defaults

| Key | Default | Type |
|---|---|---|
| `gravity_magnitude` | 0.0 | float |
| `gravity_direction` | `Vector2.ZERO` | Vector2 |
| `linear_damp` | 0.5 | float |

### Layer Composition

```
Effective Value = map_base[key] + terrain_delta[key] + sum(aoe_deltas[key])
```

| Layer | Mutator | Scope |
|---|---|---|
| `_map_base` | `apply_map_base(properties: Dictionary)` | Permanent field surface |
| `_terrain_delta` | `set_terrain_delta(key, value)`, `clear_terrain_delta(key)` | Active terrain card (one at a time) |
| `_aoe_deltas` | `add_aoe_delta(delta, turns_remaining)`, `remove_aoe_delta(idx)` | Stack of active AOE effects with duration |

### Push Mechanism

- `recalculate()` computes the effective layer sum, then calls `push_to_engine(effective)`.
- `push_to_engine()` finds the `"game_field"` group node and calls:
  - `field.set_gravity(direction, magnitude)` → updates `GravityZone` Area2D properties
  - `field.set_linear_damp(damp)` → iterates `"field_marbles"` group, sets `linear_damp` on each `RigidBody2D`
- `recalculate()` is called after every layer mutation — never per-tick.

---

## 5. Shot Execution

Governed by `scripts/ui/match.gd`. The flick slider, field rotation, and fine-tune controls produce the shot.

### Aim Input Constants

| Constant | Value | Source | Notes |
|---|---|---|---|
| `AIM_FLICK_MIN` | 0.0 | `match.gd:6` | Minimum flick slider value |
| `AIM_FLICK_MAX` | 10.0 | `match.gd:7` | Maximum flick slider value |
| `ROTATION_SPEED` | 120 °/sec | `match.gd:8` | Field rotation button hold speed |
| `FINE_TUNE_SPEED` | 60 °/sec | `match.gd:9` | Aim fine-tune button hold speed |
| `SHOT_IMPULSE_SCALE` | 80.0 | `match.gd:10` | Multiplier converting flick*power to physics impulse |

### Shot Formula

```
total_angle  = _rotation_value + _fine_tune_value          (degrees)
direction   = Vector2.LEFT.rotated(deg_to_rad(total_angle))  (unit vector)
impulse     = direction * _flick_value * character.power * SHOT_IMPULSE_SCALE
```

### Impulse → Velocity

In Godot physics, `apply_central_impulse(impulse)` adds `impulse / mass` to the marble's linear velocity.

```
velocity = impulse / marble.mass
         = direction * flick * power * 80 / weight
```

### Impulse Magnitude Table (mass = 1.0)

| Flick | Power 1.0 (Default) | Power 1.5 (Aggressive) |
|---|---|---|
| 1.0 | 80 px/s | 120 px/s |
| 3.0 | 240 px/s | 360 px/s |
| 5.0 | 400 px/s | 600 px/s |
| 7.0 | 560 px/s | 840 px/s |
| 10.0 | 800 px/s | 1200 px/s |

For Heavy marble (mass = 2.0), divide velocities by 2. For Bouncy (mass = 0.7), divide by 0.7.

### Character Power

| Character | Power | Effect at max flick |
|---|---|---|
| Default | 1.0 | Impulse multiplier = 1.0× (baseline) |
| Aggressive | 1.5 | Impulse multiplier = 1.5× (+50%) |

`character.power` is a **read-only stat**, never exposed as player input (D5). It is **multiplicative** with flick at execution time.

---

## 6. Trajectory Preview

Governed by `scripts/gameplay/trajectory_preview.gd`. The preview is analytical — it does not use physics raycasts.

| Constant | Value | Source | Notes |
|---|---|---|---|
| `THROTTLE_ROTATION_DELTA` | 0.5 ° | `trajectory_preview.gd:6` | Min rotation change to trigger recalculation (flick throttle removed) |
| `TRAJECTORY_EXTEND` | 2000 px | `trajectory_preview.gd:7` | How far the preview line extends if no hit |
| `GHOST_ALPHA` | 0.35 | `trajectory_preview.gd:9` | Opacity of ghost marble at predicted hit point |

### Hit Detection

- Uses analytical circle-ray intersection (quadratic solver).
- Combined hit radius = `Marble.RADIUS * 2.0` (marble-to-marble center distance on contact).
- Preview stops at first collision — no bounce prediction (proved inaccurate vs. physics simulation).
- Shooter-to-wall pass-through: wall does not participate in hit test.
- Preview origin: uses `field.get_shooter_position()` (outside field at 241px radius).
- Shooter spawn respects persisted rotation via `_current_rotation_degrees`; emission deferred until shooter exists.
- Single amber line from shooter to hit point (or fixed 2000px extension if no hit).

### Throttle

| Gate | Location | Condition |
|---|---|---|
| Emission | `match.gd:_emit_aim_if_changed()` | `abs(total_angle - last_emitted) > 0.5°` |
| Receiver | `trajectory_preview.gd:_on_aim_inputs_changed()` | `abs(rotation_change) >= 0.5°` (flick changes ignored — fixed-length line) |
| Re-entry | `trajectory_preview.gd:_on_phase_changed()` | `_prev_rotation` reset to `-INF` on AIM entry to ensure first emission passes |

---

## 7. Velocity Decay (Damping)

With `linear_damp = 0.5`, velocity decays exponentially:

```
v(t) = v0 * e^(-0.5 * t)
```

| Time | Velocity Remaining | Distance Traveled (v0 = 800) |
|---|---|---|
| 0.0s | 100% | 0 px |
| 0.5s | 78% | ~312 px |
| 1.0s | 61% | ~486 px |
| 2.0s | 37% | ~631 px |
| 3.0s | 22% | ~688 px |

Formula for distance: `d(t) = v0 / damp * (1 - e^(-damp * t))`

At v0 = 800, the marble can travel ~688 px before stopping. The field diameter is 440 px, so a mid-to-high power shot easily traverses the field.

---

## 8. Tuning Guide

### Overall Game Feel

**`SHOT_IMPULSE_SCALE`** (`match.gd:10`) — The master volume knob for shot power. Increase to make all shots faster; decrease to slow the game down.

- If marbles feel sluggish even at max flick → raise this.
- If marbles rocket off-screen instantly → lower this.
- Current value (80) gives max velocity of 800–1200 px/s depending on character.
- Each ±10 changes max velocity by ±100–150 px/s.

### Surface Friction

**`DEFAULT_LINEAR_DAMP`** (`field_state_manager.gd:5`) — How quickly marbles decelerate on the base field surface.

- Higher values → marbles stop faster, gameplay is more positional.
- Lower values → marbles slide longer, gameplay is more chaotic.
- Current value (0.5): marble loses ~40% speed per second.
- Recommended range: 0.2 (ice-like) to 1.5 (sand-like).
- Individual marble `friction` values are overridden by this — to restore per-marble friction, remove the global `set_linear_damp()` call in `push_to_engine()`.

### Marble Variety

Each `.tres` marble resource has a `PhysicsObjectData` sub-resource. Tune these to create distinct marble types:

| Property | Gameplay Effect | Tuning Range |
|---|---|---|
| `weight` (mass) | Heavier = slower from same impulse, harder to knock out | 0.5–3.0 |
| `elasticity` (bounce) | Higher = more kinetic energy preserved on collision | 0.0–1.0 |
| `friction` | Initial `linear_damp` before global override | 0.1–2.0 |
| `gravity_modifier` | Scales gravity effects from FieldStateManager | 0.0–2.0 |

**Note on `friction`:** Per-marble `friction` is currently overwritten by the global `linear_damp` (0.5) from `FieldStateManager`. If you want per-marble friction to matter, either:
- Remove the `set_linear_damp()` call in `field_state_manager.gd:push_to_engine()`, OR
- Change `push_to_engine()` to multiply the base damp by per-marble friction instead of overwriting.

### Character Balance

**`character.power`** — The multiplicative shot power stat. Because it multiplies with flick, small changes have large effects.

- Default (1.0) is the baseline.
- Aggressive (1.5) gives +50% impulse — noticeable but not overwhelming.
- Keep power in the range 0.5–2.5. At 2.5 with max flick, impulse = 10 * 2.5 * 80 = 2000 px/s — the marble crosses the field in ~0.25s.
- Balance power against the character's health, mana, and exclusive cards.

### Field Size

**`FIELD_RADIUS`** (`field.gd:3`) — Changing the field size affects everything:

- Larger field → shots take longer to reach targets, more room for positioning.
- Smaller field → faster-paced, more collisions, easier knockouts.
- If you change `FIELD_RADIUS`, also adjust:
  - `FIELD_CENTER` (if repositioning)
  - `SHOOTER_SPAWN_DIST` (auto-computed: `FIELD_RADIUS + Marble.RADIUS + 6.0`)
  - Gravity zone radius (`_update_gravity_shape()`)
  - Boundary detector radius (`_setup_boundary_detector()`)
  - Initial marble spawn positions (`match_fsm.gd:_spawn_initial_marbles()`)

### Quick Tune Cheat Sheet

| Symptom | Probable Cause | Fix |
|---|---|---|
| Shots too weak, marbles barely move | `SHOT_IMPULSE_SCALE` too low | Increase by 10–20 |
| Shots too strong, marbles fly off instantly | `SHOT_IMPULSE_SCALE` too high | Decrease by 10–20 |
| Marbles stop too quickly | `DEFAULT_LINEAR_DAMP` too high | Lower to 0.2–0.4 |
| Marbles slide forever | `DEFAULT_LINEAR_DAMP` too low | Raise to 0.8–1.2 |
| Heavy marble never moves | `weight` too high for current `SHOT_IMPULSE_SCALE` | Lower weight or raise scale |
| All marbles feel identical | Per-marble physics hidden by global damp | Remove `set_linear_damp()` global override |
| Character too strong/weak | `power` relative to baseline off | Adjust ±0.2 increments |
| Marbles never exit the field | Shot too weak for field size | Raise `SHOT_IMPULSE_SCALE` or lower `DEFAULT_LINEAR_DAMP` |
| Marbles exit too easily | Shot too strong, field too small | Lower `SHOT_IMPULSE_SCALE` or raise `DEFAULT_LINEAR_DAMP` |

### Derived Relationships

```
time_to_cross_field ≈ FIELD_RADIUS * 2 / (flick * power * SHOT_IMPULSE_SCALE / mass)
stop_distance ≈ (flick * power * SHOT_IMPULSE_SCALE) / (mass * linear_damp)
exit_velocity_needed ≈ sqrt(2 * linear_damp * distance_to_boundary) * initial_speed
```

For max flick Aggressive shot (1200 px/s, mass=1.0, damp=0.5):
- Crosses field in ~0.37 seconds.
- Travels ~688 px before stopping (exceeds field diameter).
- Loses half its speed after ~1.4 seconds.

---

## 9. Source File Index

| File | Contains |
|---|---|
| `scripts/gameplay/field.gd` | Field geometry constants, boundary detector, gravity zone, shooter spawn, marble spawning |
| `scripts/gameplay/marble.gd` | Marble class, RADIUS constant, physics setup from data |
| `scripts/resources/physics_object_data.gd` | Per-marble physics properties (friction, weight, elasticity, etc.) |
| `scripts/resources/character_data.gd` | Character power stat |
| `scripts/ui/match.gd` | Shot execution, aim controls, flick slider, impulse scale |
| `scripts/gameplay/trajectory_preview.gd` | Analytical trajectory prediction constants |
| `autoloads/field_state_manager.gd` | Physics layer stack defaults, recalculate, push_to_engine |
| `project.godot` | Global 2D gravity setting |
| `resources/cards/marble_*.tres` | Per-marble-type physics values |
| `resources/characters/character_*.tres` | Per-character power values |
