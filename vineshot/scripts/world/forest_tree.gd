extends StaticBody2D

signal felled(tree: Node)

@export_enum("oak", "pine") var kind: String = "oak"
@export var max_health: int = 6

var health: int
var standing: bool = true
var claimed_by = null

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var stump: Sprite2D = $Stump
@onready var trunk: CollisionShape2D = $CollisionShape2D
@onready var game_state = get_node("/root/GameState")

func _ready() -> void:
	add_to_group("trees")
	health = max_health
	stump.visible = false
	anim.animation_finished.connect(_on_anim_finished)
	anim.play("sway")
	anim.frame = randi() % 4
	anim.speed_scale = randf_range(0.8, 1.2)

func work_spot(from: Vector2) -> Vector2:
	var side := -1.0 if from.x < global_position.x else 1.0
	return global_position + Vector2(side * 11.0, 1.0)

func chop(_by: Node) -> bool:
	if not standing:
		return false
	health -= 1
	game_state.spawn_effect(get_parent(), "wood_chips", "burst", global_position + Vector2(0, -8))
	if health <= 0:
		_fall()
		return true
	anim.play("hit")
	return false

func _fall() -> void:
	standing = false
	claimed_by = null
	remove_from_group("trees")
	trunk.set_deferred("disabled", true)
	game_state.spawn_effect(get_parent(), "leaf_fall", "fall", global_position + Vector2(0, -30))
	if kind == "oak":
		anim.sprite_frames = game_state.frames("oak_fall")
		anim.offset = Vector2(16, -15)
		anim.speed_scale = 1.0
		anim.play("fall")
	else:
		anim.visible = false
		stump.visible = true
		game_state.spawn_effect(get_parent(), "poof", "poof", global_position + Vector2(0, -10))
	felled.emit(self)

func _on_anim_finished() -> void:
	if anim.animation == "hit":
		anim.play("sway")
	elif anim.animation == "fall":
		anim.visible = false
		stump.visible = true
