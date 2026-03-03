# Game Brief — TD-Prototype

**Version:** 0.1 (Living Document)
**Last Updated:** 2026-03-03

## 1. Game Identity

- **Working Title:** TD-Prototype (final name TBD)
- **Genre:** Top-Down Tower Defense with Loadout Strategy and Music Progression
- **Engine:** Godot 4.6.x (2D, GL Compatibility)
- **Visual Style:** DAW-inspired (Digital Audio Workstation) — clean, minimalist, grid-based
- **Elevator Pitch:**
	A tower defense game where every stage is a song. Players defend against waveform
	enemies across stem levels, and their performance determines the quality of each musical
	stem they unlock. Stems layer together as the player progresses through a stage,
	culminating in a boss fight scored by the full song they've assembled. Build your loadout
	in "The Studio", perform in "The Live Set", and craft the ultimate track.

### Thematic Pillars
1. **Music as Progression** — You don't just beat levels, you *compose* a song.
2. **Preparation is Power** — The loadout phase ("The Studio") is where strategy lives.
3. **Performance has Consequences** — Your skill directly shapes what you hear.
4. **DAW as Interface** — The UI *is* the instrument. Meters, racks, and pads — not swords
	 and shields.

---

## 2. Core Game Loop

```
┌─────────────────────────────────────────────────────────┐
│                    STAGE (1 Song)                        │
│                                                          │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐      │
│  │Stem 1│→ │Stem 2│→ │Stem 3│→ │Stem 4│→ │Stem 5│      │
│  │ (Enc)│  │ (Enc)│  │ (Enc)│  │ (Enc)│  │ (Enc)│      │
│  └──────┘  └──────┘  └──────┘  └──────┘  └──────┘      │
│     │         │         │         │         │           │
│     ▼         ▼         ▼         ▼         ▼           │
│  [Quality] [Quality] [Quality] [Quality] [Quality]      │
│  Unlocked  Unlocked  Unlocked  Unlocked  Unlocked       │
│                                                          │
│              All 5 stems layered ──────►  ┌──────────┐  │
│                                           │ BOSS WAVE │  │
│                                           │ (Wave 6)  │  │
│                                           └──────────┘  │
└─────────────────────────────────────────────────────────┘
```

1. **The Studio (Pre-Game):** Player configures their Loadout — selecting Towers, Buffs,
	 and Relics within their Allocation Point budget.
2. **Setlist Preview:** Player chooses which stem level to play next within the stage. 
3. **The Live Set (In-Game):** Player places towers and defends the maze against waveform
	 enemies. The Peak Meter tracks performance.
4. **Stem Unlock:** Based on Peak Meter position at wave end, the player unlocks a Good,
	 Average, or Abomination quality version of that stem.
5. **Layering:** On subsequent stem levels, all previously unlocked stems from this stage
	 play in the background at their earned quality.
6. **Boss Wave:** After all 5 stems are complete, the full assembled song plays during a
	 boss encounter. The Peak Meter acts as a pure survival mechanic here — keep it from
	 filling to survive. Defeat the mini boss to complete the stage.
7. **Progression:** Stage completion unlocks the next stage and potential rewards.

---

## 3. The Peak Meter

The Peak Meter is the central performance indicator and survival mechanic, styled as a 
DAW-standard VU/peak meter with a three-colour gradient and smooth, unscaled animation.

### How It Works
- **Distortion Metaphor:** The meter measures signal distortion (0% to 100%). It counts **up** as performance degrades.
- **Sub-Floor Noise:** The meter starts at **-5%**. The range from -5% to 0% is the "Sub-Floor"—a dedicated grey/white segment that jitters to indicate an active signal even at 0% distortion.
- **Visual Segments:** The track is physically segmented by markers at **0, 33, and 66** for threshold clarity.
- **Zoning:** Green (0-33%), Yellow (33-66%), Red (66-100%).
- **Peak Hold Pinning:** A bright peak-hold line sits strictly on the player's current distortion level without jitter, providing a ground-truth measurement.
- **Collision Logic:** When an enemy reaches the goal, its **remaining health** is added to the total.
- **Unscaled Animation:** UI feedback remains smooth regardless of game speed scale.

