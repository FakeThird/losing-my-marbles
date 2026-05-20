# Losing My Marbles! — Implementation Plan
**Version:** 5.0 | **Created:** May 2026
**Supersedes:** `docs/losing-my-marbles-plan-v4.md`
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

**Status: Full Greenfield Rebuild — Offline-First Development Model**

The project is being rewritten from scratch to implement a full system overhaul. No legacy code will be retained. Historical bugs — such as raw node references causing use-after-free crashes, trailing commas breaking compilation, and manual physics position teleporting — are eliminated by adopting strict Godot 4.6 idioms and a decoupled architecture.

### Primary Objectives of the Rebuild:
- Clean, decoupled `SignalBus` architecture from day one.
- Native Godot 2D physics (`linear_damp` and `Area2D` gravity) instead of manual velocity overrides.
- Data-driven card architecture utilizing the Command Pattern via `.tres` Resources, with a trigger-context dispatch system separating PLAY-phase and SIMULATION-phase effects.
- Complete UI suites (Matchmaking, Deck Builder, Character Select, Offline Pass-and-Play) built on a scalable state machine.
- Server-authoritative physics architecture with the structural skeleton to inject online multiplayer as a deferred phase.

### Offline-First Development Decision (May 2026)

**Online multiplayer functionality is deferred to Phase 7** (positioned after the Polish phase). The current online flow does not progress past the character selection screen — the `match_started` signal fails to trigger after both host and client select characters, preventing the transition to the match scene. Root cause investigation is deferred to avoid blocking Phase 3–6 feature development.

**Guiding principle:** All code written in Phases 3–6 shall build on the server-authoritative architecture (Godot State Charts FSM, `MatchManager`, RPC-structured methods) and remain easily-injectable by the deferred online logic. The system runs fully functional in offline mode via `OfflineMultiplayerPeer`. Online multiplayer is additive — it does not require rewriting any offline functionality.

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

