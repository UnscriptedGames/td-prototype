# Rendering & Modulation Pattern

This document outlines the high-performance visual patterns used in **TD-Prototype** to maintain a "DAW-inspired" aesthetic with thousands of dynamic grid elements.

## 1. The Grayscale Modulation Pattern

To minimize asset bloat and maximize strategic flexibility, interactive grid assets (like launchpad buttons and background tiles) are generated as **pure grayscale templates**.

### How it works:
- **Source Asset:** A single `.png` containing light, mid, and dark gray values.
- **In-Game Logic:** The asset is tinted using Godot's `modulate` or `self_modulate` properties.
- **Result:** A single 28px texture can represent every color in the neon palette while preserving its 3D shading and internal "LED" glow.

### Tone Mapping for AI Generation:
When generating grayscale templates, use this value map:
| Tone | Purpose | Modulation Effect |
|:---|:---|:---|
| **White (#FFFFFF)** | LED / Inner Glow | Reflects the pure, vibrant target color. |
| **Light Grey** | Diffuse Surface | Reflects a tinted version of the target color. |
| **Dark Charcoal** | Shadows / Extrusion | Multplies toward black, preserving 3D depth. |

---

## 2. Performance: Batch Rendering vs. Nodes

For large-scale grids (e.g., the 1,600+ background tiles), naming and managing 1,600 `Sprite2D` nodes causes significant CPU overhead.

### The Batch Pattern:
- **System:** Use a single `Node2D` and override the `_draw()` function.
- **Command:** Use `draw_texture_rect()` inside a loop.
- **Advantage:** Godot automatically batches these draw calls into a single command for the GPU.
- **Animation:** Drive scale and position offsets via `Tweens` that fire `queue_redraw()`. This ensures zero overhead when the grid is static.

---

## 3. AI Asset Generation Master Prompt

To maintain the "silicone pad" aesthetic (low-profile, soft glow) instead of a "mechanical keyboard" look, use the following prompt structure:

### Master Prompt: Silicone Pad Template
> Top-down view of a single low-profile translucent silicone DJ soundpad button. Orthographic 2D game asset. Modern clean digital illustration. CRITICAL: Strictly grayscale (only black, white, and shades of gray). The pad is a simple, flat geometric square with softly rounded corners. Absolutely NO borders and NO outlines. The interior features a soft, diffuse white radial gradient in the exact center fading to mid-gray at the edges. To create chunky 3D depth, the bottom and right outer edges must have a heavy, prominent dark charcoal-grey 3D extrusion/drop shadow sloping downwards. Top/left edges have a crisp white bevel highlight. Solid neon green background (#00FF00).

---

## 4. Hardware vs. UI Threshold
- **Hardware Assets:** (Pads, Dials, Sliders) use the "chunky slab" depth and grayscale modulation.
- **UI Overlays:** (Menus, Inspector, Popups) use high-opacity (~95%) flat surfaces to ensure readability over the game deck.
