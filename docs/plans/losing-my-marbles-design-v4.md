# Losing My Marbles! — Game Design Document
**Version:** 4.0 | **Updated:** May 2026
**Authors:** Keith Ashly Domingo, Adriel Neyro Caraig (FakeThird, iskwipi)

---

## Table of Contents

1. [Executive Overview](#1-executive-overview)
2. [Core Gameplay Loop](#2-core-gameplay-loop)
3. [Player Goals](#3-player-goals)
4. [Game Elements](#4-game-elements)
5. [Game Mechanics](#5-game-mechanics)
6. [Game Systems](#6-game-systems)
7. [Network Architecture](#7-network-architecture)
8. [Genre & Inspirations](#8-genre--inspirations)
9. [Feasibility & Risks](#9-feasibility--risks)
10. [Scope Management](#10-scope-management)

---

## 1. Executive Overview

**Title:** Losing My Marbles!
**Tagline:** "For all the marbles. Just flick."
**Hook:** A turn-based, multiplayer deck-builder reimagining of the Filipino game *Holen*. Players build strategic card hands to manipulate the playing field, then execute precise marble shots in a simulated 2D physics environment. Every card played sets up the shot; every shot determines what cards matter next.

**Platform:** PC Desktop (primary). Mobile and Web supported via GL Compatibility rendering.
**Players:** 2 players (LAN multiplayer via Session Keys). Local Offline supported via pass-and-play.
**Turn Structure:** Fully turn-based. One player acts at a time. No real-time elements during decision phases.

### Design Pillars

- **Tactical depth from simple inputs.** The depth comes entirely from card choices made before the shot and the fine-tuning of aim and flick strength.
- **Physics as the great equalizer.** No amount of card advantage guarantees a shot outcome. Genuine uncertainty must be planned around.
- **Mayhem is the point.** Cards are designed to cause chaos — terrain shifts, sticky traps, marble swaps, and gravity anomalies.

---

## 2. Core Gameplay Loop

The loop is structured around a single player's turn, divided into distinct phases. The player controls *when* to advance between phases, with the exception of Simulating (which runs uninterrupted). After a Simulating phase resolves, the player always returns to the Play phase, where they may choose to take another shot, play more cards, or end their turn.

```
a) DRAW        → Player draws cards from their private deck; mana is generated.

b) PLAY        → Player spends mana to play cards (altering the field, preparing
                  the shot). The player then chooses one of two branches:
                  → Branch A: Advance to AIM to take a shot.
                  → Branch B: End their turn voluntarily (END TURN).

c) AIM         → Player fine-tunes aim (map rotation + ball angle offset) and
                  sets the flick strength slider. A trajectory preview arc is
                  rendered. Player executes the shot to advance to SIMULATING.

d) SIMULATING  → Physics simulation runs uninterruptibly. Marbles bounce, stick,
                  and are knocked out. Knocked-out marble effects trigger. Multiplier
                  thresholds activate if enough marbles are knocked out. Once the
                  field settles, the turn automatically returns to PLAY (Branch A
                  above) — the active player may now play more cards or take
                  another shot before choosing to end their turn.

e) END TURN    → Reached only from the PLAY phase via Branch B. Unplayed cards
                  reshuffle into the private deck; remaining mana is discarded.
                  AOE durations tick down. The next player's turn begins.
```

A player may cycle through PLAY → AIM → SIMULATING as many times as they can afford (limited by mana and available marble cards). The decision to end the turn is always voluntary and always made from within the PLAY phase.

---

## 3. Player Goals

### Before a Match
- **Character Selection:** Choose a character whose Mana and Power stats, alongside their exclusive card pool, fit the intended strategy.
- **Deck Building (Private):** Construct a private deck with a clear win condition (field control, AOE stacking, high-burst damage). The private deck may contain any card type.
- **Deck Building (Public):** Fill a fixed-size public deck with owned Marble cards. These will populate the shared field pool at match start.

### During a Match
- Knock opposing marbles off the field to trigger their passive effects and deal damage to the opponent.
- Protect your own health total from reaching zero.
- Manipulate physics (gravity, stickiness, friction, elasticity) using Terrain and AOE cards.
- Execute precise shots using the flick slider combined with the character's Power modifier.

### Win Condition
A player is eliminated when their health reaches zero. The last player with health remaining wins.

---

## 4. Game Elements

### 4.1 The Map & Field State

The playing field where all marbles and obstacles exist and interact. All physics properties are calculated using the additive stacking formula:

> **Effective Value = Map Base + Terrain Delta + Sum(Active AOE Deltas)**

| Property | Description |
|---|---|
| Friction | How quickly moving bodies lose velocity over distance |
| Stickiness | Environmental dampening (e.g., honey traps) that drastically limits marble movement; applied as `linear_damp` on `RigidBody2D` instances |
| Gravity | Directional pull magnitude and vector (or anomalies) applied via `Area2D` gravity override; affects marble trajectory |
| Elasticity | Bounciness of the field boundaries; affects collision impulse response |
| Weight | Per-marble mass modifier. Affects how marbles transfer kinetic energy on collision and how strongly gravity and friction act on them. Stored in `PhysicsObjectData` and applied to `RigidBody2D.mass` |

The `FieldStateManager` system is responsible for maintaining this stack and pushing recalculated values to the physics engine whenever any layer changes.

### 4.2 The Character

Each player selects one character before a match begins.

| Property | Description |
|---|---|
| Health | Starting life total; reaching zero means elimination |
| Mana | Amount generated at the start of each turn; determines how many cards can be played |
| Power | A passive stat added to the flick slider value at shot execution to determine the final impulse magnitude. It is **not** a player-controlled input |
| Exclusive Cards | A set of cards only accessible when this character is selected |

### 4.3 The Decks

#### Public Deck (Shared Pool)
- Fixed size for all players. Players populate it exclusively with owned Marble cards before the match.
- At match start, the system secretly combines all players' public decks into a single shared marble pool and shuffles it.
- Marbles from this pool populate the field initially and refill it whenever the field runs empty during play.
- **Pool Refill:** When the shared pool is exhausted, all previously ejected or used marbles are returned to the pool and reshuffled — mirroring the private deck's reshuffle behavior. The match never ends due to an empty pool.

#### Private Deck
- Contains any mixture of card types: Marbles, Power-Ups, Tricks, Terrains, and Area-of-Effects.
- The player draws from this deck at the start of each turn.
- **Discard Pile:** Played cards and consumed cards go to a separate discard pile, not back into the private deck. When the private deck is empty during a draw, the discard pile is immediately reshuffled into a new private deck before drawing continues.
- If both the private deck and discard pile are empty, the player draws only what is available (no crash or forced draw from an empty source).
- Never visible to opponents (hidden information).

### 4.4 Physics Objects (Marbles & Obstacles)

Both marbles and obstacles share underlying physics properties via `PhysicsObjectData`, allowing them to interact within the physics engine. They are decoupled from card logic.

- **Marbles:** Spawned from the shared pool. They **do not track ownership**. Physics properties (friction, stickiness, gravity modifier, elasticity, weight) are read from the `PhysicsObjectData` component at spawn.
- **Obstacles:** Static or dynamic non-card objects placed by the Map or Trick cards (e.g., bumpers, walls). Also use `PhysicsObjectData` to define their physical characteristics.

### 4.5 Cards & The Effect System

Cards are the primary strategic resource. They do not contain hardcoded game logic; instead, they hold an array of `EffectData` resources. Each `EffectData` entry is an isolated command defined by four fields:

| Field | Type | Description |
|---|---|---|
| `effect_id` | `String` | Internal identifier for the logic to dispatch (e.g., `"deal_damage"`, `"spawn_obstacle"`, `"set_linear_damp"`) |
| `value` | `float` | Numerical magnitude of the effect. Positive or negative values encode whether the effect is beneficial or harmful (e.g., `-5.0` health is damage; `+5.0` health is healing) |
| `target` | `TargetEnum` | Who or what receives the effect. See the Target Enum table below |
| `trigger` | `TriggerEnum` | The game phase in which this effect fires. Either `PLAY` or `SIMULATION` |

#### TriggerEnum

| Value | Fires When |
|---|---|
| `PLAY` | The card is played from the player's hand during the PLAY phase |
| `SIMULATION` | A marble is knocked off the field during the SIMULATING phase |

#### TargetEnum

| Value | Valid Trigger | Who or What Is Affected |
|---|---|---|
| `SELF` | `PLAY` | The player who played the card (their health, mana, or stats) |
| `OPPONENT` | `PLAY` | The opposing player (their health, mana, or stats) |
| `CURR_MARBLE` | `PLAY` | The marble currently designated as the shooting marble; modifies its `PhysicsObjectData` for the upcoming shot |
| `KNOCKER` | `SIMULATION` | The **player** whose shot caused the marble to be knocked out |
| `KNOCKER_OPP` | `SIMULATION` | The **player** whose marble was knocked out |
| `BOTH` | `PLAY` or `SIMULATION` | Both players simultaneously |
| `FIELD_MAP` | `PLAY` or `SIMULATION` | The field physics properties (updates the `FieldStateManager` stack) |
| `FIELD_MARBLES` | `PLAY` or `SIMULATION` | All marbles currently on the field |

#### How This Handles Marble Card Duality

A Marble card's `effects` array may contain entries with *both* trigger values:
- `PLAY`-triggered effects (with `CURR_MARBLE`, `SELF`, or `FIELD_MAP` targets) fire the moment the card is played from hand, modifying the upcoming shot.
- `SIMULATION`-triggered effects (with `KNOCKER`, `KNOCKER_OPP`, or `FIELD_MARBLES` targets) fire automatically when that marble is knocked off the field, regardless of how it arrived there.

This means a single Marble resource definition handles both its in-hand behavior (active: modifying the shot) and its on-field behavior (passive: triggering effects on knockoff) without any schema duplication.

### 4.6 Card Types

1. **MARBLE:**
   - Played from hand during the PLAY phase to designate the marble the player will shoot. Its `PLAY`-triggered effects apply immediately (e.g., modifying physics of the shooting marble).
   - As a field marble in the shared pool, its `SIMULATION`-triggered effects automatically fire when it is knocked off the field.
   - **Constraint:** Only one Marble card may be played per shot cycle. Once a Marble card has been played, the player cannot play another Marble card until after the next SIMULATING phase concludes.

2. **POWER_UP:**
   - Buffs or modifies the current shooting marble or the active player (e.g., increase power for one shot, add a ricochet modifier).

3. **TRICK:**
   - Instant-execution effects targeting the field, decks, or game state (e.g., swap field marbles, spawn obstacles, discard opponent's hand cards).

4. **TERRAIN:**
   - A global field modifier. Only one Terrain card may be active at a time. Playing a new Terrain replaces the previous one. Acts as a delta on Map base properties for the remainder of the match (or until overridden).

5. **AREA_OF_EFFECT (AOE):**
   - Persists for a set number of turns.
   - Modifies field physics properties locally or globally.
   - Multiple AOE cards stack additively alongside the active Terrain and Map base in the `FieldStateManager`.

---

## 5. Game Mechanics

### 5.1 Match Initialization

1. A map is randomly selected. Its base surface properties are applied immediately to the `FieldStateManager`.
2. The system merges all players' public decks into a single shared marble pool and shuffles it.
3. A set number of marbles are drawn from the pool and placed randomly on the field using an anti-overlap spawn algorithm.
4. Turn order is randomly determined and broadcast to both players.
5. Players receive starting health. Mana begins at zero.

### 5.2 Player Turn (Detailed)

#### DRAW Phase
- The active player draws cards from their private deck up to their hand limit.
- The mana pool fills to the character's Mana stat value.
- If the private deck is empty, the discard pile is immediately shuffled into a new private deck before drawing continues.
- If both the private deck and discard pile are empty, the player draws only whatever cards remain available.

#### PLAY Phase
- The player may play cards in any order, as long as sufficient mana remains.
- Card play animations trigger on both players' screens before the effect resolves.
- **Marble card constraint:** Only one Marble card may be played per shot cycle. Once played, no further Marble cards can be played until after the next SIMULATING phase. The UI provides a visual hint directing the player to advance to the AIM phase once a Marble card is in play.
- Only one TERRAIN card may be active at a time; playing a new one replaces the current one.
- AOE cards stack on the `FieldStateManager` stack for their duration.
- When ready, the player chooses one of two actions:
  - **Advance to AIM:** Begin the aiming phase for the current shot.
  - **End Turn:** Voluntarily conclude the turn without taking another shot.

#### AIM Phase
- **Map Rotation:** The player rotates the entire map environment to find their preferred global angle.
- **Fine-Tune Angle:** The player adjusts a secondary control to precisely tune the launch direction of the ball.
- **Flick Slider:** The player sets the shot strength. The final impulse applied to the marble is `slider_value + character.power`. Character Power is a passive stat — it is not adjustable by the player during this phase.
- **Trajectory Preview:** A raycast-based arc is rendered in real-time showing the marble's predicted initial path and the angle of the first bounce. The preview updates only when the slider value changes by more than `0.01` from the previous value (throttled to prevent per-frame recalculation).
- The player executes the shot to advance to SIMULATING.

#### SIMULATING Phase
- The physics simulation runs uninterruptibly until all marbles have settled or exited the field.
- If the shooting marble does not exit the field boundary, it sheds its "shooter" designation and permanently joins the shared field marble pool as a standard field marble.
- If the shooting marble exits the field boundary, it is despawned. Its `SIMULATION`-triggered effects do **not** fire for out-of-bounds exits.
- For every marble knocked off the field, its `SIMULATION`-triggered effects are dispatched by the `EffectHandler`, routing to the correct target:
  - `KNOCKER` → the player who took the shot this turn.
  - `KNOCKER_OPP` → the player whose marble was knocked out.
  - `BOTH` / `FIELD_MAP` / `FIELD_MARBLES` → as defined.
- The Knockout Multiplier tracks how many marbles are knocked out during this simulation step. Reaching threshold tiers (e.g., 3, 5, 7 knockouts) scales the `value` of subsequently dispatched effects for the remainder of the turn.
- If the field is empty after simulation, new marbles are drawn from the shared pool (refilling the pool first if it is exhausted).
- After the simulation fully resolves, control **automatically returns to the PLAY phase**. The active player may play more cards, take another shot, or end their turn.

#### END TURN
- Reached voluntarily from the PLAY phase.
- All unplayed hand cards are shuffled back into the private deck.
- Unused mana is discarded.
- AOE durations tick down by one. Expired AOEs are removed from the `FieldStateManager` stack, which recalculates and pushes updated values to the physics engine.
- The next player's DRAW phase begins.

### 5.3 Offline / Pass-and-Play

Single-player mode allows one user to control both players locally. Because hands and private decks are hidden information, the game invokes a **Pass Device Screen** at every turn transition to prevent accidental intelligence leakage.

The Pass Device Screen uses the same visual language and sliding animation as the standard Transition Screen but is modified for this context: it displays a "Pass the device to [Player Name]" prompt in place of the loading marble, and it requires the receiving player to actively press a confirmation button before the board and UI are revealed. No game state is visible until confirmation is given.

---

## 6. Game Systems

### 6.1 State Machine

Governs the flow of a match and enforces all phase transitions. The server is the sole authority; clients request state changes and receive the confirmed new state via RPC.

```
                ┌─────────────────────────────┐
                │                             │
Init → Draw → Play ──────→ Aim → Simulating ──┘
               │
               └──────→ EndTurn → (Next Player's Draw)
```

- From **Play**, the player may branch to **Aim** (take a shot) or **EndTurn** (conclude the turn).
- From **Simulating**, the state always returns to **Play** automatically once physics resolves.
- The **EndTurn** transition is only reachable from **Play**.

### 6.2 Physics Engine & Field State Manager

Simulates all physical interactions via native Godot 2D physics primitives:

- **FieldStateManager:** Aggregates all active physics modifiers into a single effective value before pushing updates to the engine. It never updates physics properties per-tick; it only recalculates when a layer changes (a card is played, an AOE expires, etc.).
- **Stickiness:** Applied via dynamic `linear_damp` updates on `RigidBody2D` nodes.
- **Gravity:** Applied by wrapping the field in an `Area2D` with `gravity_override = true` and modulating its directional vector and magnitude.
- **Weight:** Stored in `PhysicsObjectData` per marble or obstacle, applied to `RigidBody2D.mass` at spawn.
- **Elasticity:** Applied via `PhysicsObjectData.elasticity` to the `PhysicsMaterial` of relevant collision bodies.

#### Client Physics Display

Physics simulation runs exclusively on the server. However, clients must still render a visually coherent simulation playback. This is achieved through a **Server-Driven Snapshot Replay** system:

1. During the SIMULATING phase, the server captures the position and velocity of every marble at a fixed interval (every 2 physics ticks, approximately 33 ms at 60 Hz physics).
2. When the simulation fully resolves, the server sends the complete snapshot buffer — along with the authoritative final marble positions — to all clients via a single reliable RPC.
3. Each client receives the buffer and replays it locally at the same tick interval, interpolating marble positions between snapshots to produce smooth visual motion.
4. After the replay completes, the client applies the authoritative final positions from the server, correcting any minor visual drift.

This approach guarantees that server truth is never compromised while clients receive a smooth, watchable representation of what occurred. The snapshot buffer is only transmitted once simulation is complete; real-time streaming is unnecessary in a turn-based context.

### 6.3 Effect Handler (Command Pattern)

A stateless dispatcher using a `Callable` registry keyed by `effect_id` string.

- **PLAY-phase dispatch:** The `EffectHandler` iterates over a card's `effects` array and executes only entries where `trigger == PLAY`, routing the effect to the appropriate target.
- **SIMULATION-phase dispatch:** When a marble is knocked out, the `EffectHandler` iterates that marble's `effects` array and executes only entries where `trigger == SIMULATION`, routing to `KNOCKER`, `KNOCKER_OPP`, `BOTH`, `FIELD_MAP`, or `FIELD_MARBLES` as specified.
- Adding a new effect means registering a new `Callable` in the registry. The `EffectHandler` itself is never modified.

### 6.4 Card System

Manages private deck draw and reshuffle logic, discard pile state, mana verification, card lifecycle, and the one-marble-per-shot constraint.

- **Discard Pile:** Maintained as a separate pile from the draw deck. Played cards move to the discard pile, not back into the deck. When the draw deck is empty, the discard pile is shuffled and becomes the new draw deck.
- **Marble Constraint Tracking:** The Card System tracks a per-turn flag, `marble_played: bool`. This flag is set to `true` when a Marble card is played and reset to `false` after each SIMULATING phase concludes. The server rejects any attempt to play a second Marble card while this flag is `true`.
- The server maintains an authoritative record of all players' hands, decks, and discard piles to prevent cheating or desyncs.

### 6.5 User Interfaces

- **Matchmaking / Lobby:** Interface to share or input the 6-character Session Key for LAN discovery.
- **Deck Builder:** Pre-match interface to populate the fixed-size Public Marble pool and craft the Private Deck.
- **Character Select:** Pre-match interface for selecting a character and reviewing their stats and exclusive card pool.
- **Pass Device Screen:** A turn-transition screen for offline pass-and-play, styled after the Transition Screen. Displays a "Pass the device to [Player Name]" prompt and requires an explicit confirmation tap before the game board is revealed.

### 6.6 HUD Specification

The HUD is organized across three primary game views (Main, Field, Flick) and two secondary views (Action Log, Transition/Loading). All primary views share a **Menu Button** anchored at the top-center.

#### Menu Overlay (Accessible from All Primary Views)
A floating modal panel triggered by the top-center Menu Button. Contains: Audio settings, Video settings, and a Surrender option.

---

#### Main View (Active During DRAW and PLAY Phases)

The primary game view. Rendered in first-person perspective — the player's own character is visible in the mid-foreground, the opponent is visible in the background distance, and the player's hand is spread across the bottom foreground.

| Zone | Element | Details |
|---|---|---|
| Top-Left | Player status | Health bar and avatar for the local player |
| Top-Center | Menu Button | Opens the Menu Overlay |
| Top-Right | Opponent status | Health bar and avatar for the opponent |
| Left Panel | Contextual info | Active effects list (scrollable); Action Log button; View Field button |
| Right Panel | Phase action buttons | Contextual button set, animated per state (see below) |
| Bottom-Left | Character vitals | Mana pool display and other character property visuals |
| Bottom-Right | Deck display | Visual representation of remaining deck count |
| Bottom-Center | Hand display | Fanned card hand in the foreground; cards are drag-and-drop interactive |

**Contextual Right-Panel Buttons (Animated State Transitions):**
The right panel buttons change depending on the current FSM state. When the state changes, the current button set animates off-screen (slides out), and the new button set animates in. This provides clear visual feedback of the current phase.

| FSM State | Visible Buttons |
|---|---|
| DRAW | (No action buttons; draw resolves automatically) |
| PLAY | "Aim" (advance to AIM), "End Turn" (go to END TURN) |
| PLAY (after Marble card played) | "Aim" (highlighted/pulsing as a hint), "End Turn" |
| AIM | "Execute" (fire the marble), "Back" (return to PLAY) |

---

#### Action Log View (Accessible from Main View Left Panel)

A dedicated overlay or slide-in panel. Displays a scrollable chronological list of all significant match events. Each entry shows a card or event icon on the left and descriptive text on the right. Log entries include: cards played, marbles knocked out, passive effects triggered, multiplier thresholds reached, and turn transitions.

---

#### Transition / Loading View

Used for transitions between major systems (lobby to match loading, system handoffs). Features a horizontal sliding animation — content panels sweep in from the sides — with a rolling marble animating in the center and a "Loading…" label beneath it. The screen advances automatically when the transition completes.

---

#### Field View (Board Overview)

A top-down orthographic view of the full circular playing field. Used for spatial awareness before committing to the AIM phase.

| Zone | Element | Details |
|---|---|---|
| Center | Playing field | Circular field boundary with all marbles and obstacles visible |
| Top-Left | Active Terrain card | Small card UI; clickable to open a full-detail inspection panel |
| Top-Center | Menu Button | Opens the Menu Overlay |
| Top-Right | Game state summary | Current phase and turn indicator |
| Bottom-Left | Active Effect cards | Small card stack; clickable to inspect individual active effects |
| Bottom-Right | Navigation buttons | **Flick Button** (advances to Flick View) stacked below **Back Button** (returns to Main View) |

---

#### Flick View (Active During AIM Phase)

A zoomed-in perspective of the field showing a partial arc cross-section of the bowl. Marbles and obstacles are visible inside the arc. A trajectory prediction arc is rendered from the shooting marble's position through its expected first bounce.

| Zone | Element | Details |
|---|---|---|
| Center | Zoomed field arc | Partial arc cross-section with marbles, obstacles, and trajectory prediction line |
| Top-Left | Active Terrain card | Same as Field View; clickable for inspection |
| Top-Center | Menu Button | Opens the Menu Overlay |
| Top-Right | Flick Strength Slider | Controls `slider_value` component of the shot impulse |
| Bottom-Left | Active Effect cards | Same as Field View; clickable for inspection |
| Bottom-Right | Execute Flick Button | Fires the shot and advances to SIMULATING (replaces the "Back/Flick" buttons from Field View) |

---

## 7. Network Architecture

### 7.1 Model

Server-authoritative host-client model over **ENet (UDP)**. One player hosts (running server logic and a local client); the other connects as a pure client.

### 7.2 Session Discovery

The game exclusively uses **6-character Session Keys** broadcast via UDP for LAN discovery. Direct IP connection fields are intentionally absent to simplify UX and reduce network exposure risk.

### 7.3 Authority Model

The server dictates all critical game states:
- Match phases and turn order.
- Health, mana, and multiplier thresholds.
- Card play validity (including the marble constraint flag), effect execution, and discard pile state.
- Physics simulation outcomes (run on server; results delivered to clients via snapshot relay).

### 7.4 RPC Communication Pattern

| Direction | RPC Type | Purpose |
|---|---|---|
| Server → All clients | `@rpc("authority", "call_local")` | State sync, stat sync, confirmed card plays, card animations, physics snapshot relay |
| Client → Server | `@rpc("any_peer", "call_local")` | Phase advance requests, card play requests |
| Lateral (UI only) | Signals | Local drag-and-drop, slider adjustments, trajectory preview updates |

### 7.5 Offline / Single Player

Utilizes Godot's `OfflineMultiplayerPeer`. No network traffic is generated. All RPC calls execute locally. The Pass Device Screen handles turn isolation between players sharing one device.

### 7.6 Physics Snapshot Relay

The physics simulation runs on the server only. Clients receive a replay buffer for visual display:

1. **Server (during SIMULATING):** Captures marble positions and velocities every 2 physics ticks and appends each frame to a snapshot buffer.
2. **Server (on simulation end):** Transmits the complete snapshot buffer plus the authoritative final state to all clients via a single reliable RPC (`_sync_snapshot_replay`).
3. **Client (on receipt):** Replays the buffer locally at the matching tick interval, interpolating between frames. After replay concludes, applies the authoritative final state to correct any visual drift.
4. **Buffer size:** With up to 15 marbles and a 5-second maximum simulation window, the buffer remains well within acceptable RPC payload limits.

---

## 8. Genre & Inspirations

**Primary Genre:** Turn-Based Strategy / Deck Builder
**Secondary:** Simulated Physics, Casual Competitive

| Reference | What We Take |
|---|---|
| **Kabuto Park** | Overall visual vibe; the sensation of marbles as characters with personality |
| **Peglin** | Marble varieties with inherent physics properties interacting with environmental elements |
| **Balatro** | The setup-and-payoff structure; cascading multipliers turning good setups into great payouts |
| **Pokémon TCGP / Slay the Spire** | Deck construction as strategic preparation; variance producing different viable tactics |

**What Makes This Different:**
Unlike purely card-based games, perfect card play does not guarantee perfect outcomes due to the physics layer. Unlike purely physics-based games, the card layer provides deep pre-shot decisions, AOE layering, and environmental manipulation.

---

## 9. Feasibility & Risks

### 9.1 Technical Risks

**Physics State Stacking (Stickiness / Gravity / Weight)**
Dynamically calculating and applying physics overwrites across multiple overlapping AOEs and Terrain cards can lead to jitter or desync if applied improperly.
*Mitigation:* The `FieldStateManager` aggregates all values into a single computed delta before pushing updates to `linear_damp`, `Area2D` gravity parameters, or `RigidBody2D.mass`. Updates are event-driven, never per-tick.

**Network Physics Synchronization**
Ensuring clients receive a visually coherent simulation replay while maintaining server authority.
*Mitigation:* The snapshot relay system transmits the full simulation replay buffer in one reliable RPC after simulation completes. Client playback is decoupled from server execution and corrected by authoritative final state after replay.

**Card Balance with Multipliers**
High-tier multipliers combined with powerful AOE effects risk exponential numeric scaling.
*Mitigation:* The Multiplier tier table is a data dictionary editable without recompilation. Effect magnitudes are generic `float` values in `.tres` resources, adjustable at any time.

**Effect Trigger Misrouting**
Dispatching an effect with a `PLAY`-phase target during the `SIMULATION` phase (or vice versa) could cause unintended game state mutations.
*Mitigation:* The `EffectHandler` validates `trigger` context before dispatch. Effects whose `trigger` does not match the current phase context are silently skipped and logged as a warning. The `GDScript Linter` and GUT integration tests cover trigger/target validity.

### 9.2 Feasibility Milestones

| Phase | Target |
|---|---|
| **Phase 1** | Session Key network lobby, Character Select, and Deck Builder UIs functional. |
| **Phase 3** | Functional Map simulation, FieldStateManager (Stickiness/Gravity/Weight), Aiming inputs, trajectory raycast, and snapshot relay system. |
| **Phase 5** | Fully integrated Effect Handler with trigger-context dispatch, Discard Pile, one-marble constraint, Card plays, and Multiplier System. |
| **Phase 6** | End-to-end Pass-and-Play and Multiplayer verification; strict-mode linter compliance. |

---

## 10. Scope Management

### 10.1 Minimum Viable Product (MVP)
A complete, playable 2-player game demonstrating all core rebuilt mechanics:
- Network Lobby (Session Key) and Pass-and-Play Offline mode.
- Character Select and Deck Builder UIs.
- 2 sample Characters with different Mana and Power stats.
- All 5 Card Types (Marble, Power-Up, Trick, Terrain, AOE).
- Physics Simulation with additive stacking (Friction, Stickiness, Gravity, Weight, Elasticity).
- Fully functional AIM phase (Map Rotation, Fine-Tune Angle, Flick Slider, trajectory raycast preview).
- Knockout Multiplier System.
- Un-exited marble becomes a field marble; out-of-bounds marble is despawned.
- Discard Pile and private deck reshuffle.
- One-marble-per-shot constraint with UI hint.
- Client snapshot replay for the SIMULATING phase.

### 10.2 Stretch Goals
- Expanded card library and diverse Maps with baked-in physical obstacles.
- Deep visual polish (particle effects, screen shakes on heavy collisions).
- Match history and post-game statistics screen.
- Enhanced sound design corresponding to varying impact forces.

### 10.3 Maximum Final Product (Long-Term Vision)
- Online multiplayer via dedicated cloud matchmaking.
- Player accounts with persistent card collections.
- Ranked matchmaking and seasonal competitive play.
- Progressive PvE AI campaigns.

### 10.4 Explicitly Excluded (All Scopes)
- Direct IP entry for network connections.
- 3D physics simulation.
- Real-time action gameplay.
- AI Opponent Behavior Trees (Beehive).
- Cloud Account / External Server persistence (GDSync).
- Session Key display within the in-match HUD.