> [!TIP]
> **Sub-Floor Noise in Menus:** To reinforce the "active hardware" aesthetic, the peak meter remains live in all menu and setlist screens. When no level is loaded, the meter is forced to a **0% distortion target**. Due to the -5% sub-floor offset, this results in the meter jittering at the **5% hardware margin**, communicating that the system is "on" and ready for a signal.

### Performance Grades
| Meter Zone at Wave End | Stem Quality Unlocked |
|:---|:---|
| **Green** | **Good** — The stem plays in its original, high-quality form. |
| **Yellow** | **Average** — A slightly out-of-tune version with random sound artefacts. |
| **Red** | **Abomination** — A nightmarish version (goat screams, distortion, chaos). |

### Failure & Clipping Logic
When the Peak Meter hits 100% capacity ("Clips"):
- **Immediate Pause:** The game simulation and spawning stop instantly.
- **Signal Fail Popup:** A failure dialogue is presented over the board.
- **Routing Options:**
  - **Retry Stem:** Resets the current wave/stem encounter immediately using the same loadout.
  - **Return to Setlist:** Exits the level and returns the player to the Stage menu to potentially reconfigure their approach or try a different stem.

During the **Boss Wave (Wave 6)**, the Peak Meter is a pure survival mechanic — there is no stem quality to grade. The player must prevent the meter from filling while defeating the mini boss.

---

## 4. Stage & Stem System

### Structure
- **10 Stages**, each representing a complete song (e.g., "Funky Golden Sun").
- **5 Stems per Stage** + **1 Boss Wave** = 6 encounters per stage.
- **The BaseStage Shell**: To minimize scene overhead, all gameplay happens in `BaseStage.tscn`. Individual levels are lightweight "Layout Scenes" (`template_stage.tscn` inherits) containing only painted tiles.
- **Atomic Data (`stem_data.gd`)**: Legacy `WaveData` has been merged into `StemData`. A stem now contains its own audio references, spawn instructions, and a `layout_scene_path` which is injected into the `BaseStage` at runtime.
- **Filesystem Standard**: `Stages/Stage01_Name/Audio/stem_01_drums.mp3`. Configuration files use a strict no-underscore naming convention (e.g., `Config/Stages/stage01.tres`) to ensure consistent automated loading.

### Audio Meter Pattern (Debug Logic)
- **Always On Top**: To streamline the iteration loop, launching the game in a debug build (F5) automatically sets the window to "Always On Top" via `GameManager`, ensuring the DAW interface is immediate and visible over the IDE.

### Setlist Preview UI
The Setlist is no longer a simple level select; it is a **Mix Selection** interface. 
- **Quality Selector:** Once a player unlocks a stem variant (e.g., getting a "Good" result), they can use a dropdown on the Setlist card to toggle which version of the track plays during subsequent gameplay or re-runs.
- **Progress Preservation:** If a player achieves a high quality (Good) but later replays the same stem and fails or gets a lower grade (Abomination), **the game preserves the highest quality achieved.** This ensures players don't "lose" their better tracks while experimenting with different loadouts.

### Stem Order & Gating
- **Stem 1 is mandatory.** The first stem (typically Drums/Percussion) must be completed 
	to establish the rhythmic foundation and rhythmic progress.
- **Stems 2–5 are free choice.** After Stem 1 is completed, the player can attempt any
	of the remains 4 stems in any order.
- **Boss Wave is gated.** Only unlocks after all 5 stems have been completed.

### Restart Logic ("Option C")
The player is given two levels of reset depending on whether they want to optimize a single track or rethink their entire strategy:

- **Restart Stem:** Immediately retries the current stem encounter. Towers and Gold reset,
	but the stage's overall progress (locked qualities of previously completed stems) 
	remains untouched.
- **Restart Entire Stage:** Wipes all stem progress for the current stage and returns the
	player to the Studio. This is the **only way to unlock and change the Loadout** 
	once a stage run has begun. In the SPA architecture, this is triggered via the
	`StageManager` and updates the Top Bar's context state immediately upon confirmation.

