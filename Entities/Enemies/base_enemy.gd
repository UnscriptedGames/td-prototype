extends Area2D
## Base enemy for all enemy types

class_name BaseEnemy

signal death
signal reached_end


@export var max_health: int = 10
@export var speed: float = 60.0
@export var reward: int = 1
@export var data: EnemyData


var _health: int
var _variant: String = ""

@onready var animation := $Animation as AnimatedSprite2D
@onready var hitbox := $Hitbox as CollisionShape2D
@onready var health_bar := $HealthBar as TextureProgressBar


func _ready():
    if data:
        max_health = data.max_health
        speed = data.speed
        reward = data.reward
        _variant = data.variants[randi() % data.variants.size()]

    _health = max_health
    _update_health_bar()


func play_animation(action: String, direction: String, flip_h: bool = false):
    var animation_name = _variant + "_" + action + "_" + direction
    if animation and animation.has_animation(animation_name):
        animation.play(animation_name)
        animation.flip_h = flip_h


func reset():
    _health = max_health
    _update_health_bar()


func take_damage(amount: int):
    _health -= amount
    _update_health_bar()
    if _health <= 0:
        emit_signal("death")


func _update_health_bar():
    if health_bar:
        health_bar.value = float(_health) / float(max_health) * 100.0
