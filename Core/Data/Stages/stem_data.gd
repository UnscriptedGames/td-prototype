class_name StemData
extends Resource

## Defines a single stem level within a stage.
##
## Holds both the metadata (label, scene path) used by the Setlist UI
## and the gameplay configuration (waves) used by the level scene.

## Display label shown on the Setlist card (e.g., "Drums", "Bass").
@export var stem_label: String = ""

## Resource path to the level scene (.tscn) for this stem.
@export_file("*.tscn") var level_scene_path: String = ""

## If true, this stem must be completed before any others become available.
@export var is_mandatory_first: bool = false

## Placeholder hint describing the enemy composition for this stem.
@export var enemy_preview_hint: String = "Preview TBD"

## Wave definitions for this stem's gameplay.
@export var waves: Array[WaveData] = []
