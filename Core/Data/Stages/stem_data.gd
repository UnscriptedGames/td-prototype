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

@export_group("Stem Settings")
## Delay before stem starts.
@export var start_delay: float = 0.0

## Multiplies rewards for this stem.
@export var reward_multiplier: float = 1.0

## The percentage of the stem's total enemy health required to fill the peak meter.
## e.g., 0.20 means 20% of the stem leaking causes failure.
@export var clip_tolerance: float = 0.20

## True if this is a boss stem.
@export var is_boss_stem: bool = false

## List of enemy spawn instructions for this entire stem.
@export var spawns: Array[SpawnInstruction] = []

@export_group("Stem Audio Layers")
## High quality layer (0-33% distortion)
@export var stem_audio_good: AudioStream

## Average quality layer (33-66% distortion)
@export var stem_audio_avg: AudioStream

## Abomination quality layer (66-100% distortion)
@export var stem_audio_bad: AudioStream
