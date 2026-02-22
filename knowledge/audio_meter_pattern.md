# KI: Audio Meter Implementation Pattern

## Overview
This Knowledge Item documents the implementation of the "DAW-style" audio peak meters in the project, which avoids gradient squashing and supports rounded corners.

## Key Path
- **Scene**: `res://UI/Layout/game_window.tscn`
- **Shader**: `res://UI/Shaders/peak_meter.gdshader`
- **Styles**: `res://UI/Themes/meter_clipper_style.tres`

## Pattern Details

### 1. Rounded Corners via Clipping
Because `StyleBoxTexture` (used for gradients) does not support individual corner radii, the meters use a **Clipping Container** pattern:
- A `Panel` container (`BarContainerL/R`) with a `StyleBoxFlat` applied.
- `CanvasItem.clip_children` is set to `Clip + Draw`.
- The `ProgressBar` is nested inside, and its corners are masked by the parent panel.

### 2. Static Gradient Shader
To prevent the gradient from "stretching" or "squashing" as the value changes:
- A custom shader (`peak_meter.gdshader`) uses `VERTEX.x` relative to `total_width` to map colors.
- **4-Tier Gradient:** Supports `color_sub` (Grey/White), `color_start` (Green), `color_mid` (Yellow), and `color_end` (Red).
- **Sub-Floor Mapping:** The physical bar represents a span of **105 units** (-5.0 to 100.0). Shader thresholds (`threshold_zero`, `threshold_low`, `threshold_high`) are adjusted to align with physical segment markers.
- **Reveal Effect:** The gradient appears static beneath the bar's value.
- **Peak Hold Pinning:** The peak hold line is strictly locked to the tracked gameplay value without decay or jitter, providing a sharp "truth" indicator above the noisy fill.

### 3. Theme Cleanup
- Legacy styles like `MeterBorder` and `MeterPanel` have been removed in favor of this nested container + shader approach.

### 4. Unscaled Animation Handling
To ensure standard DAW-style meter responsiveness even when the game is fast-forwarding (e.g., 4x speed):
- The `game_window.gd` script calculates an `unscaled_delta`: 
  `delta / Engine.time_scale if time_scale > 0.0 else 0.0`.
- The `lerp` for the meter needle uses this unscaled value, preventing the UI from becoming hyper-fast or jittery during high-speed wave playback.