### Server-Authoritative Match State (Offline)
The Godot State Charts FSM runs on the single authority peer (the host in offline mode via `OfflineMultiplayerPeer`). The architecture is structurally identical to online multiplayer: all state mutations go through `MatchManager` on the authority, and state is broadcast via RPC stubs that function as no-ops in offline mode but are already wired for the deferred online implementation.

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
| **Godot State Charts** | Match FSM | Runs on authority peer; structurally identical to server-only online mode |
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
| D4 | Multiplier System | A threshold table (3/5/7 knocks → 1.5×/2.0×/3.0×) managed by `MatchManager` scales the numerical `value` via `effect.duplicate()` in `dispatch_simulation_effects()`. Knockout counter resets at SIMULATING phase entry — multiplier accumulates within one shot, resets for the next. |
| D5 | Aiming Mechanics | The AIM phase uses three player-controlled inputs: Map Rotation, Fine-Tune Angle, and Flick Slider. Character Power is a **read-only stat**, not a player input. The final shot impulse is computed as `slider_value * character.power` at execution time. |
| D6 | Single-Player Offline | Implemented via `OfflineMultiplayerPeer`. Operates strictly as pass-and-play. The **Pass Device Screen** fires at every turn transition: it uses the Transition Screen's visual language (sliding animation) but displays a "Pass the device to [Player Name]" prompt and requires an explicit confirmation button press before the board is revealed. |
| D7 | Session Discovery | Matchmaking uses 6-character UDP broadcast Session Keys exclusively. Direct IP connect fields are purged from the project. *(Deferred: online matchmaking flow broken at character-select→match transition; fix deferred to Phase 7.)* |
| D8 | Object Lifecycle | If the launched shooting marble comes to rest without exiting the field boundary, it sheds its "shooter" state and becomes a standard field marble in the shared pool. If it exits the boundary, it is despawned and its SIMULATION-triggered effects do not fire. |
| D9 | Marble Reference Safety | `GameState.active_marble` must be implemented as a computed property backed by a `WeakRef` internally to prevent use-after-free hazards during ejection or freeing. |
| D10 | Input / Prediction Throttling | Trajectory prediction uses a **dual-throttle** mechanism: an emission gate in `match.gd` emits `aim_inputs_changed` only when the total angle changes by ≥ 0.5°; a receiver gate in `TrajectoryPreview` skips recalculation on rotation delta < 0.5°. Flick changes do not affect the preview (fixed-length line). This prevents redundant redraws. |
| D11 | Anti-Overlap Spawning | The `MatchManager` or a dedicated utility module must implement a `find_valid_position()` algorithm that checks for existing `RigidBody2D` overlaps before instantiating any new marble on the field. |
| D12 | Discard Pile | Each player has a separate discard pile alongside their draw deck. Played cards move to the discard pile. When the draw deck is empty during a draw, the discard pile is shuffled and becomes the new draw deck. If both are empty, only the available cards are drawn (no crash). |
| D13 | One-Marble-per-Shot Constraint | `MatchManager` tracks a per-turn boolean flag `marble_played`. This flag is set `true` when any Marble card is played and reset `false` after each SIMULATING phase concludes. The server rejects any `_request_play_card` RPC that would play a second Marble card while the flag is `true`. The UI disables Marble cards in the hand and displays a visual hint directing the player to the AIM phase once a marble is in play. |
| D14 | Client Physics Snapshot Relay | During the SIMULATING phase, the server captures marble positions and velocities every 2 physics ticks into a snapshot buffer. When simulation fully resolves, the server transmits the buffer and authoritative final state to clients via one reliable RPC. Clients replay the buffer at the matching interval, interpolating between frames, then apply the authoritative final state to correct drift. No real-time streaming; no client-side physics prediction. *(Deferred: full online replay (3.8.2–3.8.3) deferred to Phase 7. Client visual infrastructure (3.8.1) is implemented and provides the injection point.)* |
| D15 | KNOCKER Resolution | The `KNOCKER` target in `EffectData` resolves to the **player** who is currently the active shooter (i.e., the player whose shot is executing in the SIMULATING phase). This is tracked by `MatchManager` as `active_shooter_id: int` and passed as context to the `EffectHandler` at dispatch time. |
| D16 | Public Marble Pool Refill | When the shared marble pool is exhausted, all previously ejected or used marbles are returned to the pool and reshuffled. This mirrors the private deck reshuffle behavior. The match never ends due to an empty pool. |
| D17 | Field Boundary: Visual-Only, No Physical Wall | The field boundary is purely visual (drawn arc). There is no `StaticBody2D` collider at the field perimeter. Marbles freely roll off the field based on their velocity. The `BoundaryDetector` `Area2D` (radius = `FIELD_RADIUS`, aligned with the visual boundary) is the sole mechanism for detecting when a marble has left the field. It tracks bodies via `body_entered` and only emits `marble_exited_boundary` for bodies previously known to be inside, preventing false-positive exit signals from physics transients. |
| D18 | Offline-First Development | All Phases 3–6 are developed and verified in offline (Pass-and-Play) mode only. Online multiplayer functionality is consolidated into Phase 7. Code written in Phases 3–6 must maintain the server-authoritative architecture skeleton (RPC-structured methods, authority-guarded state mutations) so that online multiplayer can be injected without rewriting offline functionality. |

---

## 5. Phase Roadmap

Each phase builds one functional pillar of the game. **Do not advance to the next phase until the current phase's objectives are manually verified in offline (Pass-and-Play) mode.** Stubs from one phase must remain functional until the phase that replaces them.

**Verification mode:** Offline single-instance (Pass-and-Play) for Phases 3–6. Online multiplayer (Host + Client) verification is deferred to Phase 7.

---

### Phase 0: Scaffolding & Data Schema ✅ Complete

**Goal:** Establish project structure, tooling, linting, plugins, and all base Resource definitions.

