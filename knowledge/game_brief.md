# Game Brief — TD-Prototype

**Version:** 0.1 (Living Document)
**Last Updated:** 2026-02-18

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
│  │(Wave)│  │(Wave)│  │(Wave)│  │(Wave)│  │(Wave)│      │
│  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘      │
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
2. **Stem Select:** Player chooses which stem level to play next within the stage. A
	 "Producer's Cut" suggested order is displayed (Rhythm → Bass → Harmony → Melody →
	 Vocals) to guide newer players, while experienced players may tackle stems in any order.
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

The Peak Meter is the central performance indicator, styled as a DAW-standard VU/peak meter
with a three-colour gradient.

### How It Works
- Divided into three zones: **Green** (bottom), **Yellow** (middle), **Red** (top).
- When an enemy reaches the end of the maze (the goal), its **remaining health** is added
	to the Peak Meter's cumulative total, pushing the needle upward.
- The meter **resets between each stem level**.

### Performance Grades
| Meter Zone at Wave End | Stem Quality Unlocked |
|:---|:---|
| **Green** | **Good** — The stem plays in its original, high-quality form. |
| **Yellow** | **Average** — A slightly out-of-tune version with random sound artefacts. |
| **Red** | **Abomination** — A nightmarish version (goat screams, distortion, chaos). |

### Fail State
- If the Peak Meter **completely fills** (tops out past red) before the wave is complete,
	the level is **failed** and must be replayed.
- During the **Boss Wave (Wave 6)**, the Peak Meter is a pure survival mechanic — there is
	no stem quality to grade. The player must prevent the meter from filling while defeating
	the mini boss.

---

## 4. Stage & Stem System

### Structure
- **10 Stages**, each representing a complete song.
- **~5 Stem Levels per Stage** + **1 Boss Wave** = 6 encounters per stage.
- Each stem level corresponds to a musical layer (e.g., Drums, Bass, Synth, Melody, Vocals).

### Stem Order: "Producer's Cut"
- Players **choose** which stem to play next, but a **suggested order** is displayed on the
	stage select screen following natural musical layering logic:
	1. Rhythm / Drums
	2. Bass
	3. Harmony / Chords
	4. Melody / Lead
	5. Vocals / Top Line
- **Freestyle Mode:** Once a stage is completed via the suggested order, the player unlocks
	the ability to play stems in any order for that stage (for replays and codex hunting).

### Layered Playback
- While playing Stem Level N, stems 1 through N-1 play in the background at their
	earned quality.
- On the Boss Wave, all 5 stems play simultaneously — the player hears the full song they
	assembled.

### Replayability
- Stems can be **replayed at any time** to improve quality grades.
- All unlocked versions are stored in the **Codex** (see Section 5).

---

## 5. The Codex

A library/collection system that stores all unlocked stem variants.

### Features
- Tracks every stem from every stage and which quality versions the player has unlocked
	(Good / Average / Abomination).
- Players can replay stems to unlock **all three versions** of every stem.
- The Codex feeds directly into the **Final Stage** song-crafting system (see Section 6).
- Acts as a completionist's goal — unlock every variant across all 10 stages.

---

## 6. The Final Stage

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

The Loadout replaces the legacy card/deck system. Players configure their available tools
before entering a stage.

### Allocation Points (AP)
- The hard budget for what a player can bring into a stage.
- Every item (Tower type, Buff, Relic) has an AP cost.
- AP max starts low and **increases through progression** (mechanism TBD).
- **Cost Tiers:**
	- **Heavy:** High-Tier Towers, Powerful Relics
	- **Medium:** Standard Towers, Global Buffs
	- **Light:** Simple Spells, Utility Modules

### Towers — "The Instruments"
- Must be allocated to the Loadout to be available for building in-game.
- Each tower type has a **Stock** value — the maximum number of that tower that can be
	placed simultaneously.
- **Building:** Costs Gold. Decreases Stock (−1).
- **Selling:** Returns partial Gold. Refunds Stock (+1).
- Stock forces strategic decisions: bring many cheap towers or few powerful ones?

### Buffs — "The FX Rack"
- Repeatable utility effects that temporarily modify tower attributes.
- **Gold Cost:** Deducted on play.
- **Global Cooldown:** After any Buff is used, all Buffs enter a shared cooldown before
	another can be played.
- Applied via drag-to-target (existing system).

