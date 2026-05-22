# About `losing-my-marbles` <img src="https://github.com/user-attachments/assets/09a2258c-3c36-44fd-9128-05e13097149c" width="4%" align="top">

<img width="49%" alt="Screenshot 2026-05-19 213351" src="https://github.com/user-attachments/assets/714d4ad4-aa62-4d2b-b3a5-2510f1955bc2" />
<img width="49%" alt="Screenshot 2026-05-19 213451" src="https://github.com/user-attachments/assets/e7428ea0-41a1-4645-a90a-015bcd15c4e5" />

# Creator 
- Keith Ashly Domingo
- Adriel Neyro Caraig

**Date: May 19, 2026**

# Description

## Summary
**`losing-my-marbles`** is a turn-based, Pass-to-Play deck-builder reimagining of the Filipino game *Holen* that blends precise marble aiming with creative card strategy. Two players build strategic card hands to manipulate the playing field, then execute precise marble shots in a simulated 2D physics environment where every trick causes mayhem and every shot causes chaos! 
```
Created as the Final Portfolio for CMSC 197 Game Design and Development.
```

## Rationale
**`losing-my-marbles`** is a culmination of all that was learned by the students in CMSC 197 - Game Design and Development. It was the final portfolio designed to challenge what the students have learned so they built the a game that takes a classic game played in the Philippines, *Holens*, and from that built their own unique recreation of it, that mixes chaos, fun, and the nostalgia of when we were young.

# Features
**`losing-my-marbles`** offers both strategic and chaotic mechanics to maximize fun and unpredictability:

- **Offline Pass-and-Play** mode for two players on one device, with a Pass Device Screen preventing hidden-information leakage between turns
- **Full Deck-Builder** with two separate decks: a private hand deck (any card type) and a public marble pool (marble cards only) that merges with the opponent's at match start
- **Five Card Types** — Marbles, Power-Ups, Tricks, Terrains, and Area-of-Effects — each interacting with the physics engine or the opponent directly
- **Additive Physics Layering** — field properties (friction, gravity, stickiness, elasticity, weight) stack across Map Base, active Terrain, and all live AOE effects via `FieldStateManager`
- **Precise Aiming System** — three independent inputs: Map Rotation, Fine-Tune Angle, and Flick Slider; trajectory preview updates in real-time
- **Knockout Multiplier System** — chain knockouts within a single simulation phase to scale effect values up to 3×
- **Marble Duality** — every marble card has both a PLAY-phase effect (modifying the shot) and a SIMULATION-phase effect (triggering on knockout), defined in a single resource
- **Discard Pile & Reshuffle** — played cards move to a discard pile and cycle back when the draw deck runs dry
- **One-Marble-per-Shot Constraint** — enforced server-side; the UI hints the player toward the AIM phase once a marble is in play
- **Server-Authoritative Architecture** — all state mutations run on the authority peer; RPC stubs are already wired for deferred online multiplayer injection

# Game Mechanic

## Core Loop
Players alternate turns. Each turn is divided into distinct phases the player controls, except Simulating (which runs uninterruptibly):

| Phase | What Happens |
|---|---|
| **DRAW** | Player draws cards from their private deck; mana regenerates automatically |
| **PLAY** | Player spends mana to play cards, then branches: advance to AIM or end the turn |
| **AIM** | Player sets Map Rotation, Fine-Tune Angle, and Flick Slider; executes the shot |
| **SIMULATING** | Physics runs uninterrupted; marbles bounce, knock out, and trigger effects; control returns to PLAY automatically |
| **END TURN** | Unplayed cards reshuffle; AOE durations tick down; the opponent's DRAW begins |

A player may cycle through **PLAY → AIM → SIMULATING** as many times as mana allows before voluntarily ending their turn.

## Card Types

| Type | What It Does |
|---|---|
| **Marble** | Designates the shooting marble; PLAY effects modify the shot, SIMULATION effects trigger on knockout |
| **Power-Up** | Buffs the active player — instant health, mana restoration, or stat boosts |
| **Trick** | Instant field or opponent effects — drain mana, clear terrain, restore mana to both players |
| **Terrain** | Sets a global field modifier (gravity shift, friction change); only one active at a time |
| **Area-of-Effect** | Stacks additional physics deltas on the field for a fixed number of turns |

## Knockout Multiplier

| Knockouts This Turn | Multiplier |
|---|---|
| 0–2 | 1.0× |
| 3–4 | 1.5× |
| 5–6 | 2.0× |
| 7+ | 3.0× |

## Win Condition
A player is eliminated when their **health reaches zero**. The last player standing wins.

# Controls Documentation

## Desktop

| Input | Action |
|---|---|
| Drag card to center | Play card from hand |
| Flick Slider | Set shot strength (0–10) |
| Map Rotation Buttons (hold) | Rotate the entire field |
| Fine-Tune Buttons (hold) | Adjust aim angle precisely |
| Aim Button | Advance to AIM phase |
| Execute Button | Fire the marble |
| Back Button | Return to PLAY phase from AIM |
| End Turn Button | Voluntarily conclude the turn |

# Limitations and Issues

## Known Issues

**1. Online Multiplayer — Character Select → Match Transition**
The online multiplayer flow does not currently progress past the character selection screen. The `match_started` signal fails to trigger after both host and client select characters, preventing the transition to the match scene. Root cause investigation is deferred to Phase 7 to avoid blocking feature development in offline mode.

## Unimplemented Features
The following features are scheduled for post-submission phases and are not present in the current build:

- **Online Multiplayer** — fixing the character-select → match transition, enabling full client snapshot replay, and online RPC validation
- **GUT Integration Tests** — end-to-end automated test suite for turn FSM, discard pile lifecycle, physics stacking, and multiplier scaling
- **Strict Linter Compliance** — GDScript Linter currently runs in warnings-only mode; strict mode is deferred to Phase 6
- **Per-Marble Friction** — per-marble `friction` values are currently overridden by the global `linear_damp` from `FieldStateManager`; restoring per-marble differentiation requires removing or modifying the global override in `push_to_engine()`
- **Obstacle Cards** — static and dynamic non-card obstacles placeable by Trick cards
- **Stickiness Physics** — `stickiness` field exists in `PhysicsObjectData` but is not yet applied by the engine; deferred to a later phase

# Graphics and Tools
- Game Engine: [Godot](https://godotengine.org/download/windows/)
- Pixel Art: [Pixilart Studio](https://www.pixilart.com/)
- Audio Editing: [Audacity](https://www.audacityteam.org)

# Credits

Credits to the artists who made sprites used in this project:
- Itch.io Game Assets: [Itch.io](https://itch.io/game-assets)
- Craftpix Game Assets: [Craftpix](https://craftpix.net/)

Credits to the creators of free sound effects used in this project:
- Pixabay Sound Effects: [Pixabay](https://pixabay.com/)

A direct link to each respective download is provided in [CREDITS.md](CREDITS.md). These artists indirectly supported this project's success!

Sprites not credited were custom-built by the creators and are free for personal, non-commercial use.

# Getting Started: Players
To properly try and experience **`losing-my-marbles`**, follow these steps:
1. Download the exe file in the [releases section](https://github.com/FakeSquiffy-Games/losing-my-marbles/releases) of the repository.
2. Run the exe and enjoy the game!

# License
- This game was created passionately as a machine problem for CMSC 197 - Game Design and Development.
- **All credits for sprites and original inspiration go to their respective owners.**
- Sprites not credited were custom-built by the creators and are free for personal, non-commercial use.



