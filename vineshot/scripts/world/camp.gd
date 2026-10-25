extends Node2D

signal cleared(camp: Node)
signal wood_stolen

const WOODCUTTER := "res://scenes/enemies/woodcutter.tscn"
const GUARD := "res://scenes/enemies/guard.tscn"

@export var woodcutters: int = 2
@export var guards: int = 1

var alive: int = 0
var is_cleared: bool = false

@onready var storage = $WoodStorage
@onready var campfire: AnimatedSprite2D = $Campfire

func _ready() -> void:
	add_to_group("camps")
	storage.wood_added.connect(_on_wood_added)
	campfire.play("burn")
	for i in range(woodcutters):
		_spawn(WOODCUTTER, Vector2(-16.0 + 32.0 * i, 26.0))
	for i in range(guards):
		_spawn(GUARD, Vector2(0.0, -26.0 - 10.0 * i))

func _spawn(path: String, offset: Vector2) -> void:
	var enemy = load(path).instantiate()
	enemy.camp = self
	enemy.position = offset
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	alive += 1

func _on_wood_added(_total: int) -> void:
	wood_stolen.emit()

func _on_enemy_died(_enemy: Node) -> void:
	alive -= 1
	if alive <= 0 and not is_cleared:
		is_cleared = true
		campfire.play("out")
		cleared.emit(self)
