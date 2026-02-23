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

var _current_quality: StemQuality = StemQuality.GOOD

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep music running if pausing isn't halting tracks
	_setup_audio_players()
	
	# Connect to GameManager to receive peak meter updates
	if GameManager:
		GameManager.peak_meter_changed.connect(_on_peak_meter_changed)
		GameManager.wave_changed.connect(_on_wave_changed)

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

## Starts playing the specific stems for a new wave/level
func play_stem(wave_data: WaveData) -> void:
	if not wave_data:
		_stop_all()
		return
		
	_player_good.stream = wave_data.stem_audio_good
	_player_avg.stream = wave_data.stem_audio_avg
	_player_bad.stream = wave_data.stem_audio_bad
	
	_current_quality = StemQuality.GOOD
	_set_volumes(_current_quality)
	
	_player_good.play()
	_player_avg.play()
	_player_bad.play()

func _stop_all() -> void:
	_player_good.stop()
	_player_avg.stop()
	_player_bad.stop()

## Called when the GameManager updates the peak meter.
## current: specific distortion number
## max_val: the failure point (100% capacity)
func _on_peak_meter_changed(current: float, max_val: float) -> void:
	if max_val <= 0.0:
		return
		
	var ratio: float = current / max_val
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
	var vol_on: float = 0.0
	var vol_off: float = -80.0 # Effectively muted but keeps playing
	
	match target_quality:
		StemQuality.GOOD:
			_player_good.volume_db = vol_on
			_player_avg.volume_db = vol_off
			_player_bad.volume_db = vol_off
		StemQuality.AVERAGE:
			_player_good.volume_db = vol_off
			_player_avg.volume_db = vol_on
			_player_bad.volume_db = vol_off
		StemQuality.ABOMINATION:
			_player_good.volume_db = vol_off
			_player_avg.volume_db = vol_off
			_player_bad.volume_db = vol_on

func _on_wave_changed(_current_wave: int, _total_waves: int) -> void:
	# Hook to grab the new wave data from GameManager when it starts
	var level_data = GameManager.level_data
	if level_data and _current_wave > 0 and _current_wave <= level_data.waves.size():
		var wave: WaveData = level_data.waves[_current_wave - 1]
		play_stem(wave)
	else:
		_stop_all()
