extends Area2D

@export var speed: float = 320.0
@export var damage: float = 30.0
@export var lifetime: float = 1.0
@export var impact_effect: String = ""
@export var hit_radius: float = 9.0
@export var pierce: int = 0

var direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _done: bool = false
var _hit: Array = []
@onready var game_state = get_node("/root/GameState")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var sprite = get_node_or_null("Sprite")
	if sprite is AnimatedSprite2D:
		sprite.play()

func launch(target: Vector2) -> void:
	direction = target - global_position
	if direction.length() < 1.0:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if _done:
		return
	global_position += direction * speed * delta
	_life += delta
	for n in get_tree().get_nodes_in_group("enemies"):
		var enemy = n
		if enemy.health <= 0.0 or enemy in _hit:
			continue
		if global_position.distance_to(enemy.global_position + Vector2(0, -10)) < hit_radius:
			enemy.take_hit(damage, global_position - direction * 8.0)
			_hit.append(enemy)
			if pierce > 0:
				pierce -= 1
				continue
			_impact()
			return
	if _life >= lifetime:
		_impact()

func _on_body_entered(body) -> void:
	if _done or body.is_in_group("player"):
		return
	if body.has_method("take_hit"):
		body.take_hit(damage, global_position - direction * 8.0)
	_impact()

func _impact() -> void:
	if _done:
		return
	_done = true
	if impact_effect != "":
		game_state.spawn_effect(get_parent(), impact_effect, impact_effect, global_position)
	queue_free()
