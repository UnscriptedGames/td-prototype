# Handover

## Current State
- **Filesystem Restructured**: Successfully transitioned from "Levels" to **Stage & Stem** terminology.
- **Data Model Merged**: `LevelData` is eliminated. `StemData` is now the single source of truth for both metadata and wave data for a stem.
- **Audio Named**: All placeholder stems follow the `stem_XX_instrument.mp3` naming convention in `Stages/Stage01_FunkyGoldenSun/Audio/`.
- **Design Finalised**: Restart logic ("Option C"), Loadout locking, and Setlist Preview specs are finalised in `Knowledge/game_brief.md`.

## New Files
| File | Purpose |
|:---|:---|
| `Stages/_TemplateStage/*.gd` | Renamed template stage, data, and scene files |
| `Config/Stages/level_01_config.tres` | Moved from Config/Levels/ |

## Modified Files
| File | Change |
|:---|:---|
| `Core/Data/Stages/stem_data.gd` | Merged `waves` array into this class; dropped `StemInstrument` enum |
| `Stages/_TemplateStage/template_stage.gd` | References `StemData` instead of `LevelData` |
| `Systems/game_manager.gd` | Updated to handle `StemData` for level definitions |
| `Systems/scene_manager.gd` | Updated pool pre-warming for `StemData` structure |
| `Knowledge/game_brief.md` | Documented "Option C" restart logic and Setlist Specs |
| `Knowledge/ideas.md` | Documented Hybrid Dynamic Audio approach |

## Next Session
- **Testing Tool Implementation**: Discuss and implement tools for verifying wave spawns and audio quality shifts.
- **Setlist Preview UI Refinement**: Implement the `StemCard` visuals and Gating logic (Stem 1 mandatory).
- **Restart Hook**: Implement the "Restart Stem" and "Restart Stage" logic in the Pause Menu.
- **Audio Quality Crossfades**: Hook up the 3-tier layering in `AudioManager` using the new `StemData.waves` configuration.
