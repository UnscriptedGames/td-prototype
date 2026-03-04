# Tower Design: The Turntable

**Version:** 0.1 (Living Document)
**Last Updated:** 2026-02-18
**Status:** Design Phase — Pending Implementation

---

## 1. Overview

| Property | Value |
|:---|:---|
| **Tower Name** | The Turntable |
| **Archetype** | Projectile DPS (workhorse) |
| **Role** | Cheap, reliable single-target damage. Present in most loadouts. |
| **DAW Metaphor** | The DJ's turntable — the most iconic piece of music equipment. |
| **Litmus Test** | A turntable spins discs. This tower spins discs at enemies. 1:1 mapping. |

### Why This Is the Workhorse

- **Low barrier, high ceiling.** Cheap to place, but upgrade paths keep it relevant
  into late waves.
- **Cultural anchor.** The most-placed tower becomes the visual identity of the game.
  A turntable on the maze is an instant signal: "this is a music game."
- **DJ fantasy.** Placing turntables makes the player feel like they're setting up a
  DJ rig, which aligns with "The Live Set" phase.
- **Satisfying micro-loop.** A spinning vinyl record tumbling through the air has
  inherent visual drama — it's not a generic bullet.

---

## 2. Visual Design

### Constraints

- **Perspective:** Top-down with a slight drop shadow for depth.
- **Canvas Size:** 64×64 pixels per grid tile (~80×80 screen pixels at 1.25× upscale).
- **Readability Rule:** At 64×64, differentiation must come from **shape, colour, and
  size** — not fine detail. One dominant visual change per tier.

### Reference Image

> [!NOTE]
> The reference concept art (turntable_tiers_reference) should be placed alongside
> this document. It shows the 4 tiers in a 2×2 grid on a dark background, matching
> the descriptions below.

![Turntable tier progression — Base, Tier 1, Tier 2, Tier 3](turntable_tiers_reference.png)

### Tier Progression

The visual story across tiers: **bedroom hobby → home setup → club deck → main stage
rig.**

#### Base Level — "The Portable"

- **Housing:** Rounded-square grey housing, ~75% of cell (leaves room for shadow).
- **Platter:** Dark circular vinyl record centred in the housing, ~60% of housing
  width. Subtle groove ring visible.
- **Tone Arm:** Simple thin line resting across the top-right quadrant, pointing
  inward.
- **Label:** Small grey centre circle (spindle).
- **Shadow:** Soft drop shadow offset down-right, matching existing tile shadows.
- **Animation:** Platter spins at a slow, steady pace when targeting. Slows to a stop
  when idle.
- **Feel:** *"It's a cheap little player, but it gets the job done."*

#### Tier 1 — Colour Shift: "The Belt-Drive"

- **Primary Change:** A bright **teal/green coloured vinyl** (slipmat) replaces the
  dark record. This is the single most visible change — a bold colour pop.
- **Tone Arm:** Slightly thicker, with a visible rounded end (counterweight).
- **Housing:** Same shape as base. No new geometry.
- **Feel:** *"Same turntable, but now it's got style."*

#### Tier 2 — Size Change: "The Direct-Drive"

- **Primary Change:** Housing **grows to ~85% of cell**. The tower is physically
  bigger in its grid slot.
- **Platter:** Larger relative to housing. A contrasting **white centre label dot**
  replaces the grey spindle.
- **Tone Arm:** More detailed — visible headshell at the tip, distinct angular
  positioning. Arm is actively on the record (tower is "playing").
- **Shadow:** Slightly deeper/wider — implies more physical height.
- **Feel:** *"That's a proper deck. This one means business."*

#### Tier 3 — Shape Change: "The Full Rig"

- **Primary Change:** A **rectangular mixer section** attaches to the right side of
  the housing. This is a brand-new shape element that didn't exist before.
- **Mixer Details:** 3–4 small vertical fader lines and 2–3 circular knobs. Readable
  at 64×64 as simple geometric shapes.