### Relics — "Mastering Plugins"
- Passive modifiers that are always active once the stage begins.
- Each Relic also has an **Active Ability**.
- **Critical Rule:** Regardless of how many Relics are in the Loadout, the player may only
	use **one** Relic's Active Ability **once per stage**. Activating one locks out all
	others until the next stage.
- This creates a "save it or spend it" tension — use the active early for safety, or hold
	it for the boss?

### Loadout Scope
- **Current thinking:** Loadouts are locked to a full stage (all 5 stems + boss), not
	per-stem. This prevents tedious reconfiguration between stem levels and reinforces the
	"prepare in the Studio, perform in the Live Set" metaphor.

---

## 8. Economy & Progression

### Gold (In-Game Currency)
- Earned primarily through **defeating enemies**.
- Used to **build towers** and **play buffs**.
- Currently planned to be **contained per stem level** (resets between stems).
- Scope (per-stem vs per-stage persistence) is **TBD** and subject to playtesting.

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

Enemies are visualised as **audio waveform tracks** moving along the maze paths.

### Core Visual Identity
- Enemies appear as animated waveform shapes (sine, square, sawtooth, etc.).
- The **amplitude** of the waveform represents the enemy's **current health**.
- As the enemy takes damage, its amplitude **decreases** (the wave flattens).
- When health reaches zero, the waveform **flatlines** and the enemy disappears.

### Movement
- Enemies follow paths in **4 cardinal directions** (North, South, East, West).
- No sprite flipping or rotation is applied during movement.

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
	coexist in a single tower.
- Detailed designs are in individual `Knowledge/tower_design_*.md` documents.
- See `Knowledge/towers_brief.md` for the full roster, synergy map, and trimming
	guidance.

---

## 11. UI/UX Identity — "The DAW"

The entire interface is modelled after professional DAW software.

### Layout (1536×1024 Native, Scaled to 1920×1080)
- **Top Bar:** Global stats (Peak Meter, Gold, Wave counter) and Volume Control.
- **Left Sidebar:** Loadout rack — Tower buttons (with stock counts), Buff slots (with
	cooldown bars), Relic slots.
- **Right Panel:** Tower Inspector / Selection details.
- **Centre:** The Level Viewport (24×16 tiles @ 64px) — the maze/battlefield.

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

### The Timeline (New Feature)
- **Concept:** A visual representation of the music track's progress and upcoming events.
- **Playhead:** A red vertical line that scans left-to-right across the Level Viewport.
- **Duration Sync:** The scan duration matches the exact length of the current stem's audio track.
- **Spawn Markers:** Visual indicators along the top of the viewport (or bottom of the top bar)
	that align with specific timestamps in the track, alerting the player to incoming enemy waves.
- **Goal:** Reinforces the connection between the audio and the gameplay, acting as a functional
	"sheet music" or "sequencer" view for the player.

---

## 12. Open Design Questions

The following items are acknowledged as **not yet finalised** and will be resolved through
future design sessions and playtesting:

- [ ] **Gold Scope:** Does gold persist across stem levels within a stage, or reset per
	stem? (Current lean: per-stem reset.)
- [ ] **Loadout Scope:** Loadouts locked per stage or changeable between stems? (Current
	lean: locked per stage.)
- [ ] **AP Growth:** How does the player's maximum AP increase? Fixed per stage, or a
	separate upgrade currency?
- [ ] **Unlock Economy:** Full mapping of what unlocks where (towers, buffs, relics, AP).
- [ ] **Enemy Variants:** Detailed design for shielded, resistant, and other enemy types.
- [x] **Tower Roster:** 8 tower concepts confirmed. See `Knowledge/towers_brief.md`.
	Individual tower specs in `Knowledge/tower_design_*.md`. Stats TBD via playtesting.
- [ ] **Upgrade Branching:** Can the player mix upgrade choices across tiers (e.g.,
	Tier 1A + Tier 2B), or must they commit to a single path?
- [ ] **Relic Design:** Specific passive/active ability designs for each relic.
- [ ] **Buff Design:** Specific buff effects, costs, and cooldown values.
- [ ] **Final Stage Mechanics:** Does the custom song selection affect gameplay, or is it
	purely aesthetic?
- [ ] **Difficulty Scaling:** How does difficulty ramp across stages and within stem levels?
- [ ] **Music Source:** Original compositions, licensed tracks, or procedurally generated?
- [ ] **Game Title:** Final name for the game.
