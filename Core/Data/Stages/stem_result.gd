class_name StemResult
extends RefCounted

## Tracks the player's runtime result for a single stem during a stage attempt.
##
## This is NOT a saved Resource — it exists only in memory for the duration
## of a stage run and is wiped on stage restart.

enum StemStatus {
	LOCKED,
	AVAILABLE,
	COMPLETED,
}

enum StemQuality {
	NONE,
	GOOD,
	AVERAGE,
	ABOMINATION,
}

## Current availability state of this stem.
var status: StemStatus = StemStatus.LOCKED

## Best earned quality grade (only meaningful when status == COMPLETED).
var quality: StemQuality = StemQuality.NONE

## The quality track the player manually chooses to hear during playback.
## Defaults to matching `quality` when a new high score is achieved.
var active_playback_quality: StemQuality = StemQuality.NONE