#### 0.1 Project Initialization
- Initialize the Godot 4.6 project with GL Compatibility renderer.
- Create the standard directory layout: `scenes/`, `scripts/`, `resources/`, `assets/`, `autoloads/`, `addons/`, `test/`.
- Install and configure the **GDScript Linter** in warnings-only mode (`Exit 1`).

#### 0.2 Resource Directory Setup
- Confirm all `.tres` resource files reside in `res://resources/cards/` and `res://resources/characters/`.
- Verify that `DirAccess` can enumerate and `load()` all `.tres` files in both directories without errors.
- The `CardLibrary` helper loads resources via `DirAccess` directory traversal (no plugin dependency).

#### 0.3 Enum Definitions
Defined in `autoloads/enums.gd`: `TriggerEnum`, `TargetEnum`, `CardTypeEnum`, `MatchState`.

#### 0.4 Resource Definitions
Created: `EffectData.gd`, `PhysicsObjectData.gd`, `CardData.gd`, `MarbleData.gd`, `CharacterData.gd`.

---

### Phase 1: Lobby & Deck Management ✅ Complete

**Goal:** Session Key matchmaking, Character Select, Deck Builder UIs. *(Offline path functional; online matchmaking structural skeleton in place but character-select→match transition is broken — deferred to Phase 7.)*

#### 1.1 NetworkManager ✅
- `NetworkManager.gd` (autoload): ENet Host/Client setup. 6-character Session Key generation and UDP broadcast.
- Host path: generate key → broadcast → wait for client connection.
- Client path: listen for broadcasts → display found sessions → connect.
- `OfflineMultiplayerPeer` for offline Pass-and-Play.

#### 1.2 Main Menu and Matchmaking Lobby UI ✅
- Main Menu: Host, Join, Offline, Quit.
- Matchmaking Lobby: Session Key display, waiting indicator, connected players list.

#### 1.3 Character Selection UI ✅
- Displays characters with Mana, Power, Health stats.
- Selection sent to server via RPC; server confirms and locks in.

#### 1.4 Deck Builder UI ✅
- `CardLibrary` with `DirAccess` directory traversal.
- Private Deck and Public Marble Pool builder modes.

#### 1.5 Offline Pass-and-Play Path ✅
- "Offline" bypasses networking via `OfflineMultiplayerPeer`.
- Pass Device Screen functional at turn transitions.

---

### Phase 2: Match Flow (FSM) ✅ Complete

**Goal:** Server-authoritative FSM using Godot State Charts with all phase transitions. Functional stubs for marble-pool-dependent systems.

#### 2.1 Godot State Charts Setup ✅
- FSM with 7 states: INIT → DRAW → PLAY → AIM → SIMULATING → PLAY, PLAY → END_TURN → DRAW, AIM → PLAY ("Back").
- FSM runs on authority peer only.

#### 2.2 MatchManager ✅
- `MatchManager.gd`: `active_player_id`, `turn_order`, `marble_played`, `active_shooter_id`.
- RPC validation stubs in place for deferred online injection.
- Broadcasts state changes via `_sync_match_state.rpc()`.

#### 2.3 Turn Management ✅
- Turn order tracking, active player switching, mana generation at DRAW phase.
- AOE duration decrement at END_TURN.

#### 2.4 Marble Pool Stub ✅
- `MarblePoolManager.gd`: `get_marble()` returns hardcoded default `MarbleData`. `is_empty()` always returns `false`.
- Will be replaced by Phase 4.8 without interface changes.

---

### Phase 3: Field, Aiming, Physics & Simulation ✅ Complete

**Goal:** Circular field, aiming mechanics, Phantom Camera, physics layering, trajectory prediction, shot execution, simulation capture, and marble lifecycle. *(Offline-only verification.)*

#### 3.1 FieldStateManager API ✅ Done
- `recalculate()` → `push_to_engine()`. Layer mutators call `recalculate()`.

