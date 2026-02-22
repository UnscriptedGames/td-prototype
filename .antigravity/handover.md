# Handover: Peak Meter V2 & Signal Integrity System

## Current State
- **Peak Meter Overhaul:** The performance meter now operates on a `-5.0 to 100.0` range. 
    - The bottom `-5% to 0%` is a designated "Sub-Floor" noise segment (Grey/White).
    - The meter now reflects "Distortion" (counting up from 0% to 100%).
    - Performance thresholds (markers) are visually placed at 0%, 33%, and 66%.
- **Pinning Logic:** The bright Peak Hold line is strictly pinned to the mathematical damage total (ground truth) while the underlying bar fill jitters below it.
- **Shader:** `peak_meter.gdshader` updated to a 4-tier gradient (`color_sub`, `color_start`, `color_mid`, `color_end`).
- **Failure Logic:** `GameManager` now calculates `max_peak` per wave using `Enemy Health * Wave Clip Tolerance`.

## Signal Maps
- `GameManager.peak_changed(current: float, max_val: float)`: Dispatched when enemies leak or wave stats change. 
- `GameWindow._on_peak_changed(...)`: Listened to by the UI to update `_target_damage_value` and the `Distortion` label.

## Immediate Next Step
- **Stem Audio Integration:** Prepare the audio engine to handle stem layering (Drums, Bass, etc.) where play quality (Good/Average/Abomination) is determined by the Peak Meter's final position.

## Technical Debt / Notes
- `IntegrityValueLabel` in `game_window.tscn` was moved and updated; ensures future UI moves check the `@onready` path in `game_window.gd`.
- `clip_tolerance` is currently a `float` (e.g., `0.20`) in `WaveData.tres`.
