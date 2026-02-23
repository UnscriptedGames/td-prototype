# Handover: Peak Meter V2 & Signal Integrity System

## Current State
- **Stem Audio Integration:** `AudioManager` autoload handles real-time syncing of 3 stem variations (Good/Avg/Abomination). Crossfades volume based on `GameManager.peak_meter_changed`.
- **Peak Meter Overhaul:** Operates on a `-5.0 to 100.0` range with sub-floor noise. Pinning logic locks the ground truth peak line above the noisy fill. Wait for 100% distortion to trigger fail state.
- **Loadout Design:** Locked per Stage to ensure strategic tension ("The Studio" vs "The Live Set"). Safety valves defined via Setlist Preview and soft-counter universal viability.

## Signal Maps
- `GameManager.peak_meter_changed(current: float, max_val: float)`: Dispatched when enemies leak. Drives `AudioManager` crossfading and UI Distortion labels.
- `AudioManager.stem_quality_shifted(new_quality: StemQuality)`: Emitted when the real-time stem crosses a distortion threshold.

## Immediate Next Step
- **Tile Size Discussion:** Start the next session with a discussion about the size of the tiles used for the maze and background.
- **Design Studio Setlist Preview UI:** Build the warning/information panel in the loadout screen that shows players the upcoming wave threats to ensure fairness before locking in their loadout for the stage.

## Technical Debt / Notes
- `IntegrityValueLabel` in `game_window.tscn` was moved and updated; ensures future UI moves check the `@onready` path in `game_window.gd`.
- `clip_tolerance` is currently a `float` (e.g., `0.20`) in `WaveData.tres`.
