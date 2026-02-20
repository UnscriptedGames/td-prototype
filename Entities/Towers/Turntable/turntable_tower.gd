extends TemplateTower
class_name TurntableTower

## The Turntable — a projectile DPS tower that fires vinyl records.
##
## The workhorse tower of the game. Cheap, reliable single-target damage
## present in most loadouts. Themed as a DJ's turntable spinning discs
## at enemies.
##
## Overrides the base _attack() to use code-driven tweens for the
## tone arm sweep animation rather than AnimationPlayer tracks.


# --- ARM ANIMATION ---

@export_group("Arm Animation")

## Tone arm resting angle in degrees.
@export_range(0.0, 180.0, 0.5, "degrees") var arm_rest_angle_deg: float = 14.0

## Tone arm sweep angle in degrees.
@export_range(0.0, 180.0, 0.5, "degrees") var arm_sweep_angle_deg: float = 95.0

## Duration of the forward sweep in seconds.
@export_range(0.01, 2.0, 0.01, "suffix:s") var arm_sweep_duration: float = 0.12

## Duration of the return sweep in seconds.
@export_range(0.01, 2.0, 0.01, "suffix:s") var arm_return_duration: float = 0.25

# --- VINYL ANIMATION ---

@export_group("Vinyl Animation")

## Duration for the vinyl fade-out when fired.
@export_range(0.01, 1.0, 0.01, "suffix:s") var vinyl_fade_out_duration: float = 0.08

## Duration for the vinyl fade-in when a new record loads.
@export_range(0.01, 1.0, 0.01, "suffix:s") var vinyl_fade_in_duration: float = 0.2

## Idle vinyl rotation speed in radians per second.
@export_range(0.0, 20.0, 0.1, "radians_as_degrees") var vinyl_spin_speed: float = TAU * 0.5


# --- NODE REFERENCES ---

@onready var vinyl: Sprite2D = $Sprite/Vinyl
@onready var tone_arm: Sprite2D = $Sprite/ToneArm

## Current tween for the fire sequence. Tracked so we don't overlap.
var _fire_tween: Tween


# --- LIFECYCLE ---

func _ready() -> void:
	super._ready()
	tone_arm.rotation = deg_to_rad(arm_rest_angle_deg)


func _process(delta: float) -> void:
	super._process(delta)
	if vinyl:
		vinyl.rotation += vinyl_spin_speed * delta


# --- ATTACK OVERRIDE ---

## Overrides the base _attack() to use a tween-driven tone arm sweep
## instead of AnimationPlayer tracks. Spawns projectiles at the peak
## of the sweep and handles the vinyl fade-out/fade-in.
func _attack() -> void:
	if _current_targets.is_empty():
		state = State.IDLE
		return

	if not fire_rate_timer.is_stopped() or _is_firing or not projectile_scene:
		return

	_is_firing = true

	# Store target positions at the moment of attack.
	_targets_last_known_positions.clear()
	for target: TemplateEnemy in _current_targets:
		if is_instance_valid(target):
			if is_instance_valid(target.target_point):
				_targets_last_known_positions.append(
					target.target_point.global_position
				)
			else:
				_targets_last_known_positions.append(
					target.global_position
				)

	# Kill any existing fire tween to avoid overlaps.
	if _fire_tween and _fire_tween.is_valid():
		_fire_tween.kill()

	_fire_tween = create_tween()

	# 1. Sweep the tone arm from rest to peak.
	_fire_tween.tween_property(
		tone_arm, "rotation",
		deg_to_rad(arm_sweep_angle_deg), arm_sweep_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 2. At the peak: spawn projectiles and fade out the vinyl.
	_fire_tween.tween_callback(_spawn_projectiles)
	_fire_tween.tween_callback(_fade_out_vinyl)

	# 3. Return the tone arm to rest.
	_fire_tween.tween_property(
		tone_arm, "rotation",
		deg_to_rad(arm_rest_angle_deg), arm_return_duration
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	# 4. Fade the vinyl back in (new record loaded).
	_fire_tween.tween_callback(_fade_in_vinyl)

	# 5. Mark firing complete.
	_fire_tween.tween_callback(func() -> void: _is_firing = false)

	fire_rate_timer.start()


# --- VINYL VISIBILITY ---

## Fades the vinyl out at the moment of firing.
func _fade_out_vinyl() -> void:
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(
		vinyl, "modulate:a", 0.0, vinyl_fade_out_duration
	)


## Fades the vinyl back in after a brief pause (new record loaded).
func _fade_in_vinyl() -> void:
	# Reset rotation so the "new" record starts fresh.
	vinyl.rotation = 0.0
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(
		vinyl, "modulate:a", 1.0, vinyl_fade_in_duration
	)


# --- PROJECTILE SYNC ---

## Syncs the projectile's scale to match the vinyl's current global scale.
## This ensures the fired record looks exactly the same size as the one on the deck.
func _on_projectile_spawned(projectile: TemplateProjectile) -> void:
	# We use global_scale to account for the tower's own scale (0.075) and the vinyl's relative scale.
	# Applying this to the projectile's sprite ensures a 1:1 visual match.
	if is_instance_valid(projectile.sprite) and is_instance_valid(vinyl):
		projectile.sprite.global_scale = vinyl.global_scale
