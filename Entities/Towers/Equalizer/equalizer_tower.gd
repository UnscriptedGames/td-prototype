extends TemplateTower
class_name EqualizerTower

@onready var pulse_ring: Sprite2D = $PulseRing

# The EQ tower does not deal direct damage. It only applies the AMPLIFY effect.
# We will create an equalizer_status.tres and assign it to the tower's status_effects list in the editor (or via its Config).

func _ready() -> void:
	super._ready()
	if pulse_ring:
		var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color.GREEN) # Neon green EQ bands
		pulse_ring.texture = ImageTexture.create_from_image(image)
		pulse_ring.visible = false
		pulse_ring.modulate.a = 0.0

func _spawn_projectiles() -> void:
	if not is_instance_valid(data):
		return
		
	# Play the visual pulse ring animation
	_play_pulse_animation()
		
	# Apply damage/effects to all valid enemies currently in range
	for target in _current_targets:
		if is_instance_valid(target) and target.state == TemplateEnemy.State.MOVING:
			# EQ deals no raw damage, only applies its status effects (AMPLIFY)
			for effect in status_effects:
				target.apply_status_effect(effect)

	_is_firing = false

func _play_pulse_animation() -> void:
	if not is_instance_valid(pulse_ring):
		return
		
	pulse_ring.visible = true
	
	# The visual range highlight uses highlight_tileset.tres which has 84x84 tiles.
	var highlight_tile_size_px: float = 84.0
	var bounds_width: float = (tower_range * 2 + 1) * highlight_tile_size_px
	
	var tex_size: Vector2 = pulse_ring.texture.get_size() if pulse_ring.texture else Vector2(64, 64)
	var target_scale_val: float = bounds_width / tex_size.x
	var target_scale := Vector2(target_scale_val, target_scale_val)

	pulse_ring.scale = Vector2(0.1, 0.1)
	pulse_ring.modulate.a = 0.8
	
	var tween: Tween = create_tween()
	
	tween.tween_property(pulse_ring, "scale", target_scale, 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		
	tween.tween_property(pulse_ring, "modulate:a", 0.0, 0.2)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	
	tween.tween_callback(func(): pulse_ring.visible = false)