### Loadout Lock Timing
- The loadout **locks the moment Stem 1 begins**. 
- To ensure players can plan appropriately before committing, the **Setlist screen** 
	provides a detailed preview of all upcoming stem challenges (see Section 11).

### Layered Playback
- While playing Stem Level N, the current active stem plays in the foreground and dynamically shifts its audio quality (Good/Average/Abomination) in real-time as the Peak Meter rises.
- Previously completed stems (1 through N-1) play in the background layered over it at their permanently locked, earned quality.
- On the Boss Wave, all 5 stems play simultaneously — the player hears the full song they
	assembled.

### Audio Quality Approach (Hybrid)
Two independent audio layers operate simultaneously:

1. **Pre-Recorded Quality Variants (Composer-Owned):** Each stem ships with 3 curated
	audio files (Good / Average / Abomination) crafted by the composer. The AudioManager
	crossfades between them based on Peak Meter thresholds. This gives full artistic control
	over what degradation *sounds like* for each stem.
2. **Dynamic Audio Effects (AudioManager-Owned):** Temporary, gameplay-driven effects are
	layered on top of the active quality track via Godot's AudioBus effect chain. These are
	triggered by buffs, relics, and other gameplay events — not by the Peak Meter. They are
	additive overlays, not replacements for the base quality.

### Replayability
- Stems can be **replayed at any time** to improve quality grades.
- Replaying a stem does *not* unlock the Loadout; it uses the loadout currently locked to 
	the stage.
- All unlocked versions are stored in the **Codex** (see Section 5).

---

## 5. Maintenance & Technical Standards

### The Jules Maintenance Workflow
Project hygiene is managed via a tiered, scheduled maintenance system within `.agent/scheduled_tasks.md`. 
- **The Execution Log:** Every maintenance task (Signal Janitor, Typist, etc.) tracks its "Last Executed" date directly within the schedule to ensure 100% visibility.
- **Workflow Phases:**
    1. **Branching:** Maintenance is performed on dedicated `maint/*` branches.
    2. **Review:** AI-proposed plans and code batches must be reviewed before merging.
    3. **Closing:** Merges happen via Pull Request to maintain a clean git history.

### The "Signal Janitor" Standard
To prevent memory leaks in the dynamic SPA architecture, all nodes that connect to persistent systems (GameManager, StageManager, GlobalSignals) or handle dynamic child buttons must follow the Signal Janitor pattern:
- **Disconnect in `_exit_tree()`**: All connections made in `_ready()` or `populate()` must be explicitly disconnected.
- **Safety Guards**: Use `is_instance_valid(Node)` and `is_connected(Signal, Callable)` before every disconnection to prevent crash-on-exit during scene unloads.
- **Dynamic Cleanup**: For containers with dynamic children (e.g., Relic HBox), use `get_children()` and `get_connections()` to sweep and clear all anonymous or bound connections.

---

## 5. The Codex

> [!NOTE]
> **Status: Planned / Not yet implemented**

A library/collection system that stores all unlocked stem variants.

### Features
- Tracks every stem from every stage and which quality versions the player has unlocked
	(Good / Average / Abomination).
- Players can replay stems to unlock **all three versions** of every stem.
- The Codex feeds directly into the **Final Stage** song-crafting system (see Section 6).
- Acts as a completionist's goal — unlock every variant across all 10 stages.

---

## 6. The Final Stage

> [!NOTE]
> **Status: Planned / Not yet implemented**

**Stage 10** is the climactic finale and plays differently from all other stages.

### Custom Song Assembly
- Instead of a pre-authored song, the player **crafts their own track** by selecting stems
	from their Codex.
- The player picks **one stem per slot** from any previously completed stage and can choose
	which quality version to use.
- This assembled custom song plays during the final stage's levels and boss fight.

### The Final Boss
- The custom-assembled song plays during the ultimate boss encounter.
- The combination of stems the player selects may affect gameplay in ways TBD (e.g.,
	certain stem combinations could grant buffs or alter the arena).

---

