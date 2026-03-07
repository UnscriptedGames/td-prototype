extends TemplateTower
class_name MonitorTower

@onready var pulse_ring: Sprite2D = $PulseRing

func _ready() -> void:
    super._ready()
    if pulse_ring:
        # PlaceholderTexture2D may not render as a filled rect at runtime.
        # Generate a real 64x64 solid white texture instead.
        var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
        image.fill(Color.WHITE)
        pulse_ring.texture = ImageTexture.create_from_image(image)
        pulse_ring.visible = false
        pulse_ring.modulate.a = 0.0

func _spawn_projectiles() -> void:
    if not is_instance_valid(data):
        return
        
    # Play the visual pulse ring animation
    _play_pulse_animation()
        
    # Apply damage to all valid enemies currently in range
    for target in _current_targets:
        if is_instance_valid(target) and target.state == TemplateEnemy.State.MOVING:
            target.health -= damage
            
            # Apply any status effects (though Monitor base just deals damage)
            for effect in status_effects:
                target.apply_status_effect(effect)

    _is_firing = false


func _play_pulse_animation() -> void:
    if not is_instance_valid(pulse_ring):
        return
        
    pulse_ring.visible = true
    
    # The visual range highlight uses highlight_tileset.tres which has 84x84 tiles,
    # NOT the 64x64 collision tiles. The pulse must match what the player SEES.
    var highlight_tile_size_px: float = 84.0
    var bounds_width: float = (tower_range * 2 + 1) * highlight_tile_size_px # For range 1: 3*84 = 252
    
    # Query the actual texture size at runtime
    var tex_size: Vector2 = pulse_ring.texture.get_size() if pulse_ring.texture else Vector2(64, 64)
    var target_scale_val: float = bounds_width / tex_size.x
    var target_scale := Vector2(target_scale_val, target_scale_val)

    # Reset starting state
    pulse_ring.scale = Vector2(0.1, 0.1)
    pulse_ring.modulate.a = 0.8
    
    var tween: Tween = create_tween()
    
    # Scale up fast while staying visible
    tween.tween_property(pulse_ring, "scale", target_scale, 0.25)\
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
        
    # Then fade out at max scale
    tween.tween_property(pulse_ring, "modulate:a", 0.0, 0.2)\
        .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
    
    tween.tween_callback(func(): pulse_ring.visible = false)