#### 3.2 Boundary Detection (D17) ✅ Done
- Visual-only field boundary. `BoundaryDetector` tracks bodies, emits `marble_exited_boundary`.

#### 3.3 Phantom Camera ✅ Done
- `BoardOverviewCamera` (priority 10) + `ShooterFocusCamera` (0/20). Phase-driven priority swap.

#### 3.4 AIM Phase UI ✅ Done
- Circular field rendering. `set_map_rotation()` rotates cameras. Shooter sample at rotation-aware position. Flick slider (0–10). Dual aim controls.

#### 3.5 Trajectory Prediction ✅ Done
- Analytical circle-ray intersection. Single amber line + ghost marble. Rotation-only throttle (0.5°). Deferred emission on AIM entry.

#### 3.6 Shot Execution ✅ Done
- `apply_central_impulse(direction * flick * power * 80)`. Golden-angle anti-overlap spawn. Multiplicative power (D5).

#### 3.7 Server Snapshot Capture ✅ Done
- Snapshot every 2 ticks. Velocity threshold sleep detection (0.5 px/s, 0.3s delay, 10s timeout). `_finish_simulation()` despawns exited marbles.

#### 3.8 Client Marble Visual Infrastructure ✅ Done
- `ClientMarbleVisual` class: lightweight `Node2D` visual-only marbles (no physics).
- `sync_marbles_to_clients()` → `_sync_marble_state` RPC: server pushes marble state to clients.
- `_client_marbles` dictionary keyed by server `instance_id`.
- Provides the injection point for deferred online snapshot replay (Phase 7).

#### 3.9 Marble Lifecycle ✅ Done
- If shooter marble stays on field after simulation → shed "shooter" state, register in shared pool via `return_marble()`.
- If it exits boundary → despawn (SIMULATION effects do not fire).
- Verified end-to-end: shot → simulation → lifecycle resolution → next turn in offline mode.

---

### Phase 4: Card Framework Integration ✅ Complete

**Goal:** Integrate the Card Framework plugin for UI card handling, implement full deck lifecycle (including discard pile), implement one-marble-per-shot constraint, implement public marble pool merge, implement contextual phase buttons with animations, enable card play validation, automate the DRAW phase with mana/card-count HUD and card-deal animations, and animate card play resolution (enlarge → shrink → discard). *(Offline-only; authority-guarded RPC methods serve as the online injection skeleton.)*

#### 4.1 Card Framework Setup ✅ Done
- Installed **Card Framework 1.3.3**.
- Created `CardDataFactory` (extends `CardFactory`, scene `card_data_factory.tscn`): bridges `CardData` resources to plugin `Card` nodes via `create_card_from_data(card_data, container)`.
- Factory generates card textures programmatically (no texture assets needed) using `FontFile` for card face rendering.
- No modifications to Card Framework plugin files.
- CardManager configured in `match.tscn` with `card_size = Vector2(150, 210)` and `card_factory_scene` pointing to `card_data_factory.tscn`.

#### 4.2 Hand UI and Drag-to-Play ✅ Done
- **TableFrame architecture:** Hand and PlayArea are children of `TableFrame` (opaque Control, full-rect). On AIM button press, TableFrame slides down (offset_top/bottom tween to viewport height, 0.4s TRANS_QUAD) to reveal the field — "putting cards away" metaphor.
- **Hand:** Card Framework `Hand` node (`anchor_left=0.5, anchor_right=0.5, offset_left=-300, offset_right=300`) — 600px centered bottom span. Fan spread with rotation and vertical curves.
- **PlayArea:** Large centered drop zone (`anchor 0.1-0.9 × 0.1-0.72`, unique name `%PlayArea`). `mouse_filter` toggled PASS during PLAY phase, IGNORE otherwise.
- **Card play detection:** Overrides `move_cards()` (not `on_card_move_done`) in `PlayArea` to emit `card_played` after `super.move_cards()` succeeds. This works because `CardContainer.add_card()` → `_assign_card_to_container()` sets `card.card_container = self` immediately, and `move_cards()` is the public entry point called by `CardManager._on_drag_dropped()`. The `on_card_move_done` callback only fires after tween animations complete, which never happens on drop (cards preserve global position).
- **Pass Device screen:** Fully opaque `ColorRect` background added to `pass_device.tscn`.

