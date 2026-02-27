extends Node

## Manages stage-level progression and stem state for the current run.
##
## Sits between the Setlist UI and GameManager/SceneManager. Owns the
## active StageData, tracks per-stem results (StemResult), and controls
## stem availability gating (Stem 1 → Stems 2-5 → Boss).

# --- Signals ---

## Emitted when a new stage is loaded and the Setlist should populate.
signal stage_loaded(stage_data: StageData)

## Emitted when a stem's status or quality changes and its card should update.
signal stem_status_changed(stem_index: int, result: StemResult)

## Emitted when a full stage restart occurs and all cards should reset.
signal stage_restarted


# --- Constants ---

## Total number of playable stems (excluding the boss).
const STEM_COUNT: int = 5

## Index used for the boss stem in the results array.
const BOSS_INDEX: int = 5

## Peak meter ratio thresholds matching AudioManager/game_brief.md zones.
const THRESHOLD_AVG: float = 0.33
const THRESHOLD_BAD: float = 0.66

## Resource path for returning to the Setlist between stems.
const SETLIST_SCENE_PATH: String = "res://UI/Setlist/setlist_screen.tscn"


# --- State ---

## The stage definition for the current run.
var _active_stage: StageData

## Runtime results for each stem (indices 0-4) + boss (index 5).
var _stem_results: Array[StemResult] = []

## Index of the stem currently being played (-1 if on setlist screen).
var _current_stem_index: int = -1

## True after the player starts their first stem, locking the loadout.
var _loadout_locked: bool = false


# --- Getters ---

var active_stage: StageData:
	get: return _active_stage

var stem_results: Array[StemResult]:
	get: return _stem_results

var current_stem_index: int:
	get: return _current_stem_index

var loadout_locked: bool:
	get: return _loadout_locked


# --- Public Methods ---

## Initialises the stage run. Sets Stem 1 to AVAILABLE, all others LOCKED.
func load_stage(stage_data: StageData) -> void:
	_active_stage = stage_data
	_current_stem_index = -1
	_loadout_locked = false
	_initialise_results()
	GameManager.stem_completion_requested.connect(_on_stem_completion_requested)
	GameManager.stem_failed.connect(_on_stem_failed)
	stage_loaded.emit(stage_data)


## Starts a specific stem level by index. Validates availability first.
func start_stem(stem_index: int) -> void:
	if stem_index < 0 or stem_index > BOSS_INDEX:
		push_warning("StageManager: Invalid stem index %d." % stem_index)
		return

	var result: StemResult = _stem_results[stem_index]
	if result.status == StemResult.StemStatus.LOCKED:
		push_warning("StageManager: Stem %d is locked." % stem_index)
		return

	_current_stem_index = stem_index
	_loadout_locked = true

	# Reset GameManager state for a fresh stem play.
	GameManager.reset_state()

	# Determine the scene path and stem data from the stage data.
	var scene_path: String = _get_scene_path(stem_index)
	if scene_path.is_empty():
		push_error("StageManager: No scene path for stem index %d." % stem_index)
		return
		
	var stem_data: StemData = _get_stem_data(stem_index)

	SceneManager.load_scene(scene_path, SceneManager.ViewType.LEVEL, stem_data)


## Records the completion of the current stem with a quality grade.
## Called by the level/GameManager when the final wave is cleared.
func complete_stem(quality: StemResult.StemQuality) -> void:
	if _current_stem_index < 0:
		push_warning("StageManager: No active stem to complete.")
		return

	var result: StemResult = _stem_results[_current_stem_index]
	result.status = StemResult.StemStatus.COMPLETED

	# Best Score Keeps: Only overwrite quality if we did better (lower enum integer).
	# NONE (0) is lower than GOOD (1), so handle that specific upgrade safely.
	var old_quality: int = result.quality
	if old_quality == StemResult.StemQuality.NONE or quality < old_quality:
		result.quality = quality
		# Sync the active playback quality so the player hears their new high score.
		result.active_playback_quality = quality

	stem_status_changed.emit(_current_stem_index, result)

	# Unlock the next tier of stems based on what was just completed.
	_unlock_next_stems()

	var completed_index: int = _current_stem_index
	_current_stem_index = -1

	if OS.is_debug_build():
		var quality_name: String = StemResult.StemQuality.keys()[quality]
		print("StageManager: Stem %d completed with %s quality." % [
			completed_index, quality_name
		])


## Restarts the current stem without resetting stage progress.
func restart_stem() -> void:
	if _current_stem_index < 0:
		push_warning("StageManager: No active stem to restart.")
		return

	start_stem(_current_stem_index)


## Wipes all stem results and returns to the initial state.
## Unlocks the loadout so the player can reconfigure in the Studio.
func restart_stage() -> void:
	_current_stem_index = -1
	_loadout_locked = false
	_initialise_results()
	stage_restarted.emit()

	if OS.is_debug_build():
		print("StageManager: Stage restarted. All progress wiped.")


## Returns the number of completed stems (excluding the boss).
func get_completed_stem_count() -> int:
	var count: int = 0
	for index: int in range(STEM_COUNT):
		if _stem_results[index].status == StemResult.StemStatus.COMPLETED:
			count += 1
	return count