## 7. Loadout System — "The Studio"

The Loadout replaces the legacy card/deck system. We use a **Data vs. Configuration** paradigm:
- **Data Structures (`loadout_data.gd`):** Scripts defining the rules and stats for an action.
- **Configurations (`*_config.tres`):** Resource files containing specific values for designers to tweak.

### Allocation Points (AP)
- The hard budget for what a player can bring into a stage.
- Every item (Tower type, Buff, Relic) has an AP cost.
- AP max starts low and **increases through progression** (mechanism TBD).

### The Rack (Slot-Based Architecture)
The loadout is organized into a fixed-size grid (The Rack), separating it from a generic "deck" feel.
- **Towers:** Fixed **6 slots**.
- **Buffs:** Fixed **6 slots**.
- **Relics:** Fixed **3 slots**.
- **Precise Placement:** Players can drag items from the Studio Catalog into specific slots.
- **Internal Swapping:** Items within the Loadout can be rearranged by dragging one slot over another, triggering an automatic swap.
- **Duplicate Guard:** A tower can only occupy one slot in the Rack. Once added, it is disabled in the Catalog until removed from the loadout.

### Towers — "The Instruments"
- Must be allocated to the Loadout to be available for building in-game.
- Each tower type has a **Stock** value — the maximum number of that tower that can be
	placed simultaneously.
- **Building:** Costs Gold. Decreases Stock (−1).
- **Selling:** Returns partial Gold. Refunds Stock (+1).
- Stock forces strategic decisions: bring many cheap towers or few powerful ones?

### Buffs — "The FX Rack"

> [!NOTE]
> **Status: Planned / Not yet implemented**

- Repeatable utility effects that temporarily modify tower attributes.
- **Gold Cost:** Deducted on play.
- **Global Cooldown:** After any Buff is used, all Buffs enter a shared cooldown before
	another can be played.
- Applied via drag-to-target (existing system).

### Relics — "Mastering Plugins"

> [!NOTE]
> **Status: Planned / Not yet implemented**

- Passive modifiers that are always active once the stage begins.
- Each Relic also has an **Active Ability**.
- **Critical Rule:** Regardless of how many Relics are in the Loadout, the player may only
	use **one** Relic's Active Ability **once per stage**. Activating one locks out all
	others until the next stage.
- This creates a "save it or spend it" tension — use the active early for safety, or hold
	it for the boss?

### Loadout Scope
- **Current thinking:** The loadout is strictly locked for the entirety of a Stage (all 5 stems + boss) to reinforce the "prepare in the Studio, perform in the Live Set" metaphor. This prevents tedious reconfiguration between stem levels.
- To prevent player frustration at the Boss Wave due to a locked loadout, two safety mechanisms are employed:
  - **Universal Viability:** Every tower can technically damage every enemy (soft counters). No boss is mathematically impossible to beat, just harder if brought the wrong tools.
  - **The Setlist Preview:** The Studio UI explicitly shows the upcoming challenges (e.g., 'Warning: Heavy Shielded Enemies incoming') before the player confirms their loadout, ensuring failure feels like a tactical error rather than an unfair trick.

---

## 8. Economy & Progression

### Gold (In-Game Currency)
- Earned primarily through **defeating enemies**.
- Used to **build towers** and **play buffs**.
- **Per-Stem Scope (Finalized):** Gold is contained strictly within the current stem level. 
	Starting a new stem or restarting a stem resets Gold to the starting amount defined 
	in the stage config. This prevents "snowballing" economy where an easy first stem 
	makes the remaining 4 trivial.

### Progression & Unlocks (TBD)
- **Stage Completion:** Unlocks the next stage sequentially.
- **Stem Completion:** May unlock new towers or buffs.
- **Boss Defeats:** May unlock Relics.
- **AP Growth:** Mechanism TBD — fixed progression per stage or a separate upgrade system.
- **The Codex:** Acts as a long-term completionist goal (unlock all stem variants).

> [!NOTE]
> The full progression and unlock economy has not been designed yet. This section will be
> expanded as the design matures through playtesting.

---

## 9. Enemy Design — "The Waveforms"