#### 4.3 Card Play Validation
The authority (host in offline mode) validates every `_request_play_card` request before executing it. Validation logic is structurally identical to online mode: sender check, turn check, mana cost check, one-marble constraint check. RPC annotation is already in place for deferred online injection.

#### 4.4 Discard Pile Implementation
- `DeckManager.gd` (per player): manages `draw_pile: Array[CardData]`, `hand: Array[CardData]`, `discard_pile: Array[CardData]`.
- `draw_cards(count: int) -> void`: if `draw_pile` is empty, shuffle `discard_pile` into `draw_pile` first.
- `play_card(card: CardData) -> void`: removes card from `hand`, appends to `discard_pile`.
- `end_turn_reshuffle() -> void`: moves all remaining `hand` cards to `discard_pile`.

#### 4.5 One-Marble Constraint and UI Hint (D13)
- After a Marble card is played, set `marble_played = true` in `MatchManager`.
- On the client, when `marble_played` is `true`: disable remaining Marble cards in hand, show pulsing "Aim" button hint.
- Reset `marble_played = false` after SIMULATING concludes.

#### 4.6 Contextual Right-Panel Button Animations
- Right-panel phase buttons slide-out/slide-in via Tween on FSM state change.
- Button sets by state: DRAW (empty — auto-transitions to PLAY via animation, see 4.9), PLAY (Aim + End Turn), AIM (Execute + Back).

#### 4.7 Card Play Animations
- When the authority confirms a card play, the card visual animates **before** effect resolution:
  1. **Enlarge:** Card scales up (e.g., 1.0 → 1.3 over 0.25s, TRANS_BACK) centered on screen to signify its effects are being applied.
  2. **Shrink & discard:** Card shrinks down (e.g., 1.3 → 0.0 over 0.3s, TRANS_QUAD) while tweening its position toward the discard pile box (see 4.9 for box positioning).
  3. **Effect resolution:** `EffectHandler` dispatches only after the animation sequence completes.
- The card does **not** remain in the PlayArea after being played.

#### 4.8 Public Marble Pool Merge (Replaces Phase 2 Stub)
- In INIT, `MarblePoolManager` collects all players' public `MarbleData` decks, merges, shuffles.
- `get_marble()`: pops from shuffled pool. `return_marble()`: appends back.
- `refill_pool()`: when empty, returns all ejected marbles to pool and reshuffles (D16).

#### 4.9 DRAW Phase Automation & HUD
The DRAW phase has no button — it auto-transitions to PLAY via animation. All HUD elements use Tweens for transitions.

- **Mana Bottle (bottom-left):** A progress-bar styled as a bottle, positioned in the bottom-left corner. Displays current mana / max mana. When mana regenerates during DRAW, the bottle plays a "filling-up" animation (value tween, 0.5–0.8s, TRANS_SINE) with an accompanying liquid-rise shader or color-fill effect. Label inside or beside the bottle shows the numeric value (e.g., "3/5").
- **Card Count Box (next to Mana Bottle):** A small box icon adjacent to the mana bottle displaying the number of remaining cards in the player's draw pile (e.g., "🃏 × 12"). Updates via signal when `DeckManager.draw_pile` changes.
- **Card Deal Animation:** When the DRAW phase begins (after mana regen completes):
  1. Cards spawn visually from the card count box position.
  2. Cards tween along an arc path into the player's Hand (fan spread positions), one at a time with staggered delays (0.08–0.12s per card, TRANS_QUAD).
  3. After the last card arrives, the FSM auto-transitions to PLAY via `send_event("draw_complete")`.
