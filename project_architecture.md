# TD-Prototype: Project Architecture & Systems Definitions

**Master Document** for project-specific constraints, system architectures, and design patterns.
This document complements **`architecture.md`** (the Agent Persona/Workflow) by defining **WHAT** we are building and **HOW** specific systems work.

## 1. Game Identity & Core Loop
- **Genre:** Top-Down Tower Defense with Deckbuilding mechanics.
- **Visual Style:** DAW-inspired (Digital Audio Workstation) UI, minimalist meters, and clean grid-based aesthetics.
- **Core Loop:**
  1.  **Draft phase:** Player builds a deck of Tower and Buff cards.
  2.  **Wave phase:** Enemies spawn along defined paths.
  3.  **Action phase:** Player uses Energy/Gold to play cards (Build Towers, Buff Towers) to stop enemies.

## 2. UI/UX Standards
- **Viewport Resolution:** `1536x1024` (Native Game Area) scaled to `1920x1080` screen.
- **Layout:** "DAW-Style" Layout.
  -   **Top Bar:** Global stats (Health, Gold, Wave).
  -   **Left Sidebar:** Card Hand & Deck controls.
  -   **Right Sidebar:** Selection/Inspector details.
  -   **Center:** The Level Viewport (24x16 tiles of 64px).

## 3. Technical Standards

### File System
- **Entities:** `Entities/Towers`, `Entities/Enemies`, `Entities/Projectiles`.
- **Resources:** `Config/Cards`, `Config/Decks`, `Config/Levels`, `Config/Towers`.
- **Systems:** `Systems/build_manager.gd`, `Systems/game_manager.gd`.

### Physics Layers (Collision)
- **Layer 1:** Towers
- **Layer 2:** Enemy Position (Movement collision)
- **Layer 3:** Enemy Hitbox (Projectiles target this)
- **Layer 4:** Projectiles

### Naming Conventions (Strict)
- **Enemies:** `[variant]_[action]_[direction]` (e.g., `red_move_south_west`).
- **Towers:** `level_01_shoot`, `level_01_idle`.

## 4. Systems Overview

### 4.1. Cards & Deck
**Resources:** `CardData`, `DeckData`
- **BuildTowerEffect:** Links to `TowerData` + `TowerScene`. Places a permanent structure.
- **BuffTowerEffect:** Links to stats/status effects. Applies temporary buffs to existing towers.
- **Hand Logic:** Controlled by `CardsHUD`. Can be "Condensed" (minimized) or "Expanded".

### 4.2. Towers
**Base Scene:** `TemplateTower` (`template_tower.tscn`)
**Data Driven:** `TowerData` containing array of `TowerLevelData`.
- **Architecture:** Towers do NOT calculate physics in `_process`. They wait for the **AnimationPlayer** to trigger the method `_spawn_projectile` via a Method Track.
- **Upgrades:** Defined by index in the `TowerData.levels` array. Level 0 is base.

### 4.3. Enemies
**Base Scene:** `TemplateEnemy` (`template_enemy.tscn`)
**Data Driven:** `EnemyData` defining stats and `variants`.
- **Variant System:** One scene handles multiple visual types (Red, Blue, Armored) via the `variant` string.
- **Direction:** 4-way movement (NW, NE, SW, SE). East/West are handled by flipping the Sprite2D (`flip_h`).
- **Validation:** On `_ready()`, enemies self-validate that they have all required animations for their assigned variant.

### 4.4. Levels & Waves
**Resources:** `LevelData` -> `WaveData` -> `SpawnInstruction`
- **LevelData:** Defines map constraints (allowed towers).
- **WaveData:** Defines timing, boss flags, and reward multipliers.
- **SpawnInstruction:** Defines *What* (Enemy Scene), *Where* (Path Node), *How Many* (Count), and *When* (Delays).

### 4.5. Pathfinding (Grid + Curves)
**Nodes:** `Path2D` nodes with `path_data.gd` script.
- **Branching:** Paths rely on `path_data.gd` to define an array of `branches` (connections to next paths).
- **Decision:** When an enemy reaches the end of a path, it checks `branches`. If >1, it chooses randomly. If 0, it is a "Goal" (Deal damage).
- **Offset:** Enemies use `max_path_offset` to walk slightly off-center for visual crowding.

### 4.6. Building & Drag-and-Drop
**Manager:** `BuildManager.gd`
- **Ghost System:** Instantiates a "Ghost" tower that follows the mouse. Snaps to the 64x64 grid.
- **Validation:** Checks `path_layer` custom data (`buildable` bool) and ensures no overlaps.
- **Banishment:** If a drag is cancelled improperly (out of bounds), the session is "Banished" (`banish_drag_session`) to prevent the card from triggering effects until fully reset.