- **Platter:** Teal **glow ring** around the outer edge of the record (shader effect).
- **Label:** Bright **glowing centre dot** (white-green).
- **Tone Arm:** Most refined version, with detailed headshell.
- **Housing:** Wider overall footprint to accommodate mixer. Additional small circular
  details (screws/vents) at corners.
- **Shadow:** Maximum depth — this tower dominates its grid cell.
- **Feel:** *"That's the centrepiece of the rig. The headliner's deck."*

### Tier Visual Summary

| Tier | Name | Dominant Change | Player Reads As |
|:---|:---|:---|:---|
| **Base** | The Portable | — | "Grey square, dark circle, line" |
| **Tier 1** | The Belt-Drive | **Colour** (teal vinyl) | "It's got colour now" |
| **Tier 2** | The Direct-Drive | **Size** (bigger housing + white label) | "It's bigger and active" |
| **Tier 3** | The Full Rig | **Shape** (mixer panel + glow) | "It's got extra gear" |

### Art Budget Decision

Each upgrade tier shares the **same visual regardless of which upgrade choice** the
player selects within that tier. This is intentional:

- **Budget:** 4 sprites per tower (not 7+).
- **Readability:** Players build a visual vocabulary of 4 looks, not a confusing
  matrix.
- **Choice Differentiation:** Handled through **projectile visuals** and **attack
  effects**, not tower model changes.

---

## 3. Upgrade System

### Structure

- **Base Level** + **3 Upgrade Tiers** with **2 choices per tier**.
- Each tier visually evolves the tower (see Section 2).
- Choices within a tier share the same tower sprite.

### Upgrade Tree

```
                        ┌─────────────┐
                        │    BASE     │
                        │ The Portable│
                        └──────┬──────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
         ┌──────┴──────┐       │       ┌──────┴──────┐
         │  TIER 1 (A) │       │       │  TIER 1 (B) │
         │   45 RPM    │       │       │ Heavy Vinyl  │
         └──────┬──────┘       │       └──────┬──────┘
                │              │              │
         ┌──────┴──────┐       │       ┌──────┴──────┐
         │  TIER 2 (A) │       │       │  TIER 2 (B) │
         │  Scratch    │       │       │  Ricochet   │
         └──────┬──────┘       │       └──────┬──────┘
                │              │              │
         ┌──────┴──────┐       │       ┌──────┴──────┐
         │  TIER 3 (A) │       │       │  TIER 3 (B) │
         │ Crossfader  │       │       │  Echo Spin  │
         └─────────────┘       │       └─────────────┘
                               │
                     (Visual upgrade
                      applies to both
                      A and B choices)
```

### Tier 1 — Rate vs Power

| Choice | Name | Effect |
|:---|:---|:---|
| **A** | 45 RPM | Fire rate increases significantly. Damage per hit stays the same. Smaller, faster projectiles. |
| **B** | Heavy Vinyl | Damage per hit increases significantly. Fire rate stays the same. Larger, heavier-looking projectiles. |

**Strategic Tension:** Volume of fire vs. burst damage per shot.

### Tier 2 — On-Hit Effect

| Choice | Name | Effect |
|:---|:---|:---|
| **A** | Scratch | Each hit applies a brief **damage-over-time** effect (waveform scratch visual on the enemy). Stacks up to 3 times. |
| **B** | Ricochet | After hitting the primary target, the record **bounces** to a second nearby enemy for reduced damage. |

**Strategic Tension:** Single-target sustained pressure vs. multi-target spread.

### Tier 3 — Ultimate Ability

| Choice | Name | Effect |
|:---|:---|:---|
| **A** | Crossfader | Periodically fires a **burst of 3 records** in rapid succession at the current target. The burst has a cooldown between activations. |
| **B** | Echo Spin | Every Nth record fired is an **echo record** that passes through enemies, damaging all in a line (piercing projectile). |

**Strategic Tension:** Concentrated burst vs. line-clearing pierce.

---

## 4. Projectile: The Vinyl Record

### Base Projectile

- **Shape:** Small circle with a visible centre hole (reads as a vinyl record even at
  small sizes).
- **Flight Behaviour:** Spins visibly during flight (rotation animation). Travels in
  a straight line toward the target.