- **FSM change:** The DRAW state emits `draw_started` on entry. Mana regen and card deal run as an animation sequence. On completion, the state machine automatically fires the `draw_complete` transition to PLAY — no player input required during DRAW.
	
	**Implementation note:** Arc-path deal animation was skipped — cards use straight-line tween from card-count box to hand (visually acceptable, no functional impact).

---

### Phase 5: Effects & Multipliers ✅ Complete

**Goal:** Implement the `EffectHandler` with trigger-context dispatch, register all effect callables, implement KNOCKER routing, implement the multiplier system, and implement AOE duration tracking. *(Offline-only; architecture structurally identical to online.)*

#### 5.1 EffectHandler Skeleton + Context Objects ✅ Done
- `EffectHandler.gd` registered as autoload. `PlayContext` / `SimulationContext` inner `RefCounted` classes. `_registry` dictionary. `dispatch_play_effects()` and `dispatch_simulation_effects()` entry points.

#### 5.2 Target Routing ✅ Done
- `_resolve_target()` type-checks context (PlayContext vs SimulationContext), dispatches to `_resolve_play_target()` or `_resolve_simulation_target()`. Maps all 8 `TargetEnum` values per D3. Context-invalid targets log a warning and return `[]`.

#### 5.3 Effect Registration ✅ Done
- 8 handlers registered in `_ready()`: `deal_damage`, `heal`, `drain_mana`, `restore_mana`, `set_linear_damp`, `set_gravity`, `apply_aoe`, `clear_terrain`. Player-targeted handlers clamp health/mana to valid ranges. Field-targeted handlers call `FieldStateManager` methods.

#### 5.4 Knockout Multiplier (D4) ✅ Done
- `MULTIPLIER_THRESHOLDS` constant (3/5/7 → 1.5×/2.0×/3.0×). `increment_knockout()` called in `_on_marble_knocked_out()` before multiplier query. `reset_knockouts()` at SIMULATING entry. Multiplier applied via `effect.duplicate()` in `dispatch_simulation_effects()` — original resources never mutated.

#### 5.5 AOE Duration Tracking ✅ Done (pre-wired Phase 3/4)
- `FieldStateManager.tick_aoe_durations()` decrements turns, removes expired AOEs, recalculates. Wired in `_on_end_turn_entered()`.

---

### Phase 6: Polish & Testing ⬜ Not Started

**Goal:** Enable strict linting, write GUT integration tests, clear all remaining technical debt, and validate end-to-end offline pass-and-play behavior.

#### 6.1 GUT Installation
- Install **GUT 9.6.0** and configure the test runner.

#### 6.2 Integration Test Suite (Offline)
Write GUT integration tests covering:

| Test Area | What to Verify |
|---|---|
| Turn FSM | All state transitions including PLAY → AIM → SIMULATING → PLAY loop; END_TURN from PLAY; AIM → PLAY ("Back") |
| Discard Pile | Draw from deck; card moved to discard on play; deck exhaustion triggers discard reshuffle; double-empty draws no cards |
| One-Marble Constraint | Second marble card is rejected; flag resets after SIMULATING; UI disabling reflects authority state |
| Physics Stacking | `FieldStateManager` outputs correct additive sums; weight applied to marble mass |
| Effect Trigger Context | PLAY-triggered effects do not fire during SIMULATION phase (and vice versa); KNOCKER resolves to correct player ID |
| Snapshot Relay (Offline) | Snapshot buffer captured by authority; `_finish_simulation()` produces correct final state |
| Marble Pool Refill | Pool correctly refills when exhausted; refill does not duplicate or lose marbles |
| Multiplier Scaling | Correct multiplier tier applies based on knockouts_this_turn; resets each turn |
| Pass-and-Play | Pass Device Screen appears at every turn transition; confirmation button works |

#### 6.3 Strict Linting
- Switch GDScript Linter to strict mode (`Exit 2` on any critical warning).
- Resolve all remaining type annotation gaps, untyped function signatures, and unreachable code warnings.

