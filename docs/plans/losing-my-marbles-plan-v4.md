# Losing My Marbles! — Implementation Plan
**Version:** 4.0 | **Created:** May 2026
**Audience:** Core Engineering Team, AI Development Agents

---

## Table of Contents

1. [Project State Summary](#1-project-state-summary)
2. [Architecture Philosophy](#2-architecture-philosophy)
3. [Technology Stack & Plugins](#3-technology-stack--plugins)
4. [Locked Decisions](#4-locked-decisions)
5. [Phase Roadmap](#5-phase-roadmap)
6. [Testing & Quality Strategy](#6-testing--quality-strategy)
7. [Code Standards](#7-code-standards)

---

## 1. Project State Summary

**Status: Full Greenfield Rebuild**
The project is being rewritten from scratch to implement a full system overhaul. No legacy code will be retained. Historical bugs — such as raw node references causing use-after-free crashes, trailing commas breaking compilation, and manual physics position teleporting — are eliminated by adopting strict Godot 4.6 idioms and a decoupled architecture.

### Primary Objectives of the Rebuild:
- Clean, decoupled `SignalBus` architecture from day one.
- Native Godot 2D physics (`linear_damp` and `Area2D` gravity) instead of manual velocity overrides.
- Data-driven card architecture utilizing the Command Pattern via `.tres` Resources, with a trigger-context dispatch system separating PLAY-phase and SIMULATION-phase effects.
- Complete UI suites (Matchmaking, Deck Builder, Character Select, Offline Pass-and-Play) built on a scalable state machine.
- Server-authoritative physics with a client-side snapshot replay system for visual coherence during the SIMULATING phase.

---

## 2. Architecture Philosophy

### Composition Over Inheritance
Deep inheritance chains are explicitly avoided. Marbles and Obstacles share physical traits but differ conceptually. Both use a `PhysicsObjectData` Resource as a composable component. `MarbleData` extends `CardData` and contains `@export var physics: PhysicsObjectData`. `ObstacleData` (not a card) also contains a `PhysicsObjectData`. The physics engine reads from the component resource without requiring a shared object base class.

### Trigger-Context Effect Dispatch
`EffectData` carries a `trigger: TriggerEnum` field (`PLAY` or `SIMULATION`). The `EffectHandler` checks the current game phase context before dispatching any effect. Only effects whose `trigger` matches the active context are executed; mismatched effects are silently skipped. This allows a single Marble resource to define both its in-hand behavior (via `PLAY`-triggered effects) and its on-field knockoff behavior (via `SIMULATION`-triggered effects) without any schema duplication or runtime type-switching.

### Field State Layering
Map physics (Friction, Stickiness, Gravity, Elasticity, Weight) are dynamic. A `FieldStateManager` autoload recalculates global physics states using the additive formula: `Map Base + Terrain Delta + Sum(Active AOE Deltas)`. Properties are pushed to Godot engine primitives only when a layer changes, not per-tick.

### Full SignalBus Observer Pattern
No node shall store a reference to a sibling or cousin. All cross-system communication routes through the `SignalBus` autoload. Hardcoded scene-tree paths are forbidden.

### Server-Authoritative Match State
Godot State Charts runs the match FSM **on the server only**. Clients receive state integers via RPC to update their UI. There is no client prediction or lag compensation; turn-based latency is imperceptible. Physics also runs exclusively on the server; clients receive a snapshot replay buffer after each SIMULATING phase to display the outcome visually.

### Staged Placeholder Strategy
When a phase implements an FSM state that depends on data or logic deferred to a later phase, a functional stub is provided. The stub must satisfy the interface contract (same method signatures, same signal emissions, same data shape) using hardcoded defaults or empty collections, so that the consuming system works end-to-end. Stubs are replaced when their phase arrives; no other code should need to change.

---

## 3. Technology Stack & Plugins

### Engine
- **Godot 4.6** — GL Compatibility Renderer (Target: PC Desktop; Web/Mobile supported)
- **Physics:** Native Godot 2D Physics (`RigidBody2D`, `Area2D`)

### Plugins

| Plugin | Role | Scope |
|---|---|---|
| **Godot State Charts** | Match FSM | Server-side only; clients receive state enum via RPC |
| **Card Framework 1.3.3** | UI / Card rendering | Replaces custom dragging logic; manages Hand and Pile UI |
| **Phantom Camera (v0.6+)** | Camera Management | Manages transitions between Field Overview and Flick Aim views via `priority` swapping |
| **GUT 9.6.0** | Unit & integration tests | Deferred to Phase 6 (Polish) |
| **GDScript Linter** | Static code quality | Active from Phase 0; warnings-only (`Exit 1`) during Phases 0–5; strict mode (`Exit 2`) in Phase 6 |

*(Note: Beehive, GDSync, Input Helper, and Panku Console are explicitly excluded from the project scope.)*

---

## 4. Locked Decisions

The following decisions are finalized. They must not be reversed without a documented revision to this plan and the GDD.

| # | Topic | Decision |
|---|---|---|
| D1 | Stickiness Implementation | Additive map/AOE stickiness is applied as a `linear_damp` modifier to `RigidBody2D` instances via the `FieldStateManager`. |
| D2 | Gravity Implementation | The playing field is wrapped in an `Area2D` with `gravity_override = true`. `FieldStateManager` updates its directional vector and magnitude. |
| D3 | Effect Targeting | `EffectData` uses two enums: `TriggerEnum { PLAY, SIMULATION }` and `TargetEnum { SELF, OPPONENT, CURR_MARBLE, KNOCKER, KNOCKER_OPP, BOTH, FIELD_MAP, FIELD_MARBLES }`. PLAY-valid targets: `SELF`, `OPPONENT`, `CURR_MARBLE`, `BOTH`, `FIELD_MAP`, `FIELD_MARBLES`. SIMULATION-valid targets: `KNOCKER`, `KNOCKER_OPP`, `BOTH`, `FIELD_MAP`, `FIELD_MARBLES`. The `EffectHandler` validates trigger context before dispatch. |
| D4 | Multiplier System | A threshold table (e.g., 3/5/7 knocks) managed by `MatchManager` scales the numerical `value` inside the `EffectHandler` for the duration of the current turn. |
| D5 | Aiming Mechanics | The AIM phase uses three player-controlled inputs: Map Rotation, Fine-Tune Angle, and Flick Slider. Character Power is a **read-only stat**, not a player input. The final shot impulse is computed as `slider_value * character.power` at execution time. |
| D6 | Single-Player Offline | Implemented via `OfflineMultiplayerPeer`. Operates strictly as pass-and-play. The **Pass Device Screen** fires at every turn transition: it uses the Transition Screen's visual language (sliding animation) but displays a "Pass the device to [Player Name]" prompt and requires an explicit confirmation button press before the board is revealed. |
| D7 | Session Discovery | Matchmaking uses 6-character UDP broadcast Session Keys exclusively. Direct IP connect fields are purged from the project. |
| D8 | Object Lifecycle | If the launched shooting marble comes to rest without exiting the field boundary, it sheds its "shooter" state and becomes a standard field marble in the shared pool. If it exits the boundary, it is despawned and its SIMULATION-triggered effects do not fire. |
| D9 | Marble Reference Safety | `GameState.active_marble` must be implemented as a computed property backed by a `WeakRef` internally to prevent use-after-free hazards during ejection or freeing. |
| D10 | Input / Prediction Throttling | Trajectory prediction uses a **dual-throttle** mechanism: an emission gate in `match.gd` emits `aim_inputs_changed` only when the total angle changes by ≥ 0.5°; a receiver gate in `TrajectoryPreview` skips recalculation on rotation delta < 0.5°. Flick changes do not affect the preview (fixed-length line). This prevents redundant redraws. |
| D11 | Anti-Overlap Spawning | The `MatchManager` or a dedicated utility module must implement a `find_valid_position()` algorithm that checks for existing `RigidBody2D` overlaps before instantiating any new marble on the field. |
| D12 | Discard Pile | Each player has a separate discard pile alongside their draw deck. Played cards move to the discard pile. When the draw deck is empty during a draw, the discard pile is shuffled and becomes the new draw deck. If both are empty, only the available cards are drawn (no crash). |
| D13 | One-Marble-per-Shot Constraint | `MatchManager` tracks a per-turn boolean flag `marble_played`. This flag is set `true` when any Marble card is played and reset `false` after each SIMULATING phase concludes. The server rejects any `_request_play_card` RPC that would play a second Marble card while the flag is `true`. The UI disables Marble cards in the hand and displays a visual hint directing the player to the AIM phase once a marble is in play. |
| D14 | Client Physics Snapshot Relay | During the SIMULATING phase, the server captures marble positions and velocities every 2 physics ticks into a snapshot buffer. When simulation fully resolves, the server transmits the buffer and authoritative final state to clients via one reliable RPC. Clients replay the buffer at the matching interval, interpolating between frames, then apply the authoritative final state to correct drift. No real-time streaming; no client-side physics prediction. |
| D15 | KNOCKER Resolution | The `KNOCKER` target in `EffectData` resolves to the **player** who is currently the active shooter (i.e., the player whose shot is executing in the SIMULATING phase). This is tracked by `MatchManager` as `active_shooter_id: int` and passed as context to the `EffectHandler` at dispatch time. |
| D16 | Public Marble Pool Refill | When the shared marble pool is exhausted, all previously ejected or used marbles are returned to the pool and reshuffled. This mirrors the private deck reshuffle behavior. The match never ends due to an empty pool. |
| D17 | Field Boundary: Visual-Only, No Physical Wall | The field boundary is purely visual (drawn arc). There is no `StaticBody2D` collider at the field perimeter. Marbles freely roll off the field based on their velocity. The `BoundaryDetector` `Area2D` (radius = `FIELD_RADIUS`, aligned with the visual boundary) is the sole mechanism for detecting when a marble has left the field. It tracks bodies via `body_entered` and only emits `marble_exited_boundary` for bodies previously known to be inside, preventing false-positive exit signals from physics transients. This replaces the original "circular wall" design because a physical wall would trap marbles that should exit, contradicting the game's core mechanic of marbles being knocked out of bounds. |

---

## 5. Phase Roadmap

Each phase builds one functional pillar of the game. **Do not advance to the next phase until the current phase's objectives are manually verified using Godot's "Run Multiple Instances" (Host + Client) debug tool.** Stubs from one phase must remain functional until the phase that replaces them.

---

### Phase 0: Scaffolding & Data Schema

**Goal:** Establish project structure, tooling, linting, plugins, and all base Resource definitions. No game logic yet — this phase is purely structural.

#### 0.1 Project Initialization
- Initialize the Godot 4.6 project with GL Compatibility renderer.
- Create the standard directory layout: `scenes/`, `scripts/`, `resources/`, `assets/`, `autoloads/`, `addons/`, `test/`.
- Install and configure the **GDScript Linter** in warnings-only mode (`Exit 1`).

#### 0.2 Resource Directory Setup
- Confirm all `.tres` resource files reside in `res://resources/cards/` and `res://resources/characters/`.
- Verify that `DirAccess` can enumerate and `load()` all `.tres` files in both directories without errors.
- The `CardLibrary` helper loads resources via `DirAccess` directory traversal (no plugin dependency).

#### 0.3 Enum Definitions
Define the following enums in a shared `Enums.gd` autoload (or top-level constants file) so they are accessible project-wide without circular dependencies:

```gdscript
# Enums.gd (autoload or class_name Enums)

enum TriggerEnum {
    PLAY,       # Effect fires when the card is played from hand
    SIMULATION  # Effect fires when the marble is knocked off the field
}

enum TargetEnum {
    # PLAY-phase targets
    SELF,           # The player who played the card
    OPPONENT,       # The opposing player
    CURR_MARBLE,    # The marble designated as the current shooting marble
    # SIMULATION-phase targets
    KNOCKER,        # The player who took the shot that caused the knockoff
    KNOCKER_OPP,    # The player whose marble was knocked off
    # Valid in both phases
    BOTH,           # Both players
    FIELD_MAP,      # The field physics (FieldStateManager stack)
    FIELD_MARBLES   # All marbles currently on the field
}

enum CardTypeEnum {
    MARBLE,
    POWER_UP,
    TRICK,
    TERRAIN,
    AREA_OF_EFFECT
}

enum MatchState {
    INIT,
    DRAW,
    PLAY,
    AIM,
    SIMULATING,
    END_TURN
}
```

#### 0.4 Resource Definitions
Create the following `.gd` Resource scripts. All fields use strict type annotations with explicit defaults. These are data containers only — no logic.

```gdscript
# EffectData.gd
class_name EffectData
extends Resource

@export var effect_id: String = ""
@export var value: float = 0.0
@export var target: Enums.TargetEnum = Enums.TargetEnum.SELF
@export var trigger: Enums.TriggerEnum = Enums.TriggerEnum.PLAY
```

```gdscript
# PhysicsObjectData.gd
class_name PhysicsObjectData
extends Resource

@export var friction: float = 1.0
@export var stickiness: float = 0.0     # Maps to linear_damp
@export var gravity_modifier: float = 1.0
@export var elasticity: float = 0.5
@export var weight: float = 1.0         # Maps to RigidBody2D.mass
```

```gdscript
# CardData.gd
class_name CardData
extends Resource

@export var card_name: String = ""
@export var type: Enums.CardTypeEnum = Enums.CardTypeEnum.TRICK
@export var mana_cost: int = 0
@export var effects: Array[EffectData] = []
```

```gdscript
# MarbleData.gd
class_name MarbleData
extends CardData

# MarbleData has both PLAY-triggered and SIMULATION-triggered effects in the
# inherited `effects` array. PLAY effects fire when the card is played from
# hand. SIMULATION effects fire when the marble is knocked off the field.
# The type is set to CardTypeEnum.MARBLE by default.
@export var physics: PhysicsObjectData = PhysicsObjectData.new()
```

```gdscript
# CharacterData.gd
class_name CharacterData
extends Resource

@export var character_name: String = ""
@export var health: int = 20
@export var mana: int = 3              # Mana generated per turn (stat, not current pool)
@export var power: float = 1.0         # Read-only stat added to flick slider at execution
@export var exclusive_cards: Array[CardData] = []
```

#### 0.5 Verification
- All Resources can be instantiated and saved as `.tres` files in the Godot editor without errors.
- Enum values are accessible from any script via `Enums.TargetEnum.KNOCKER`, etc.
- The GDScript Linter runs cleanly with zero errors (warnings acceptable).

---

### Phase 1: Lobby & Deck Management

**Goal:** Implement Session Key matchmaking, Character Select, and Deck Builder UIs. No match logic yet.

#### 1.1 NetworkManager
- `NetworkManager.gd` (autoload): ENet Host/Client setup. Implements 6-character Session Key generation and UDP broadcast for LAN discovery.
- Host path: generate key → broadcast → wait for client connection.
- Client path: listen for broadcasts → display found sessions → connect to selected session.
- Direct IP input is explicitly excluded.

#### 1.2 Main Menu and Matchmaking Lobby UI
- Main Menu scene with buttons: Host, Join, Offline (Pass-and-Play), Quit.
- Matchmaking Lobby scene: displays the 6-character Session Key to the host; shows a waiting indicator; lists connected players.

#### 1.3 Character Selection UI
- Displays available characters with their Mana, Power, Health stats and exclusive card previews.
- Selection is sent to the server via RPC; server confirms and locks in both players' selections before proceeding.

#### 1.4 Deck Builder UI
- Uses `CardLibrary` (`DirAccess` directory traversal) to populate the available card pool.
- Two separate builder modes in one scene:
  - **Private Deck:** Player assembles a deck from all available card types for their selected character.
  - **Public Marble Pool:** Player fills a fixed-size pool exclusively with owned Marble cards.
- Deck validation (size, type restrictions) runs on the client for UX feedback and is re-validated server-side on submission.

#### 1.5 Offline Pass-and-Play Path
- Selecting "Offline" at the Main Menu bypasses networking entirely via `OfflineMultiplayerPeer`.
- Leads to the same Character Select and Deck Builder flow but for two local players in sequence.
- The **Pass Device Screen** must be present and functional from this phase onward for every turn transition in offline mode. It uses the Transition Screen visual language (horizontal slide animation) but displays "Pass the device to [Player Name]" and requires a confirmation button press.

---

### Phase 2: Match Flow (FSM)

**Goal:** Establish the server-authoritative FSM using Godot State Charts and implement all phase transitions, including the PLAY → AIM → SIMULATING → PLAY loop. Implement functional stubs for all marble-pool-dependent systems.

#### 2.1 Godot State Charts Setup
- Install **Godot State Charts**.
- Create the Match FSM on the server. The FSM structure must model the following transitions exactly:

```
INIT
  → DRAW    (auto on match start)
DRAW
  → PLAY    (auto on draw completion)
PLAY
  → AIM     (triggered by player action: "Advance to Aim")
  → END_TURN (triggered by player action: "End Turn")
AIM
  → SIMULATING (triggered by player action: "Execute Shot")
  → PLAY    (triggered by player action: "Back")
SIMULATING
  → PLAY    (auto on simulation completion)
END_TURN
  → DRAW    (auto, begins next player's turn)
```

- The `AIM → PLAY` ("Back") transition returns the player to the PLAY phase without consuming the marble card that was designated. The `marble_played` flag should not be set until the shot is actually executed.

#### 2.2 MatchManager
- `MatchManager.gd` (server-side node or autoload):
  - Maintains `active_player_id: int`, `turn_order: Array[int]`, `marble_played: bool`, `active_shooter_id: int`.
  - Validates all client RPCs: rejects out-of-turn actions, rejects second marble plays while `marble_played` is `true`.
  - Resets `marble_played` to `false` after each SIMULATING phase concludes.
  - Broadcasts state changes to all clients via `_sync_state.rpc(new_state: int)`.

```gdscript
@rpc("any_peer", "call_local", "reliable")
func _request_phase_advance(requested_transition: int) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id != active_player_id:
        push_warning("Phase advance request from non-active player: ", sender_id)
        return
    # Validate and execute state transition via State Charts...
```

#### 2.3 Turn Management
- Implement turn order tracking, active player switching, and server-side mana generation (fills to `character.mana` stat at the start of each DRAW phase).
- AOE duration decrement fires at the END_TURN state transition.

#### 2.4 Marble Pool Stub (Placeholder for Phase 4)
The INIT state requires a populated marble pool to spawn field marbles, but the actual merge logic is implemented in Phase 4. Provide a functional stub:
- `MarblePoolManager.gd`: Exposes the interface `get_marble() -> MarbleData`, `return_marble(marble: MarbleData) -> void`, `is_empty() -> bool`.
- **Stub implementation:** `get_marble()` returns a hardcoded default `MarbleData` resource. `is_empty()` always returns `false`.
- The stub must satisfy the interface contract completely so that Phase 3 physics and spawn logic work end-to-end. The stub is replaced in Phase 4 without requiring changes to any consuming code.

---

### Phase 3: Field, Aiming, Physics & Client Relay

**Goal:** Implement map simulation, aiming mechanics, Phantom Camera, physics layering, trajectory prediction, and the client snapshot relay system.

#### 3.1 Circular Field & Boundary Detection
- Create the Field scene (`field.gd`, extends `Node2D`) as a circular playing field:
  - **Radius:** 220px, **Center:** (450, 250).
  - **Visual boundary:** Drawn via `_draw()` — filled circle + arc outline (12px thickness) for the field surface. This is purely visual; there is no physical wall. Marbles are free to roll off the field.
  - **Gravity zone:** `Area2D` with `CircleShape2D` (radius 260), positioned at field center, configured with `gravity_space_override = REPLACE` for `FieldStateManager` control. Covers shooter spawn position and boundary detection zone.
  - **Boundary detector:** A separate `Area2D` (radius = `FIELD_RADIUS`, aligned with the visual boundary). Tracks bodies that enter via `body_entered` and only emits `SignalBus.marble_exited_boundary(marble)` when a tracked `Marble` exits (prevents false-positives from physics overlap transients). Marbles that leave this zone are considered off-field and should be despawned (D8).
- `find_valid_position()`: Physics overlap query via `intersect_shape` with golden-angle spiral search (D11), clamping candidates to field bounds. Used for all marble spawns.
- See `scripts/gameplay/field.gd` for constants and implementation.

#### 3.2 FieldStateManager
- `FieldStateManager.gd` (autoload):
  - Maintains three layers as **Dictionaries** (not `PhysicsObjectData` resources): `_map_base: Dictionary`, `_terrain_delta: Dictionary`, `_aoe_deltas: Array[Dictionary]`.
  - Dictionary keys: `"gravity_magnitude"`, `"gravity_direction"`, `"linear_damp"`. Defaults: gravity 0, direction zero, damp 2.0.
  - **`recalculate()`** (public): Single entry point. Computes `effective = map_base + terrain_delta + sum(aoe_deltas)` by iterating keys, then calls `push_to_engine(effective)`.
  - **`push_to_engine(effective: Dictionary)`**: Finds the `"game_field"` group node, calls `field.set_gravity(dir, mag)` and `field.set_linear_damp(damp)` (which iterates `"field_marbles"` group).
  - Layer mutators (`apply_map_base`, `set_terrain_delta`, `add_aoe_delta`, `remove_aoe_delta`) all call `recalculate()` after modification.
  - **`tick_aoe_durations()`**: Decrements `turns_remaining` on all AOEs, removes expired ones (≤ 0), calls `recalculate()` if changed. Called at END_TURN state transition.
  - `recalculate()` is called only when a layer changes — never per-tick.
  - See `autoloads/field_state_manager.gd`.

#### 3.3 Phantom Camera
- Install **Phantom Camera (v0.6+)**.
- Two `PhantomCamera2D` nodes:
  - **`BoardOverviewCamera`** (existing, renamed): priority 10, shows the full field top-down. Configured in the match scene with `unique_name_in_owner`.
  - **`ShooterFocusCamera`** (created programmatically in `field.gd._setup_shooter_camera()`): priority 0 default, positioned at field center.
- Camera switching is driven by `SignalBus.phase_changed` → `_on_phase_changed_for_camera()` in `field.gd`:
  - AIM or SIMULATING: `ShooterFocusCamera.priority = 20` (takes over from BoardOverviewCamera).
  - All other states: `ShooterFocusCamera.priority = 0` (falls back to BoardOverview).
- `_exit_tree()` disconnects the SignalBus connection.

#### 3.4 AIM Phase UI
- **Map Rotation:** `set_map_rotation(degrees)` rotates the **Camera2D** nodes (`BoardOverviewCamera` and `ShooterFocusCamera`), not the Map scene. `Camera2D.ignore_rotation = false` is set in both `.tscn` and `_ready()`. Marbles stay fixed in world space.
- **Shooter sample marble:** Spawned at AIM entry via `_spawn_shooter_sample()`, frozen at a position outside the field boundary (`SHOOTER_SPAWN_DIST = FIELD_RADIUS + Marble.RADIUS + 6.0`, ~241px). Spawn position respects persisted `_current_rotation_degrees` (applied immediately after spawn via `_update_shooter_marble_position()`). Anti-overlap placement via `intersect_shape` query with golden-angle spiral search (D11). Counter-rotated so it appears visually fixed at the right edge. Despawned on AIM exit (except when transitioning to SIMULATING).
- **Dual aim control sets** (built programmatically in `match.gd._build_aim_controls()`):
  - **Field rotation buttons** (±120°/sec) — coarse aim.
  - **Fine-tune buttons** (±60°/sec) — precise angular offset.
  - **Flick Power slider** (0–10, step 0.1) — stored in `_flick_value`.
- Total launch angle = `_rotation_value + _fine_tune_value`. `_fine_tune_value` resets to 0 on AIM entry; `_rotation_value` persists across turns for UX continuity.
- `character.power` value is read-only from `CharacterData` and is never exposed as an adjustable input (D5). It will be added to `_flick_value` at shot execution time.

#### 3.5 Trajectory Prediction
- `TrajectoryPreview.gd` (`class_name`, child of Field, created programmatically via `_setup_trajectory_preview()`).
- **Uses analytical circle-ray intersection** (quadratic solver) — NOT physics raycasts. This avoids coupling to the physics tick and gives deterministic, frame-rate-independent predictions.
- **Algorithm:**
  1. Compute field entry point by intersecting the shot ray with the field boundary circle (shooter→field entry passes through wall without collision).
  2. From the entry point, check only field marbles (not the wall) using combined radii (`Marble.RADIUS * 2.0`) for the hit test.
  3. On hit: single amber line from shooter to the first hit point. Ghost marble marker (translucent circle + arc at `Marble.RADIUS`, 35% alpha) at the predicted hit point.
  4. On no hit: line extends a fixed 2000px across the field.
  5. **No bounce prediction** — preview stops at first collision (bounce direction proved inaccurate vs. physics simulation).
  6. **No flick-power-based length** — line uses fixed `TRAJECTORY_EXTEND` for UX simplicity.
- **Throttle mechanism:**
  - **Emission gate** in `match.gd._emit_aim_if_changed()`: only emits when `abs(total - last_emitted) > 0.5°`.
  - **Receiver gate** in `TrajectoryPreview._on_aim_inputs_changed()`: rotation-only check (0.5° delta). Flick changes no longer trigger redraws.
  - **Re-entry fix:** `_prev_rotation` reset to `-INF` on AIM entry; emission deferred via `call_deferred` to ensure shooter exists before first draw.
- **Signal flow:** `match.gd` → `SignalBus.aim_inputs_changed(rotation_degrees, flick_power)` → `TrajectoryPreview._on_aim_inputs_changed()`.
- Field exposes `get_shooter_position()` and `get_field_marble_positions()` for the preview to query.
- Shooter spawn respects persisted rotation via `_current_rotation_degrees` tracking in `field.gd`.
- See `scripts/gameplay/trajectory_preview.gd`.

#### 3.6 Shot Execution
- On "Execute Shot" (already wired to `_fsm.send_event("shoot")` in `match.gd._on_execute_pressed()`):
  - The flick power value is stored in `match.gd._flick_value` (range 0–10).
  - The total launch angle is `_rotation_value + _fine_tune_value`.
  - Shot direction: `Vector2.LEFT.rotated(deg_to_rad(total_angle))`.
  - Apply `RigidBody2D.apply_central_impulse(direction * _flick_value * character.power)` to the designated shooting marble on the server.
- Transition to SIMULATING state.
- The `ExecuteButton` and FSM `"shoot"` event are already wired; only the physics impulse and state transition logic need implementation.

#### 3.7 SIMULATING Phase: Server Snapshot Capture
On the server, during the SIMULATING phase:
- Maintain `_snapshot_buffer: Array[Dictionary]` and a tick counter.
- Every 2 physics ticks, capture a snapshot:

```gdscript
func _capture_snapshot() -> void:
    var frame: Dictionary = {}
    for body in get_tree().get_nodes_in_group("field_marbles"):
        if body is RigidBody2D:
            frame[body.get_instance_id()] = {
                "pos": body.global_position,
                "vel": body.linear_velocity,
                "avel": body.angular_velocity,
                "pid": (body as Marble).owner_player_id,
            }
    _snapshot_buffer.append(frame)
```

- Detect simulation completion by monitoring marble velocities falling below thresholds (`VELOCITY_THRESHOLD = 0.5`, `ANGULAR_VELOCITY_THRESHOLD = 0.1`) after `SLEEP_CHECK_DELAY = 0.3s`. Safety timeout at `SIMULATION_TIMEOUT = 10s`.
- When simulation is complete:
  - Build `_final_state: Dictionary` with authoritative final positions of all remaining marbles.
  - Despawn marbles in `_exited_marbles` (tracked by `BoundaryDetector`), erase them from `final_state`.
  - Emit `SignalBus.simulation_complete(final_state)` to trigger SIMULATING → PLAY transition.
  - Transmit snapshot buffer and final state to clients via `_sync_snapshot_replay.rpc()`.

#### 3.8 SIMULATING Phase: Client Snapshot Replay
On clients, receive and replay the snapshot buffer:

```gdscript
@rpc("authority", "call_remote", "reliable")
func _sync_snapshot_replay(buffer: Array, final_state: Dictionary) -> void:
    # Buffer and final_state are received after simulation completes on server.
    # Replay buffer at the same 2-tick interval (approx. 33ms at 60Hz physics).
    for frame: Dictionary in buffer:
        _apply_snapshot_frame(frame)   # Move client marble visuals to frame positions
        await get_tree().create_timer(SNAPSHOT_INTERVAL).timeout
    _apply_final_state(final_state)    # Lock in authoritative positions, correct drift

func _apply_snapshot_frame(frame: Dictionary) -> void:
    for marble_id: int in frame:
        var marble: Node2D = _get_client_marble_visual(marble_id)
        if is_instance_valid(marble):
            marble.global_position = frame[marble_id]["pos"]
```

- `SNAPSHOT_INTERVAL` is a constant matching the server's 2-tick capture interval: `2.0 / ProjectSettings.get("physics/common/physics_ticks_per_second")`.
- After `_apply_final_state()`, the client's visuals are locked to server-authoritative positions. Any interpolation drift during replay is overridden.

#### 3.9 Marble Lifecycle
- If the shooting marble's `RigidBody2D` remains on the field after simulation, remove its "shooter" designation and register it in the shared pool via `MarblePoolManager.return_marble()`.
- If it exits the boundary (detected via `Area2D` exit signal), despawn it. Its SIMULATION-triggered effects do not fire.
- Use the `find_valid_position()` (D11) utility for all new marble spawns to prevent overlap.

---

### Phase 4: Card Framework Integration

**Goal:** Integrate the Card Framework plugin for UI card handling, implement full deck lifecycle (including the discard pile), implement the one-marble-per-shot constraint, implement the public marble pool merge, implement contextual phase buttons with animations, and enable server-authoritative card play validation.

#### 4.1 Card Framework Setup
- Install **Card Framework 1.3.3**.
- Write a `CardFactory.gd` utility: given a `CardData` resource, instantiate the appropriate Card Framework UI card, bind its data (name, mana cost, effects preview), and return it as a node ready for placement in the Hand UI.

#### 4.2 Hand UI and Drag-to-Play
- Implement the Hand UI using Card Framework's Hand and Pile components.
- Cards are drag-and-drop into the designated "play area."
- When a card is dragged to the play area, the client sends `_request_play_card(card_id: String)` RPC to the server for validation.

#### 4.3 Server-Side Card Validation
The server validates every `_request_play_card` request before executing it:

```gdscript
@rpc("any_peer", "call_local", "reliable")
func _request_play_card(card_id: String) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id != active_player_id:
        push_warning("Out-of-turn card play from: ", sender_id)
        return
    var card: CardData = _get_card_from_hand(sender_id, card_id)
    if card == null:
        push_warning("Card not in hand: ", card_id)
        return
    if active_mana < card.mana_cost:
        push_warning("Insufficient mana for card: ", card_id)
        return
    # One-marble constraint check (D13)
    if card.type == Enums.CardTypeEnum.MARBLE and marble_played:
        push_warning("Second marble card rejected for sender: ", sender_id)
        return
    # Validation passed — execute play
    _execute_card_play(sender_id, card)
```

#### 4.4 Discard Pile Implementation
- `DeckManager.gd` (server-side, per player): manages `draw_pile: Array[CardData]`, `hand: Array[CardData]`, `discard_pile: Array[CardData]`.
- `draw_cards(count: int) -> void`: if `draw_pile` is empty, shuffle `discard_pile` into `draw_pile` first. Draw up to `count` cards; if still insufficient, draw what remains without error.
- `play_card(card: CardData) -> void`: removes card from `hand`, appends to `discard_pile`.
- `end_turn_reshuffle() -> void`: moves all remaining `hand` cards to `discard_pile`.

#### 4.5 One-Marble Constraint and UI Hint (D13)
- After `_execute_card_play` plays a Marble card, set `marble_played = true` in `MatchManager`.
- Broadcast this state to the playing client via RPC so the UI can respond.
- On the client, when `marble_played` is `true`:
  - Disable (grey out) all remaining Marble cards in the hand.
  - Show a pulsing visual indicator on the "Aim" button in the right-panel contextual buttons, directing the player to proceed.
- When SIMULATING phase concludes and control returns to PLAY, the server broadcasts `marble_played = false`, re-enabling Marble cards.

#### 4.6 Contextual Right-Panel Button Animations
The right-panel phase buttons on the Main View change based on the current FSM state. Transitions are animated:
- When the FSM state changes, the current button group plays a slide-out animation (buttons move off-screen in one direction).
- Once fully off-screen, the new button group for the incoming state plays a slide-in animation from the opposite direction.
- Button sets by state:

| FSM State | Button Set |
|---|---|
| DRAW | Empty (no interactive buttons; phase resolves automatically) |
| PLAY (no marble played) | "Aim" button, "End Turn" button |
| PLAY (marble played) | "Aim" button (pulsing hint highlight), "End Turn" button |
| AIM | "Execute" button, "Back" button |

#### 4.7 Card Play Animations
- When the server confirms a card play, broadcast the card's visual to all clients before effect resolution via `@rpc("authority", "call_local")`.
- The animation plays on both screens first; the effect resolves only after the animation completes.

#### 4.8 Public Marble Pool Merge (Replaces Phase 2 Stub)
- In the INIT state, `MarblePoolManager` collects all players' public `MarbleData` decks submitted from the Deck Builder, merges them into one `Array[MarbleData]`, and shuffles.
- `get_marble() -> MarbleData`: pops from the shuffled pool.
- `return_marble(marble: MarbleData) -> void`: appends back to the pool.
- `refill_pool() -> void`: called when `is_empty()` returns `true`. Moves all previously ejected marbles back into the pool and reshuffles (D16).
- This replaces the Phase 2 stub entirely. No other code needs to change because the interface contract is identical.

---

### Phase 5: Effects & Multipliers

**Goal:** Implement the `EffectHandler` with trigger-context dispatch, register all effect callables, implement KNOCKER routing, implement the multiplier system, and implement AOE duration tracking.

#### 5.1 EffectHandler
- `EffectHandler.gd` (autoload or server-side singleton):
  - Maintains a `_registry: Dictionary` mapping `effect_id: String` to `Callable`.
  - Two primary dispatch methods:

```gdscript
# Dispatches all PLAY-triggered effects from a card.
# context provides active player, current marble, and field reference.
func dispatch_play_effects(card: CardData, context: PlayContext) -> void:
    for effect: EffectData in card.effects:
        if effect.trigger != Enums.TriggerEnum.PLAY:
            continue
        if not _registry.has(effect.effect_id):
            push_error("Unregistered effect_id: ", effect.effect_id)
            continue
        _registry[effect.effect_id].call(effect, context)

# Dispatches all SIMULATION-triggered effects from a knocked-out marble.
# context provides active_shooter_id, knocked_out_owner_id, and field reference.
func dispatch_simulation_effects(marble: MarbleData, context: SimulationContext) -> void:
    for effect: EffectData in marble.effects:
        if effect.trigger != Enums.TriggerEnum.SIMULATION:
            continue
        if not _registry.has(effect.effect_id):
            push_error("Unregistered effect_id: ", effect.effect_id)
            continue
        _registry[effect.effect_id].call(effect, context)
```

#### 5.2 Context Objects
Define `PlayContext` and `SimulationContext` as lightweight data classes (inner classes or Resource subclasses):

```gdscript
# PlayContext: passed to all PLAY-triggered effect callables
class PlayContext:
    var active_player_id: int
    var opponent_player_id: int
    var current_marble: MarbleData   # The designated shooting marble (may be null)
    var field_state_manager: FieldStateManager

# SimulationContext: passed to all SIMULATION-triggered effect callables
class SimulationContext:
    var knocker_player_id: int       # D15: the player whose shot caused the knockoff
    var knocker_opp_player_id: int   # The player whose marble was knocked out
    var field_state_manager: FieldStateManager
```

#### 5.3 Target Routing
Each registered Callable receives the `EffectData` and the appropriate context. The Callable is responsible for routing to the correct target. A helper method `_resolve_target(effect: EffectData, context)` in `EffectHandler` can simplify this:

```gdscript
func _resolve_target(effect: EffectData, context) -> Variant:
    match effect.target:
        Enums.TargetEnum.SELF:       return _get_player(context.active_player_id)
        Enums.TargetEnum.OPPONENT:   return _get_player(context.opponent_player_id)
        Enums.TargetEnum.CURR_MARBLE: return context.current_marble
        Enums.TargetEnum.KNOCKER:    return _get_player(context.knocker_player_id)
        Enums.TargetEnum.KNOCKER_OPP: return _get_player(context.knocker_opp_player_id)
        Enums.TargetEnum.BOTH:       return [_get_player(context.active_player_id), _get_player(context.opponent_player_id)]
        Enums.TargetEnum.FIELD_MAP:  return context.field_state_manager
        Enums.TargetEnum.FIELD_MARBLES: return _get_all_active_marbles()
    return null
```

#### 5.4 Effect Registration
Register individual effects at `EffectHandler._ready()`. Each effect is a pure function registered as a Callable:

```gdscript
func _ready() -> void:
    _registry["deal_damage"]     = _effect_deal_damage
    _registry["heal"]            = _effect_heal
    _registry["spawn_obstacle"]  = _effect_spawn_obstacle
    _registry["apply_aoe"]       = _effect_apply_aoe
    _registry["set_linear_damp"] = _effect_set_linear_damp
    # ... register additional effects here as new card types are created.
    # Never modify dispatch_play_effects or dispatch_simulation_effects to add new effects.
```

#### 5.5 Knockout Multiplier
- `MatchManager` tracks `knockouts_this_turn: int`, reset to `0` at each DRAW phase.
- After each marble knockoff in a SIMULATING phase, increment `knockouts_this_turn`.
- Before `dispatch_simulation_effects()` is called for each marble, compute `multiplier: float` from the threshold table (e.g., `{3: 1.5, 5: 2.0, 7: 3.0}`). Pass the multiplier to the `SimulationContext`.
- The `EffectHandler` multiplies `effect.value` by the context multiplier before applying. This scaling is applied only during the current simulation step's dispatches.

#### 5.6 AOE Duration Tracking
- Each active AOE on the `FieldStateManager` stack carries a `turns_remaining: int` counter.
- At the END_TURN state transition, `FieldStateManager.tick_aoe_durations()` decrements all counters.
- Any AOE with `turns_remaining <= 0` is removed from the stack.
- After removal, `FieldStateManager.recalculate()` is called to push the updated effective values to the physics engine.

---

### Phase 6: Polish & Testing

**Goal:** Enable strict linting, write GUT integration tests, clear all remaining technical debt, and validate end-to-end multiplayer and pass-and-play behavior.

#### 6.1 GUT Installation
- Install **GUT 9.6.0** and configure the test runner in Godot's editor.

#### 6.2 Integration Test Suite
Write GUT integration tests covering:

| Test Area | What to Verify |
|---|---|
| Network Flow | Connection via Session Key; Lobby entry; `OfflineMultiplayerPeer` path |
| Turn FSM | All state transitions including PLAY → AIM → SIMULATING → PLAY loop; END_TURN from PLAY; AIM → PLAY ("Back") |
| Discard Pile | Draw from deck; card moved to discard on play; deck exhaustion triggers discard reshuffle; double-empty draws no cards |
| One-Marble Constraint | Second marble card is rejected; flag resets after SIMULATING; UI disabling reflects server state |
| Physics Stacking | `FieldStateManager` outputs correct additive sums for all combinations of terrain + AOE; weight applied to marble mass |
| Effect Trigger Context | PLAY-triggered effects do not fire during SIMULATION phase (and vice versa); KNOCKER resolves to the correct player ID |
| Snapshot Relay | Snapshot buffer received by client; marble positions after replay match server final state within tolerance |
| Marble Pool Refill | Pool correctly refills when exhausted; refill does not duplicate or lose marbles |
| Multiplier Scaling | Correct multiplier tier applies based on knockouts_this_turn; resets each turn |

#### 6.3 Strict Linting
- Switch GDScript Linter to strict mode (`Exit 2` on any critical warning).
- Resolve all remaining type annotation gaps, untyped function signatures, and unreachable code warnings.

#### 6.4 Technical Debt Clearance
- Replace all Phase 2 stubs with their final implementations (should be complete by Phase 4, confirmed here).
- Review all `push_warning` and `push_error` calls to ensure they are meaningful and logged appropriately.
- Confirm all `_exit_tree()` disconnects are in place for every `SignalBus` connection made in `_ready()`.

---

## 6. Testing & Quality Strategy

### Linter Gates
During Phases 0–5, the GDScript Linter runs in development mode (`Exit 1`): warnings are logged to the console but do not block builds. This allows rapid iteration on the greenfield rebuild. In Phase 6, strict mode is enabled (`Exit 2`): all type and syntax warnings must be resolved before the build is considered clean.

### Manual Verification Protocol
During Phases 1–5, each phase is manually verified using Godot's **"Run Multiple Instances"** debug tool (one instance as Host, one as Client) before advancing to the next phase. Additionally, the pass-and-play path must be verified locally in each phase where it is relevant.

### Test Deferral Rationale
GUT tests are deliberately deferred to Phase 6. During the greenfield rebuild, the FSM, UI, and physics architecture are subject to structural change. Writing fine-grained unit tests against frequently moving interfaces increases maintenance burden without yielding proportional confidence. Integration tests written in Phase 6 against the stable final architecture are higher-value.

---

## 7. Code Standards

### Type Annotations
Strict static typing is mandatory for all variables, parameters, and return types. No untyped declarations are permitted.

```gdscript
var health: int = 20
var active_effects: Array[EffectData] = []

func take_damage(amount: int) -> void:
    health -= amount

func get_effective_mana() -> int:
    return current_mana
```

### SignalBus Observer Pattern
Hardcoded node paths (e.g., `$"../SiblingNode"`, `get_parent().get_node(...)`) are strictly forbidden for cross-system communication. All cross-system events route through the global `SignalBus.gd` autoload.

```gdscript
# Emitting from a Marble node (server-side)
SignalBus.marble_knocked_out.emit(marble_id, context.knocker_player_id)

# Listening in MatchManager
func _ready() -> void:
    SignalBus.marble_knocked_out.connect(_on_marble_knocked_out)

func _exit_tree() -> void:
    SignalBus.marble_knocked_out.disconnect(_on_marble_knocked_out)
```

### Server Authority & RPC Validation
State mutations happen exclusively on the server. Every RPC that accepts requests from clients must:
1. Verify it is executing on the server (`if not multiplayer.is_server(): return`).
2. Identify the sender (`multiplayer.get_remote_sender_id()`).
3. Validate the sender is the active player.
4. Validate the requested action is legal in the current state.

```gdscript
@rpc("any_peer", "call_local", "reliable")
func _request_play_card(card_id: String) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    if sender_id != active_player_id:
        push_warning("Out-of-turn card play from: ", sender_id)
        return
    # ... proceed with validation
```

### Signal Connection Cleanup
Every node that connects to `SignalBus` or any autoload signal in `_ready()` **must** explicitly disconnect in `_exit_tree()`. This prevents orphaned callbacks from executing on freed nodes during long-running multiplayer sessions.

```gdscript
func _ready() -> void:
    SignalBus.state_changed.connect(_on_state_changed)

func _exit_tree() -> void:
    SignalBus.state_changed.disconnect(_on_state_changed)
```

### Input Efficiency
Per-frame physics polling and trajectory preview updates must be gated by state-change checks or numerical delta thresholds. The trajectory raycast must not recalculate unless `abs(slider_value - prev_pull) > 0.01`.

### Memory Hazard Prevention
Direct raw node references to transient physics objects (marbles, obstacles) are forbidden. Use `WeakRef` or `instance_id` tracking for any object that may be ejected or freed during a simulation step. `GameState.active_marble` is backed by `WeakRef` internally and exposes a safe computed property.

### Effect Registration Pattern
New effects are added by registering a `Callable` in `EffectHandler._ready()`. The `EffectHandler`'s dispatch methods (`dispatch_play_effects`, `dispatch_simulation_effects`) are never modified to accommodate new effects. This is the open/closed principle as applied to the Command Pattern.

```gdscript
# Adding a new "freeze_field" effect:
# 1. Register the Callable in _ready()
_registry["freeze_field"] = _effect_freeze_field

# 2. Implement the Callable
func _effect_freeze_field(effect: EffectData, context: PlayContext) -> void:
    var target: FieldStateManager = _resolve_target(effect, context)
    target.apply_freeze(effect.value)

# 3. Create a .tres CardData resource with effect_id = "freeze_field"
# No other code changes required.
```

### Snapshot Relay Constants
The client snapshot replay interval must be defined as a named constant, not a magic number, and must be derived from the engine physics tick rate to stay in sync with the server's capture interval:

```gdscript
const SNAPSHOT_CAPTURE_INTERVAL_TICKS: int = 2
const SNAPSHOT_REPLAY_INTERVAL: float = float(SNAPSHOT_CAPTURE_INTERVAL_TICKS) / \
    float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
```