- **On Hit:** Brief impact effect — a small radial "scratch" ripple.

### Projectile Variants by Upgrade

| Upgrade | Projectile Change |
|:---|:---|
| **45 RPM** | Slightly smaller record, faster spin animation. |
| **Heavy Vinyl** | Slightly larger record, darker colour, slower spin. |
| **Scratch** | Normal record, but leaves a waveform scratch trail on hit. |
| **Ricochet** | Record visibly bounces toward a second target after impact. |
| **Crossfader** | Burst fires 3 records in rapid sequence (same projectile). |
| **Echo Spin** | Echo records have a translucent/ghost appearance and pierce. |

---

## 5. Audio Design Notes

Since this tower will be heard thousands of times per session, audio must be:

- **Short:** Sub-200ms for fire and hit sounds to avoid overlap.
- **Non-shrill:** Warm, vinyl-appropriate tones. Think "whoosh" not "ping."
- **Randomised:** Slight pitch and timing variation on each fire to prevent listener
  fatigue.

| Event | Sound Direction |
|:---|:---|
| **Fire** | Soft vinyl "whoosh" / disc spin release. |
| **Hit** | Satisfying "thwack" with a subtle crackle (vinyl pop). |
| **Scratch (DoT)** | Brief DJ scratch sound on application. |
| **Ricochet** | A lighter "skip" sound on the bounce. |

---

## 6. Animation Notes

| State | Animation |
|:---|:---|
| **Idle** | Platter slows to a stop. Tone arm lifts slightly (resting position). |
| **Targeting** | Platter spins at a constant speed. Tone arm lowers onto the record. |
| **Firing** | Brief flash or "release" frame as the record launches. Platter spin speed momentarily increases. |
| **Upgraded** | Spin speed baseline increases with each tier. |

---

## 7. Stat Framework

> [!NOTE]
> Exact values are TBD and subject to playtesting. The framework below defines the
> stat *categories* and their intended relationships.

| Stat | Description | Scales With |
|:---|:---|:---|
| **Damage** | HP removed per hit. | Heavy Vinyl (Tier 1B), base tier growth. |
| **Fire Rate** | Records per second. | 45 RPM (Tier 1A), base tier growth. |
| **Range** | Detection/targeting radius in tiles. | Base stat, may increase slightly with tiers. |
| **Projectile Speed** | How fast the record travels. | Base stat, minor scaling. |
| **Build Cost** | Gold to place on the grid. | Fixed per tower type. |
| **Upgrade Cost** | Gold per tier upgrade. | Increases per tier. |
| **Stock** | Max simultaneous placements (from Loadout). | Fixed by Loadout AP allocation. |
| **AP Cost** | Allocation Points to bring into a stage. | Fixed per tower type. |

---

## 8. Synergy Notes

The Turntable's effectiveness scales significantly when paired with specific towers:

| Partner Tower | Synergy |
|:---|:---|
| **Subwoofer** (Slow) | Slowed enemies spend more time in range → more records land. Scratch DoT ticks fully. |
| **Equalizer** (Debuff) | Damage amplification on filtered enemies makes every record hit harder. |
| **Delay Pedal** (DoT) | Ricochet spreads targets for the Delay Pedal to tag. |

---

## 9. Open Design Questions

- [ ] **Exact stat values:** Base damage, fire rate, range, costs per tier.
- [ ] **Upgrade branching rules:** Can the player mix A and B across tiers (e.g.,
  Tier 1A + Tier 2B), or must they commit to a single path?
- [ ] **Projectile collision:** Does the record have a hitbox that can be dodged, or
  is it homing?
- [ ] **Ricochet targeting:** Does the bounce target the nearest enemy, or a random
  one in range?
- [ ] **Scratch stacking:** What is the DoT damage per stack and duration?
- [ ] **Echo Spin pierce limit:** Does it pierce infinitely or cap at N enemies?
- [ ] **Visual effects budget:** Shader-based glow for Tier 3, or sprite-based?
- [ ] **Sound effects:** Source or create placeholder audio for fire/hit events.