#### 6.4 Technical Debt Clearance
- Replace all Phase 2 stubs with their final implementations.
- Review all `push_warning` and `push_error` calls for meaningful logging.
- Confirm all `_exit_tree()` disconnects are in place for every `SignalBus` connection.

---

### Phase 7: Online Multiplayer ⬜ Not Started (Deferred)

**Goal:** Fix the character-select→match transition, complete client snapshot replay, enable online card play validation, and validate end-to-end Host + Client multiplayer behavior. This phase is positioned after polishing because all features must be stable offline before network complexity is introduced.

**Rationale for deferral:** The current online flow does not progress past the character selection screen. The `match_started` signal fails to trigger after both host and client select characters, preventing the transition to the match scene. Root-causing and fixing this now would block feature development in Phases 4–6. Since the server-authoritative architecture is already in place, and all RPC-structured methods follow the same patterns as the working offline code, online multiplayer can be injected without architectural change.

#### 7.1 Character Select → Match Transition Fix
- Diagnose why `_pending_characters` check in `match_manager.gd` does not reach size ≥ 2 in online mode.
- Possible causes: RPC delivery order, client `character_selected` signal not reaching the server, or `_pending_characters` lifecycle.
- Fix the signal flow so both host and client selections trigger `match_started`.

#### 7.2 Online Client Snapshot Replay (completes 3.8)
- Implement `_sync_snapshot_replay` in `field.gd`: replay snapshot buffer at 2-tick interval on remote clients.
- `_apply_snapshot_frame(frame)`: update `ClientMarbleVisual` positions from frame data.
- `_apply_final_state(final_state)`: snap to authoritative positions, remove despawned visual marbles.
- Leverages the `_client_marbles` dictionary and `ClientMarbleVisual` infrastructure from 3.8.1.

#### 7.3 Online RPC Validation
- Enable strict `multiplayer.get_remote_sender_id()` validation on all client-to-server RPCs.
- Test turn-order enforcement, out-of-turn rejection, and one-marble constraint under latency.
- Verify `_sync_match_state` correctly updates client UI for all state transitions.

#### 7.4 Online Card Play
- Verify `_request_play_card` RPC works with remote clients.
- Ensure card play animations broadcast to all peers.
- Verify `marble_played` flag is synced correctly.

#### 7.5 Network Integration Tests
- Multi-instance tests for: Host + Client connection via Session Key, full match flow online, snapshot replay accuracy, disconnect/reconnect handling.

---

## 6. Testing & Quality Strategy

### Linter Gates
During Phases 0–5, the GDScript Linter runs in development mode (`Exit 1`): warnings are logged to the console but do not block builds. This allows rapid iteration. In Phase 6, strict mode is enabled (`Exit 2`).

### Manual Verification Protocol
During Phases 3–6, each phase is manually verified in **offline Pass-and-Play mode** (single instance, `OfflineMultiplayerPeer`). Online multiplayer verification is deferred to Phase 7.

### Test Deferral Rationale
GUT tests are deliberately deferred to Phase 6. During the greenfield rebuild, the FSM, UI, and physics architecture are subject to structural change. Writing fine-grained unit tests against frequently moving interfaces increases maintenance burden without yielding proportional confidence. Integration tests written in Phase 6 against the stable final architecture are higher-value.

---

## 7. Code Standards

### Type Annotations
Strict static typing is mandatory for all variables, parameters, and return types. No untyped declarations are permitted.

### SignalBus Observer Pattern
Hardcoded node paths are strictly forbidden for cross-system communication. All cross-system events route through `SignalBus.gd`.

### Authority Guarding
State mutations happen exclusively on the authority peer (`multiplayer.is_server()` guard or `OfflineMultiplayerPeer` host). Every RPC that accepts requests validates the sender and the current state. This pattern applies in both offline and online modes — the same code path executes in both.

### Signal Connection Cleanup
Every node that connects to `SignalBus` or any autoload signal in `_ready()` **must** explicitly disconnect in `_exit_tree()`.

