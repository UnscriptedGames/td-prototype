# Tower Design Brief — TD-Prototype

**Version:** 0.1 (Living Document)
**Last Updated:** 2026-02-18

## 1. Design Philosophy

Towers are called **"Instruments"** within the DAW metaphor. Every tower must pass the
litmus test:

> *"Could a music producer look at this tower's name and attack and immediately say
> 'yeah, that's what that piece of gear does'?"*

The attack behaviour must feel like a **natural extension of the equipment** — a speaker
*pulses*, a compressor *squashes*, a delay pedal *echoes*. If the mechanic doesn't map
intuitively to the gear, it's the wrong fit.

### Target Roster
- **6–8 unique towers** covering a range of attack types, effects, and upgrade paths.
- Each tower fills a distinct **TD archetype** so the player has meaningful loadout
  decisions.

### Archetypes to Cover
| Archetype | Role |
|:---|:---|
| **Projectile DPS** | Reliable single-target damage dealer |
| **AoE Damage** | Punishes grouped enemies |
| **Crowd Control** | Slows or disrupts enemy movement |
| **Damage-over-Time** | Sustained pressure after initial hit |
| **Burst / Sniper** | Slow but devastating single hits |
| **Debuff / Support** | Amplifies other towers' effectiveness |
| **Sustained Beam** | Rewards target focus, punishes swapping |
| **Anti-Tank / Scaling** | Counters high-HP enemies specifically |

---

## 2. Tower Roster

### 2.1. The Turntable

- **Archetype:** Projectile DPS (bread & butter)
- **Attack:** Spins vinyl records at single targets.
- **Fantasy:** The workhorse — cheap, reliable, and present in almost every loadout.
  The "Dart Monkey" of this game.
- **Upgrade Direction:**
  - RPM — increased fire rate.
  - Heavier Vinyl — increased damage per hit.
  - Ricochet — records bounce off the first target to hit a second.

---

### 2.2. The Monitor

- **Archetype:** AoE pulse damage
- **Attack:** Studio monitor that emits concentric sound wave pulses, damaging all
  enemies in range.
- **Fantasy:** The "put one in the middle of a cluster" tower. Rewards good maze design
  that forces enemies to bunch up.
- **Upgrade Direction:**
  - Larger pulse radius.
  - Faster pulse rate.
  - Final-tier "Feedback Burst" — massive damage when 5+ enemies are in range.

---

### 2.3. The Subwoofer

- **Archetype:** Crowd Control (slow)
- **Attack:** Emits deep bass frequencies that vibrate the ground, slowing all enemies
  in its zone. Minimal damage.
- **Fantasy:** The enabler — doesn't kill anything on its own but makes every other
  tower dramatically more effective. A real tempo controller.
- **Upgrade Direction:**
  - Deeper Frequency — stronger slow percentage.
  - Wider radius.
  - Tier-3 "Bass Drop" — periodic stun effect.

---

### 2.4. The Compressor

- **Archetype:** Anti-Tank / Scaling damage
- **Attack:** Targets a single enemy and "compresses" its amplitude — deals
  **percentage-based damage** that scales with the enemy's current HP. Like a real
  compressor that reduces loud signals more aggressively.
- **Fantasy:** The boss-killer. Expensive and slow, but the answer to anything big. You
  bring this when you know the wave has tanks.
- **Upgrade Direction:**
  - Higher Ratio — increased percentage damage.
  - Faster Attack/Release — higher fire rate.
  - "Brickwall Limiter" mode — caps enemy speed while compressing.
- **Visual Note:** The vacuum tube aesthetic (glowing glass tubes, warm orange light)
  fits perfectly as the visual design for this tower.

---

### 2.5. The Delay Pedal

