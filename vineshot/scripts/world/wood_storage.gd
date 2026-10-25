extends StaticBody2D

signal wood_added(total: int)

var wood: int = 0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("storages")
	_refresh()

func drop_spot() -> Vector2:
	return global_position + Vector2(0, 12)

func deposit() -> void:
	wood += 1
	_refresh()
	wood_added.emit(wood)

func _refresh() -> void:
	if wood == 0:
		anim.play("empty")
	elif wood < 3:
		anim.play("low")
	elif wood < 6:
		anim.play("half")
	else:
		anim.play("full")
