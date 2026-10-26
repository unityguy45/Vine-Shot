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
	var guarded := alert_level() >= 2
	if _wait > 0.0:
		_stand()
		_wait -= delta
		if not _turned and _wait < look_time * 0.5:
			_turned = true
			_face(facing.rotated(PI + randf_range(-0.6, 0.6)))
		return
	var reach := 1.45 if guarded else 1.0
	if _move_to(center + _points[_index] * reach, walk_speed * (1.35 if guarded else 1.0), delta):
		_wait = look_time * (0.7 if guarded else 1.0)
		_turned = false
		_index = (_index + 1) % _points.size()
