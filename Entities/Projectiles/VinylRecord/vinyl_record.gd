extends TemplateProjectile
class_name VinylRecord

## A vinyl record projectile fired by the Turntable tower.
##
## Homes toward its target while visually spinning in flight.
##
## Base Level: Inherits all behaviour from TemplateProjectile.
## Future upgrade tiers will add overrides here:
## - Ricochet: bounce to a second target on impact.
## - Echo Spin: pierce through enemies in a line.

## Spin speed in radians per second while in flight.
const SPIN_SPEED: float = TAU * 3.0

@onready var projectile_sprite: Sprite2D = $Sprite


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if projectile_sprite:
		projectile_sprite.rotation += SPIN_SPEED * delta
