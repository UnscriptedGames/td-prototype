extends Node

## Central manager for music stems and dynamic audio quality layering.
##
## This autoload handles playing the current active stem across three
## distinct quality variations (Good, Average, Abomination), crossfading
## between them in real-time based on the Peak Meter (distortion level).
## It also preserves previously completed stems and plays them linearly.

# Signal definitions
signal stem_quality_shifted(new_quality: StemQuality)

enum StemQuality {
	GOOD,
	AVERAGE,
	ABOMINATION
}

# Thresholds that match the game's Peak Meter design (0, 0.33, 0.66, 1.0)
const THRESHOLD_AVG: float = 0.33
const THRESHOLD_BAD: float = 0.66

# Active Stem Players (Playing Simultaneously for Sync)
var _player_good: AudioStreamPlayer
var _player_avg: AudioStreamPlayer
var _player_bad: AudioStreamPlayer

# Historical Stem Players (Playing Simultaneously at locked qualities)
var _historical_players: Array[AudioStreamPlayer] = []

var _current_quality: StemQuality = StemQuality.GOOD

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep music running if pausing isn't halting tracks
	_setup_audio_players()
	
	# Connect to GameManager to receive peak meter updates
	if GameManager:
		GameManager.peak_meter_changed.connect(_on_peak_meter_changed)
		GameManager.wave_changed.connect(_on_wave_changed)
		GameManager.game_state_changed.connect(_on_game_state_changed)

func _exit_tree() -> void:
	if is_instance_valid(GameManager):
		if GameManager.peak_meter_changed.is_connected(_on_peak_meter_changed):
			GameManager.peak_meter_changed.disconnect(_on_peak_meter_changed)
		if GameManager.wave_changed.is_connected(_on_wave_changed):
			GameManager.wave_changed.disconnect(_on_wave_changed)
		if GameManager.game_state_changed.is_connected(_on_game_state_changed):
			GameManager.game_state_changed.disconnect(_on_game_state_changed)

func _setup_audio_players() -> void:
	_player_good = AudioStreamPlayer.new()
	_player_good.name = "StemGood"
	_player_good.bus = "Music" # Assuming a Music bus exists or will exist
	add_child(_player_good)
	
	_player_avg = AudioStreamPlayer.new()
	_player_avg.name = "StemAvg"
	_player_avg.bus = "Music"
	add_child(_player_avg)
	
	_player_bad = AudioStreamPlayer.new()
	_player_bad.name = "StemBad"
	_player_bad.bus = "Music"
	add_child(_player_bad)
	
	# Start with only 'Good' audible
	_set_volumes(StemQuality.GOOD)

## Starts playing the specific stems for a new level
func play_stem(stem_data: StemData) -> void:
	if not stem_data:
		_stop_all()
		return
		
	# 1. Clean up old historical players
	for player in _historical_players:
		if is_instance_valid(player):
			player.queue_free()
	_historical_players.clear()
	
	# 2. Setup active stem's 3-track dynamic playback
	_player_good.stream = stem_data.stem_audio_good
	_player_avg.stream = stem_data.stem_audio_avg
	_player_bad.stream = stem_data.stem_audio_bad
	
	_current_quality = StemQuality.GOOD
	_set_volumes(_current_quality)
	
	# 3. Setup historical locked-quality playback
	if StageManager and StageManager.active_stage:
		var current_index: int = StageManager.current_stem_index
		
		# Iterate through all stems in the stage
		for index in range(StageManager.stem_results.size()):
			# Skip the currently active stem (it's handled by the dynamic players)
			if index == current_index:
				continue
				
			# Ensure we have a valid result and stem data to read from
			if index >= StageManager.active_stage.stems.size():
				continue
				
			var result: StemResult = StageManager.stem_results[index]
			var historical_stem_data: StemData = StageManager.active_stage.stems[index]
			
			if result.status == StemResult.StemStatus.COMPLETED and is_instance_valid(historical_stem_data):
				# Pick the stream matching their manual playback selection
				var stream: AudioStream = null
				if result.active_playback_quality == StemResult.StemQuality.ABOMINATION:
					stream = historical_stem_data.stem_audio_bad
				elif result.active_playback_quality == StemResult.StemQuality.AVERAGE:
					stream = historical_stem_data.stem_audio_avg
				else:
					# Default to Good if None or Good
					stream = historical_stem_data.stem_audio_good
					
				# Create a dedicated player for this historical stem
				if stream:
					var historical_player := AudioStreamPlayer.new()
					historical_player.name = "HistoricalStem_%d" % index
					historical_player.bus = "Music"
					historical_player.stream = stream
					add_child(historical_player)
					_historical_players.append(historical_player)

	# 4. Play EVERYTHING at the precise same moment for perfect phase sync
	_player_good.play()
	_player_avg.play()
	_player_bad.play()
	
	for hist_player in _historical_players:
		hist_player.play()

func _stop_all() -> void:
	_player_good.stop()
	_player_avg.stop()
	_player_bad.stop()
	
	for player in _historical_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_historical_players.clear()

## Called when the GameManager updates the peak meter.
## current: specific distortion number
## maximum_value: the failure point (100% capacity)
func _on_peak_meter_changed(current: float, maximum_value: float) -> void:
	if maximum_value <= 0.0:
		return
		
	var ratio: float = current / maximum_value
	var target_quality: StemQuality = StemQuality.GOOD
	
	if ratio >= THRESHOLD_BAD:
		target_quality = StemQuality.ABOMINATION
	elif ratio >= THRESHOLD_AVG:
		target_quality = StemQuality.AVERAGE
		
	if target_quality != _current_quality:
		_current_quality = target_quality
		_transition_to_quality(_current_quality)

func _transition_to_quality(quality: StemQuality) -> void:
	# For now, popping the volumes immediately. 
	# A Tween can be added here for smooth crossfading if dictated by design polish later.
	_set_volumes(quality)
	stem_quality_shifted.emit(quality)
	
	if OS.is_debug_build():
		print("AudioManager: Stem Quality Shifted -> ", StemQuality.keys()[quality])

func _set_volumes(target_quality: StemQuality) -> void:
	var volume_on: float = 0.0
	var volume_off: float = -80.0 # Effectively muted but keeps playing
	
	match target_quality:
		StemQuality.GOOD:
			_player_good.volume_db = volume_on
			_player_avg.volume_db = volume_off
			_player_bad.volume_db = volume_off
		StemQuality.AVERAGE:
			_player_good.volume_db = volume_off
			_player_avg.volume_db = volume_on
			_player_bad.volume_db = volume_off
		StemQuality.ABOMINATION:
			_player_good.volume_db = volume_off
			_player_avg.volume_db = volume_off
			_player_bad.volume_db = volume_on

func _on_wave_changed(_current_wave: int, _total_waves: int) -> void:
	# Hook to grab the new stem data from GameManager when it starts
	var level_data = GameManager.level_data
	if level_data and _current_wave > 0:
		play_stem(level_data)
	else:
		_stop_all()


## Pauses or resumes stem playback to stay in sync with the game pause state.
func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	var is_paused: bool = (new_state == GameManager.GameState.PAUSED)
	_player_good.stream_paused = is_paused
	_player_avg.stream_paused = is_paused
	_player_bad.stream_paused = is_paused
	
	for player in _historical_players:
		if is_instance_valid(player):
			player.stream_paused = is_paused