- **Archetype:** Damage-over-Time
- **Attack:** Initial hit, then the damage **echoes** — repeating as reduced-damage
  ticks over time (like a delay effect's repeating taps).
- **Fantasy:** "Tag and forget." Hit an enemy once, and the echoes keep chipping away
  as it walks through the maze. Stacks beautifully with the Subwoofer's slow.
- **Upgrade Direction:**
  - More echo taps.
  - Shorter tap interval.
  - "Ping-Pong Delay" — damage bounces between two nearby enemies.

---

### 2.6. The Tuning Fork

- **Archetype:** Burst / Sniper
- **Attack:** Charges up and releases a devastating **resonance strike** at long range.
  Slow attack speed, massive single-hit damage. The fork vibrates with increasing
  intensity before releasing a shockwave along a narrow line.
- **Fantasy:** The precision instrument. One shot, one kill. Punishes poor placement
  (long wind-up means it might only fire once per pass). High skill ceiling.
- **Upgrade Direction:**
  - Faster resonance charge time.
  - Longer range.
  - "Harmonic" — bonus damage if two Tuning Forks target the same enemy.

---

### 2.7. The Equalizer (EQ)

- **Archetype:** Debuff / Support
- **Attack:** Deals no direct damage. Instead, **filters** enemies passing through its
  range — they take increased damage from all other sources for a duration (like
  stripping frequencies to expose vulnerabilities).
- **Fantasy:** The force multiplier. On its own, worthless. Paired with a Turntable and
  a Monitor? Devastating. This is the tower that separates good players from great ones.
- **Upgrade Direction:**
  - Stronger debuff percentage.
  - Longer debuff duration.
  - Specialised bands:
    - Low-Cut — also slows enemies.
    - Mid-Scoop — reduces enemy armour.
    - High-Boost — marks enemies for critical hits.

---

### 2.8. The Theremin

- **Archetype:** Sustained Beam
- **Attack:** Continuous damage beam that locks onto the nearest enemy. Damage **ramps
  up** the longer it stays locked on the same target. Resets if the target leaves range
  or dies.
- **Fantasy:** The patient tower. Melts anything that lingers. Punishes enemies slowed
  by the Subwoofer. The ramp-up prevents it from being a straight upgrade to the
  Turntable.
- **Upgrade Direction:**
  - Faster ramp-up rate.
  - Higher damage ceiling.
  - "Oscillation" mode — slowly sweeps between two targets without fully resetting.

---

## 3. Synergy Map

The best TD games reward **tower combinations**. Below are the key planned synergies:

```
Subwoofer (Slow) ──────► Theremin (longer lock-on = more ramp damage)
Subwoofer (Slow) ──────► Delay Pedal (more echo ticks land while slowed)
EQ (Debuff) ───────────► Monitor (amplified AoE = wave clear)
EQ (Debuff) ───────────► Tuning Fork (amplified burst = one-shots)
Compressor ─────────────► Boss waves (% damage scales with HP)
Tuning Fork ×2 ────────► Harmonic bonus (rewards double investment)
```

---

## 4. Trimming to 6 (If Required)

If 8 towers is too many for the prototype, the two candidates for removal are:

1. **The Theremin** — its "ramp-up beam" niche overlaps with the Compressor's anti-tank
   role. Could be merged into a Compressor upgrade path instead.
2. **The Delay Pedal** — DoT can feel invisible to players. Could be folded into the
   Turntable as an upgrade tier ("Echo Vinyl" mode).

This leaves a tight core six: **Turntable, Monitor, Subwoofer, Compressor, Tuning Fork,
Equalizer.**

---

## 5. Legacy Concept Mapping

| Original Concept | Roster Mapping | Notes |
|:---|:---|:---|
| Record Player | **Turntable** | Direct match — renamed to feel more "studio." |
| Speaker Tower | **Monitor** | Renamed to "Studio Monitor" to match DAW lexicon. |
| Vacuum Tube | **Compressor** | Reframed — "Vacuum Tube" is a component, not a device. The Compressor is the device with a clear mechanic (amplitude reduction = % damage). The tube aesthetic becomes its visual identity. |

---

## 6. Open Design Questions

- [ ] **Final roster size:** 6, 7, or 8 towers?
- [ ] **Stock values:** How many of each tower can be placed simultaneously?
- [ ] **AP costs:** Cost tiers per tower (Heavy / Medium / Light)?
- [ ] **Upgrade system:** Linear upgrade path or branching specialisations?
- [ ] **Upgrade cost:** Gold, AP, or a separate upgrade currency?
- [ ] **Stat values:** Base damage, range, fire rate, and cost for each tower.
- [ ] **Visual design:** Detailed art direction for each tower.
