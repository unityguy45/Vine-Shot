extends "res://scripts/enemies/enemy.gd"

@export var patrol_radius: float = 80.0
@export var look_time: float = 1.6

var _points: Array[Vector2] = []
var _index: int = 0
var _wait: float = 0.0
var _turned: bool = false

func _setup() -> void:
	var start := randf() * TAU
	for k in range(4):
		var a := start + TAU * float(k) / 4.0
		_points.append(Vector2(cos(a), sin(a) * 0.7) * randf_range(patrol_radius * 0.7, patrol_radius))

func _work(delta: float) -> void:
	var center: Vector2 = global_position
	if camp and is_instance_valid(camp):
		center = camp.global_position
	if _wait > 0.0:
		_stand()
		_wait -= delta
		if not _turned and _wait < look_time * 0.5:
			_turned = true
			_face(-facing)
		return
	if _move_to(center + _points[_index], walk_speed, delta):
		_wait = look_time
		_turned = false
		_index = (_index + 1) % _points.size()