### Input Efficiency
Per-frame physics polling and trajectory preview updates must be gated by state-change checks or numerical delta thresholds.

### Memory Hazard Prevention
Direct raw node references to transient physics objects (marbles, obstacles) are forbidden. Use `WeakRef` or `instance_id` tracking.

### Effect Registration Pattern
New effects are added by registering a `Callable` in `EffectHandler._ready()`. The dispatch methods are never modified to accommodate new effects.

### Snapshot Relay Constants
The client snapshot replay interval must be defined as a named constant derived from the engine physics tick rate:

```gdscript
const SNAPSHOT_CAPTURE_INTERVAL_TICKS: int = 2
const SNAPSHOT_REPLAY_INTERVAL: float = float(SNAPSHOT_CAPTURE_INTERVAL_TICKS) / \
    float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
```

---

## Appendix: Phase Completion Checklist

| Phase | Status | Verification Mode |
|---|---|---|
| Phase 0 — Scaffolding | ✅ Complete | Editor inspection |
| Phase 1 — Lobby & Deck | ✅ Complete | Offline + partial online |
| Phase 2 — Match FSM | ✅ Complete | Offline |
| Phase 3 — Field & Aiming | ✅ Complete | Offline |
| Phase 4 — Card Framework | ✅ Complete | Offline |
| Phase 5 — Effects & Multipliers | ✅ Complete | Offline |
| Phase 6 — Polish & Testing | ⬜ Not Started | Offline |
| Phase 7 — Online Multiplayer | ⬜ Not Started (Deferred) | Host + Client |

---

## Appendix: v5 Changelog

| Change | Rationale |
|---|---|
| Added D18 (Offline-First Development) | Codifies the decision to defer online multiplayer to Phase 7 |
| Added Phase 7 — Online Multiplayer | Consolidates all deferred online features: character-select fix, snapshot replay, RPC validation, integration tests |
| Renumbered 3.8 → 3.8.1 (Client Marble Visual Infrastructure, Done) + deferred 3.8.2–3.8.3 to Phase 7 | 3.8.1 provides the injection point; full online replay requires Phase 7 fixes |
| Added 4.9 (DRAW Phase Automation & HUD) | Mana bottle progress bar, card count box, card deal animation, auto-transition DRAW→PLAY |
| Expanded 4.7 (Card Play Animations) | Card enlarge→shrink→discard animation sequence; card does not remain in PlayArea |
| Phase 4, 5, 6 re-scoped as offline-only | Verification mode changed from "Host + Client" to "Offline Pass-and-Play" |
| Updated D7, D14 with deferred-online annotations | Transparent tracking of what is implemented vs. deferred |
| Updated Phase Completion Checklist | Added Phase 7 row, updated verification mode column |
| Project State Summary updated with Offline-First Development Decision | Documents the why and the guiding principle for code written in Phases 3–6 |
| Merged 5.1 + 5.2 (EffectHandler + Context Objects), renumbered 5.3–5.6 → 5.2–5.5 | Context objects (PlayContext, SimulationContext) implemented as inner classes alongside EffectHandler skeleton in one sub-phase |
| Clarified SIMULATION dispatch trigger | SIMULATION effects fire per knocked-out marble (not per shooter). Shooter excluded on its own shot per D8. Non-shooter marbles emit `marble_knocked_out` on exit. Single shot can trigger multiple SIMULATION dispatches. |
| Revised D4 multiplier reset (SIMULATING entry, not DRAW) | Multiplier accumulates within a single shot's simulation phase and resets at the next SIMULATING entry. This prevents knockouts from one shot from affecting the multiplier of a later shot within the same turn, making multi-knockout shots self-contained. |
| Marked 5.5 AOE Duration Tracking as pre-wired | `tick_aoe_durations()` was already called in `_on_end_turn_entered()` from Phase 3/4 work. No additional wiring needed for Phase 5. |
