class_name StageData
extends Resource

## Defines the structure of a single stage (one "song").
##
## A stage groups 5 playable stems and 1 boss stem into a complete
## musical experience. Stem order: [0] = mandatory first, [1-4] = free choice.

## Display name for this stage (e.g., "Track 01 — Neon Pulse").
@export var stage_name: String = ""

## Sequential stage number used for progression gating.
@export var stage_number: int = 1

## The 5 playable stem levels in order. Index 0 is always mandatory first.
@export var stems: Array[StemData] = []

## The boss encounter that unlocks after all 5 stems are completed.
@export var boss_stem: StemData
