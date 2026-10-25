extends Area2D

@export_enum("snare", "spike_pit") var kind: String = "snare"
@export var hold_time: float = 3.0
@export var damage: float = 15.0

var armed: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var game_state = get_node("/root/GameState")

func _ready() -> void:
	add_to_group("traps")
	body_entered.connect(_on_body_entered)
	if kind == "snare" and game_state.has_skill("bear_trap"):
		sprite.texture = load("res://art/traps/png/bear_trap.png")

func _on_body_entered(body) -> void:
	if not armed or not body.is_in_group("enemies"):
		return
	var enemy = body
	if enemy.health <= 0.0:
		return
	armed = false
	if kind == "snare":
		enemy.root_for(hold_time)
		if game_state.has_skill("bear_trap"):
			sprite.texture = load("res://art/traps/png/bear_trap_sprung.png")
			if enemy.has_method("drop_wood"):
				enemy.drop_wood()
			enemy.take_hit(damage, global_position, false)
		else:
			sprite.texture = load("res://art/traps/png/snare_sprung.png")
	else:
		sprite.texture = load("res://art/traps/png/spike_pit_sprung.png")
		enemy.root_for(1.0)
		enemy.take_hit(damage, global_position)
	game_state.spawn_effect(get_parent(), "dash_dust", "puff", global_position)
	await get_tree().create_timer(hold_time).timeout
	_fade()

func pick_up() -> void:
	if not armed:
		return
	armed = false
	game_state.spawn_effect(get_parent(), "dash_dust", "puff", global_position)
	queue_free()

func _fade() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