Enemies are modular **audio waveform tracks** defined by `EnemyData` resources.

### Core Visual Identity
- Enemies appear as animated waveform shapes (sine, square, sawtooth, etc.).
- Enemy **health** is represented by a **glitch/distortion shader effect**, mimicking a degraded audio signal.
- As the enemy takes damage, its waveform experiences increasingly severe horizontal signal tearing and RGB chromatic aberration.
- Color vibrancy and opacity are intentionally preserved at 100% until death to ensure the visual remains striking.
- When health reaches zero, the waveform **flatlines** and the enemy disappears.

### Movement & Navigation
- **Grid-Based (AStarGrid2D):** Enemies no longer follow fixed geometric splines. Instead, they find the shortest path through the maze using a 24x16 grid.
- **Weighted Targets:** Spawners can define multiple "Goal Tiles" with proportional weightings (e.g., 50% of enemies go to Goal A, 50% to Goal B).
- **Sub-Stepping Math:** Movement is calculated via a path-consumption loop. This ensures stability at high game speeds (up to 12x) and prevents enemies from "clipping" through walls at corners without needing heavy physics bodies.
- **Visual Directions:** Enemies follow paths in **4 cardinal directions**. No sprite flipping or rotation is applied.
- **Editor Preview:** Visuals are driven by `@tool` scripts, allowing real-time previews of wave scrolling directly in the Godot inspector.

### Visual Configuration (via Shader)
- **Shared Material Optimization:** All enemies share a single base `.tres` `ShaderMaterial`. Unique per-enemy properties (like animation time and `health_ratio`) are driven by Godot 4's `instance_shader_parameters` to minimise draw calls and memory overhead.
- **Geometry:** The shader calculates a mathematically perfect `corner_radius_px` and anti-aliased `border_width` via a Signed Distance Field.

### Planned Variant Types (TBD)
- **Shielded Waveforms:** Enemies with a protective barrier that must be broken before
    health damage applies.
- **Resistant Waveforms:** Enemies with damage type resistances (e.g., immune to
    compression/EQ effects).
- Additional variant types will be designed to fit the audio/music theme as development
	progresses.

### Goal Behaviour
- When an enemy reaches the end of the maze, its **remaining health** is added to the
	Peak Meter.

---

## 10. Tower Design — "The Instruments"

Towers are the player's primary defence. Each is themed around audio/music production
equipment.

### Confirmed Concepts
| Tower | Archetype | Attack | Notes |
|:---|:---|:---|:---|
| **Turntable** | Projectile DPS | Vinyl records | Workhorse tower. Formerly "Record Player." |
| **Monitor** | AoE Damage | Sound wave pulses | Formerly "Speaker Tower." |
| **Subwoofer** | Crowd Control | Bass frequency slow | Enabler — minimal damage, strong slow. |
| **Compressor** | Anti-Tank | % amplitude reduction | Formerly "Vacuum Tube" (reframed as device). |
| **Delay Pedal** | Damage-over-Time | Echo damage ticks | Tag-and-forget sustained pressure. |
| **Tuning Fork** | Burst / Sniper | Resonance strike | Slow charge, massive single hit. |
| **Equalizer** | Debuff / Support | Frequency filtering | Amplifies other towers' damage. |
| **Theremin** | Sustained Beam | Ramp-up laser | Damage increases with lock-on time. |

### Design Direction
- **Roster Target:** 6–8 unique towers, each filling a distinct TD archetype.
- Towers must pass the litmus test: the attack behaviour should feel like a natural
	extension of the equipment.
- **Upgrade System:** 3 tiers × 2 choices per tier. Visual changes are per-tier
	(not per-choice) to manage art budget.