## Determines the quality grade from the current peak meter ratio.
## Called at wave/stem end to translate the meter position into a grade.
func determine_quality_from_peak() -> StemResult.StemQuality:
	if GameManager.max_peak <= 0.0:
		return StemResult.StemQuality.GOOD

	var ratio: float = GameManager.current_peak / GameManager.max_peak

	if ratio >= THRESHOLD_BAD:
		return StemResult.StemQuality.ABOMINATION
	elif ratio >= THRESHOLD_AVG:
		return StemResult.StemQuality.AVERAGE
	else:
		return StemResult.StemQuality.GOOD


## Retries the currently failed stem by using the remembered index.
func retry_stem() -> void:
	if _current_stem_index >= 0:
		_stop_current_stem_audio()
		start_stem(_current_stem_index)
	else:
		push_error("StageManager: No active stem to retry.")


## Clears the current stem index and returns to the setlist preview screen.
func return_to_setlist() -> void:
	_current_stem_index = -1
	_stop_current_stem_audio()
	SceneManager.load_scene(SETLIST_SCENE_PATH, SceneManager.ViewType.MENU)


## Finds the StemAudioPlayer node in the live scene tree and stops it immediately.
## Called before any scene transition to prevent audio from bleeding into the next scene.
func _stop_current_stem_audio() -> void:
	# 1. Stop the new global audio manager (which plays the layered stems)
	if AudioManager and AudioManager.has_method("_stop_all"):
		AudioManager._stop_all()

	# 2. Stop the local TemplateStage audio player (if it hasn't been removed yet)
	var root: Window = get_tree().root
	for child: Node in root.get_children():
		if child is GameWindow:
			var subviewport: Node = child.get_node_or_null(
				"MainLayout/WorkspaceSplit/GameViewWrapper/GameViewContainer/SubViewport"
			)
			if not subviewport:
				return
			for level: Node in subviewport.get_children():
				var player: Node = level.get_node_or_null("StemAudioPlayer")
				if player is AudioStreamPlayer and player.playing:
					player.stop()
					if OS.is_debug_build():
						print("StageManager: Local Stem audio stopped before scene transition.")
			return


# --- Private Methods ---

## Handles a normal stem completion event from GameManager.
## Grades the stem quality, records the result, and returns to the Setlist.
func _on_stem_completion_requested() -> void:
	if _current_stem_index < 0:
		return
	var quality: StemResult.StemQuality = determine_quality_from_peak()
	complete_stem(quality)
	return_to_setlist()


## Handles an immediate stem fail event from GameManager (peak meter clipped).
func _on_stem_failed() -> void:
	if _current_stem_index < 0:
		return
	var result: StemResult = _stem_results[_current_stem_index]
	
	# Failure Preservation: Do not wipe progress if this was already beaten.
	if result.status != StemResult.StemStatus.COMPLETED:
		result.status = StemResult.StemStatus.AVAILABLE
		result.quality = StemResult.StemQuality.NONE
		
	stem_status_changed.emit(_current_stem_index, result)

	if OS.is_debug_build():
		print("StageManager: Stem failed — peak meter clipped. Awaiting user popup action.")


## Creates fresh StemResult objects for all 6 slots (5 stems + 1 boss).
## Stem 1 (index 0) starts as AVAILABLE; everything else starts LOCKED.
func _initialise_results() -> void:
	_stem_results.clear()
	for index: int in range(STEM_COUNT + 1):
		var result := StemResult.new()
		if index == 0:
			result.status = StemResult.StemStatus.AVAILABLE
		_stem_results.append(result)
		stem_status_changed.emit(index, result)


## Opens stems based on progression rules:
## - Completing Stem 1 unlocks Stems 2-5.
## - Completing all 5 stems unlocks the Boss.
func _unlock_next_stems() -> void:
	if _current_stem_index == 0:
		# Stem 1 completed: unlock the middle 4 stems.
		for index: int in range(1, STEM_COUNT):
			if _stem_results[index].status == StemResult.StemStatus.LOCKED:
				_stem_results[index].status = StemResult.StemStatus.AVAILABLE
				stem_status_changed.emit(index, _stem_results[index])

	# Check if all 5 stems are complete to unlock the boss.
	if get_completed_stem_count() >= STEM_COUNT:
		if _stem_results[BOSS_INDEX].status == StemResult.StemStatus.LOCKED:
			_stem_results[BOSS_INDEX].status = StemResult.StemStatus.AVAILABLE
			stem_status_changed.emit(BOSS_INDEX, _stem_results[BOSS_INDEX])


## Resolves the level scene path for a given stem index.
func _get_scene_path(stem_index: int) -> String:
	if not _active_stage:
		return ""

	if stem_index == BOSS_INDEX:
		if _active_stage.boss_stem:
			return _active_stage.boss_stem.level_scene_path
		return ""

	if stem_index >= 0 and stem_index < _active_stage.stems.size():
		return _active_stage.stems[stem_index].level_scene_path

	return ""

## Resolves the StemData resource for a given stem index.
func _get_stem_data(stem_index: int) -> StemData:
	if not _active_stage:
		return null

	if stem_index == BOSS_INDEX:
		return _active_stage.boss_stem

	if stem_index >= 0 and stem_index < _active_stage.stems.size():
		return _active_stage.stems[stem_index]

	return null
