extends Area2D

@export var speed: float = 170.0
@export var lifetime: float = 1.1
@export var spin_speed: float = 18.0
@export var hit_radius: float = 8.0

var direction: Vector2 = Vector2.RIGHT
var damage: float = 10.0
var _life: float = 0.0
var _done: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var game_state = get_node("/root/GameState")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(target: Vector2, amount: float) -> void:
	damage = amount
	direction = target - global_position
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	sprite.flip_h = direction.x < 0.0

func _physics_process(delta: float) -> void:
	if _done:
		return
	global_position += direction * speed * delta
	sprite.rotation += spin_speed * delta * (-1.0 if direction.x < 0.0 else 1.0)
	_life += delta
	var player = get_tree().get_first_node_in_group("player")
	if player and not player.is_dead() and not player.is_dashing() and global_position.distance_to(player.global_position + Vector2(0, -8)) < hit_radius:
		player.take_damage(damage, direction * 90.0)
		_finish(false)
		return
	if _life >= lifetime:
		_finish(true)

func _on_body_entered(body) -> void:
	if _done or body.is_in_group("enemies") or body.is_in_group("player"):
		return
	_finish(true)

func _finish(dropped: bool) -> void:
	if _done:
		return
	_done = true
	if dropped:
		game_state.play_sfx("arrow_miss", global_position, -6.0, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