- **Animation Approach:** Towers with simple idle/shoot cycles use
	`AnimationPlayer` (keyframe-driven). Towers with dynamic, reactive animations
	(e.g., Turntable's tone arm sweep) use code-driven `Tweens`. Both systems may
	coexist in a single tower. For large-scale grid elements (e.g., Background 
	Renderer), prefer `draw_texture_rect` batching combined with `Tweens` over 
	mass-instantiating Nodes or complex `_draw` geometry to stay within 
	performance budgets.
- Detailed designs are in individual `Knowledge/tower_design_*.md` documents.
- See `Knowledge/towers_brief.md` for the full roster, synergy map, and trimming
	guidance.

---

## 11. UI/UX Identity — "The DAW"

The entire interface is modelled after professional DAW software.

### SPA Desktop Architecture
The game operates as a Single Page Application within a persistent shell (`GameWindow`).
- **Persistent DAW Shell**: The Top Bar (Transport Controls, Peak Meter) and Left Sidebar remain on screen during transitions to maintain immersion.
- **Workspace Swapping**: Menus (Main Menu, Setlist, Studio) and Gameplay Levels are loaded into a central **SubViewport Workspace**. This prevents "hard" scene cuts and allows for smooth, software-like transitions.
- **Sidebar Architecture**: The Left Sidebar is nested within a `SidebarContainer` alongside a `SidebarOverlay`. This grouping allows the entire rack to be managed as a single logical unit for input propagation and state-dependent visibility.
- **Animation Strategy**: To ensure layout stability, sidebar transitions animate `offset_left` and `offset_right` properties rather than `position.x`. This utilizes Godot 4's anchor system reliably. Animations use a `TRANS_CUBIC` ease (`0.4s`) and a `call_deferred` pattern to allow layout settlement before the Tween begins.
- **Animation Lock**: An `_is_sidebar_animating` flag prevents rapid-fire button presses from desynchronizing the sidebar state during transitions.
- **Context-Aware Sidebar Overlay**: The Left Sidebar features a dynamic **OverlayContent** container. This system swaps its content (e.g., Main Menu buttons) based on the game's context.
- **Inspector Signal Persistence**: Because the `TowerInspector` is a persistent UI element while the `BuildManager` is recreated per level, the `GameWindow` uses a **Signal Rebinding Pattern**. Whenever a new level is wired up, the inspector's `sell_tower_requested` and `target_priority_changed` signals are explicitly re-connected to the fresh `BuildManager` instance.
- **Refined Navigation Flow**:
    - **Menu Toggle**: The "Menu" button in the Top Bar toggles the sidebar overlay.
    - **Click-to-Close (Auto-Hide)**: During gameplay, clicking in the maze viewport, selecting a tower, or interacting with transport controls (Play/Restart) automatically closes the sidebar.
    - **Audio Exception**: Adjusting volume or toggling mute is exempt from auto-hide, allowing for background adjustments without closing the menu.

### Layout (1536×1024 Native, Scaled to 1920×1080)
- **Top Bar:** Global stats (Peak Meter, Gold, Wave counter), Restart button, and Volume Control.
- **Left Sidebar:** Loadout rack — Tower buttons (with stock counts), Spell slots (with
	cooldown bars), Relic slots.
- **Right Panel:** Tower Inspector / Selection details.
- **Debug Overlay:** Developmental tools (Game Speed, Framerate, Debug Logs) are grouped in a dedicated `DebugToolbar` overlay. This sits on top of the Game Viewport but is visually distinct from the main Top Bar to preserve the "DAW" aesthetic.
- **High-Contrast Popups:** The Tower Inspector uses a solid, high-opacity background (`~95%`) specifically to mirror DAW "floating plugin" aesthetics and ensure stats are readable over the complex maze geometry.

**Context-Aware Transport Controls**
- The **Play** and **Restart** buttons in the Top Bar are strictly tied to gameplay state. They are disabled when viewing the Main Menu or Setlist to prevent invalid state transitions.
- **Restart Safety:** Triggering a restart while a wave is active explicitly pauses the simulation before presenting the confirmation dialog, ensuring the game doesn't continue running in the background while the player decides.

**Auto-Pause for System Modals**
- To preserve player progress and prevent "cheap" deaths, the game automatically enters a `PAUSED` state whenever a system-level confirmation dialog (Quit, Main Menu, Setlist, Restart) is opened.
- If the user cancels the dialog, the game automatically resumes only if a wave was already in progress.

### DAW Metaphor Mapping
| Game Element | DAW Equivalent |
|:---|:---|
| Pre-game loadout | The Studio — setting up your rack |
| In-game phase | The Live Set — performing |
| Towers | Instruments |
| Buffs | FX Rack modules |
| Relics | Mastering plugins |
| Gold | Energy |
| Allocation Points | CPU/RAM budget |
| Peak Meter | VU / Peak meter |
| Enemies | Waveform tracks |
| Stages | Songs |
| Stem levels | Individual tracks/stems |
| Enhanced map tiles | Amped Tiles / High Voltage |

### The Setlist Preview (The Stage Map)
The Setlist screen serves as the transition between "The Studio" (Preparation) and "The Live Set" (Performance). It displays the 5 stems as clickable cards.

- **The Stem Card**:
    - **Instrument Label**: The musical role (e.g., "Synths", "Vocals").
    - **State Indication**: Clearly marked as *Locked*, *Available*, or *Completed*.
    - **Quality Grade**: Displays the earned medal/icon (**Good / Average / Abomination**) if the stem has been beaten.
    - **Enemy Preview**: Critical strategic data preview.
    - **Mandatory Cue**: Stem 1 is visually highlighted as the required entry point.
    - **Theme Variations**: Styling is managed via **Theme Type Variations** (e.g., `StemCardPanel`) within `daw_theme.tres`, allowing unique card looks while maintaining global inheritance from the DAW theme.

### Art Direction for Assets
- **Style:** Modern, clean semi-realistic digital illustration. Not retro, not
	cartoon, no thick outlines. Smooth gradients with subtle material shading.
- **Colour Palette:** Dark charcoal base with neon teal/cyan accent lighting,
	matching the maze tile aesthetic. High contrast to read clearly at small scale.
- **3D Depth:** All assets rendered with a "chunky slab" depth — lighter highlight
	on top/left edges, darker shadow on bottom/right (app-icon style).
- **Texture Import:** Enable mipmaps on all tower/projectile textures; use
	`Linear Mipmap` texture filter on downscaled sprites.
- **Design-for-Scale:** Assets are generated at 1024×1024 and downscaled via
	`Sprite2D.scale` in-engine. Fine details (e.g., vinyl grooves) should be bold
	enough to survive the downscale.
- **Grayscale Modulation Pattern:** Grid assets and UI elements are designed as 
	pure grayscale templates. This allows for dynamic, high-performance 
	color-tinting via `modulate` or `self_modulate` in-engine.
	- **White / Light Grey:** High-luminance areas (LEDs/Glow).
	- **Mid-Grey:** Diffuse material surface (Silicone/Metal).
	- **Dark / Charcoal:** Permanent 3D shadows and extrusions.

### The Timeline (New Feature)

> [!NOTE]
> **Status: Planned / Not yet implemented**

- **Concept:** A visual representation of the music track's progress and upcoming events.
- **Playhead:** A red vertical line that scans left-to-right across the Level Viewport.
- **Duration Sync:** The scan duration matches the exact length of the current stem's audio track.
- **Spawn Markers:** Visual indicators along the top of the viewport (or bottom of the top bar)
	that align with specific timestamps in the track, alerting the player to incoming enemy waves.
- **Goal:** Reinforces the connection between the audio and the gameplay, acting as a functional
	"sheet music" or "sequencer" view for the player.

### The Opening Sequence

> [!NOTE]
> **Status: Planned / Not yet implemented**

- **The Writing Grid**: The `AnimationLayer` uses a 1:1 mapping with the background 28×28 pad grid. Title strings (e.g., "DRUMS", "BASS") are plotted directly into this layer using the `animation_tileset.tres` and are revealed as part of the stem introduction.
- **The Column Swipe**: The opening sequence uses a `SWIPE_RIGHT` transition mode. `SongLayer` tiles (28px) disappear as a leading wave, followed by the `MazeLayer` buttons (84px) appearing with a fixed `swipe_gap` (~15% screen width), creating a rhythmic "wipe" that resolves into the level view.

---

## 12. State Management — "The Frozen Studio"

### Pause Philosophy
The pause state acts as a "Strategic Planning" mode. The music/action freezes, but the player remains active within the "DAW" environment.

### Selective Interactivity
- **Permitted**: Tower selection, changing Target Priority, and interacting with background pads.
- **Single-Click Transition**: Selection remains active while paused. If a tower is clicked while the menu is open, the game unpauses, hides the menu, and selects the tower in one seamless action.
- **Blocked**: Placing new towers, selling, or upgrading. This prevents permanent tactical decisions while frozen.
- **Modal Interruptions**: Opening any modal confirmation via the Top Bar or Sidebar (Main Menu, Setlist, Restart) triggers a global pause and deselects current towers to clear the tactical view.
- **Audio Sync**: Background music stems are strictly synchronized to the game's pause state via `stream_paused`.

---

## 13. Open Design Questions

The following items are acknowledged as **not yet finalised** and will be resolved through
future design sessions and playtesting:

- [x] **Gold Scope:** Gold resets per stem (Resolved Feb 26).
- [x] **Data Consolidation:** Merged legacy `WaveData` into `StemData` to simplify the resource pipeline (Resolved Feb 26).
- [x] **Modal Behavior:** Game auto-pauses for all system confirmations and resumes on cancel if a wave was active (Resolved Feb 27).
- [x] **Setlist Navigation:** Returning to the Setlist from a level is a destructive action requiring a confirmation prompt (Resolved Mar 02).
- [x] **BaseStage Injection:** Moved to a shell-injection pattern to reduce scene bloat (Resolved Mar 01).
- [x] **Sidebar Main Menu:** Refactored main navigation into a context-aware sidebar overlay (Resolved Mar 02).
- [x] **Auto-Load Stage 1:** The Setlist button now automatically loads the first stage if no active stage exists (Resolved Mar 02).
- [x] **Selection Reliability:** Synchronized `BuildManager` and `GameWindow` state to ensure reliable tower clicking during pause (Resolved Mar 02).
- [x] **Signal Management:** Implemented mandatory `_exit_tree()` cleanup across all UI and core systems (Resolved Mar 03).
- [x] **Inspector Persistence:** Resolved broken sell/priority signals by rebinding inspector to BuildManager on every level load (Resolved Mar 03).
- [x] **Slot-Based Loadout:** Transitioned towers to a fixed 6-slot array for precise placement and swapping (Resolved Mar 03).
- [x] **Sidebar Interaction:** Fixed drag-locking issue by ensuring sidebar remains interactive during Studio drags (Resolved Mar 03).
- [ ] **AP Growth:** How does the player's maximum AP increase? Fixed per stage, or a
	separate upgrade currency?
- [ ] **Unlock Economy:** Full mapping of what unlocks where (towers, buffs, relics, AP).
- [ ] **Enemy Variants:** Detailed design for shielded, resistant, and other enemy types.
- [ ] **Upgrade Branching:** Can the player mix upgrade choices across tiers (e.g.,
	Tier 1A + Tier 2B), or must they commit to a single path?
- [ ] **Relic Design:** Specific passive/active ability designs for each relic.
- [ ] **Buff Design:** Specific buff effects, costs, and cooldown values.
- [ ] **Final Stage Mechanics:** Does the custom song selection affect gameplay, or is it
	purely aesthetic?
- [ ] **Difficulty Scaling:** How does difficulty ramp across stages and within stem levels?
- [ ] **Music Source:** Original compositions, licensed tracks, or procedurally generated?
- [ ] **Game Title:** Final name for the game.

---

## 14. Future / Stretch Goals

### Dynamic Audio Effects Layer
Temporary, gameplay-triggered audio effects layered on top of the active stem quality track via Godot's AudioBus system. 
- **Buff Feedback:** High-pass filter sweeps or shimmer reverb when a buff is applied.
- **Relic Feedback:** Tape stop or rewind effects for relic activations.
- **Performance Feedback:** Vinyl scratch one-shots when an enemy reaches the goal.
- **Visualizer Sync:** Buffs and towers pulsing the background "sound pads" in time with the track transients.

