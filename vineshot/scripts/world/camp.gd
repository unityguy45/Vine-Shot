extends Node2D

signal cleared(camp: Node)
signal wood_stolen
signal alert_changed(camp: Node, level: int, reason: String)

const WOODCUTTER := "res://scenes/enemies/woodcutter.tscn"
const GUARD := "res://scenes/enemies/guard.tscn"

@export var woodcutters: int = 2
@export var guards: int = 1
@export var on_guard_time: float = 45.0
@export var start_alert: int = 0

var alive: int = 0
var is_cleared: bool = false
var alert_level: int = 0
var _guard_t: float = 0.0
var _reinforced: bool = false

@onready var storage = $WoodStorage
@onready var campfire: AnimatedSprite2D = $Campfire
@onready var tent: Node2D = $Tent
@onready var game_state = get_node("/root/GameState")

func _ready() -> void:
	add_to_group("camps")
	storage.wood_added.connect(_on_wood_added)
	campfire.play("burn")
	alert_level = start_alert
	for i in range(woodcutters):
		_spawn(WOODCUTTER, Vector2(-16.0 * (woodcutters - 1) + 32.0 * i, 26.0))
	for i in range(guards):
		_spawn(GUARD, Vector2(-14.0 * (guards - 1) + 28.0 * i, -28.0))

func _process(delta: float) -> void:
	if alert_level >= 2 and not is_cleared:
		_guard_t -= delta
		if _guard_t <= 0.0:
			alert_level = 1
			alert_changed.emit(self, alert_level, "calm")

func raise_alert(level: int, reason: String) -> void:
	if is_cleared:
		return
	if level >= 2:
		_guard_t = on_guard_time
	if level <= alert_level:
		return
	alert_level = level
	alert_changed.emit(self, alert_level, reason)
	if alert_level >= 2 and not _reinforced:
		_reinforced = true
		_send_reinforcement()

func _send_reinforcement() -> void:
	await get_tree().create_timer(3.0).timeout
	if is_cleared or not is_inside_tree():
		return
	var guard = _spawn(GUARD, tent.position + Vector2(0, 16))
	game_state.spawn_effect(self, "poof", "poof", guard.global_position + Vector2(0, -8))
	alert_changed.emit(self, alert_level, "reinforcement")

func _spawn(path: String, offset: Vector2):
	var enemy = load(path).instantiate()
	enemy.camp = self
	enemy.position = offset
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	alive += 1
	return enemy

func _on_wood_added(_total: int) -> void:
	wood_stolen.emit()

func _on_enemy_died(_enemy: Node) -> void:
	alive -= 1
	if alive <= 0 and not is_cleared:
		is_cleared = true
		alert_level = 0
		campfire.play("out")
		cleared.emit(self)
