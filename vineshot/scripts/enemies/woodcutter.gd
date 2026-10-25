extends "res://scripts/enemies/enemy.gd"

var job: String = "rest"
var tree = null
var carrying: bool = false
var _rest_t: float = 1.0

func _setup() -> void:
	_rest_t = randf_range(0.5, 2.0)
	anim.animation_looped.connect(_on_chop_swing)

func _walk_anim() -> String:
	return "carry" if carrying else "walk"

func _work(delta: float) -> void:
	match job:
		"rest":
			_stand()
			_rest_t -= delta
			if _rest_t <= 0.0:
				job = "find"
		"find":
			if carrying:
				job = "return"
				return
			tree = _nearest_tree()
			if tree:
				tree.claimed_by = self
				job = "go"
			else:
				job = "rest"
				_rest_t = 2.0
		"go":
			if not _tree_ok():
				job = "find"
				return
			if _move_to(tree.work_spot(global_position), walk_speed, delta):
				_face(tree.global_position - global_position)
				job = "chop"
		"chop":
			if not _tree_ok():
				job = "find"
				return
			velocity = Vector2.ZERO
			move_and_slide()
			_face(tree.global_position - global_position)
			_play("chop")
		"return":
			if camp == null or not is_instance_valid(camp):
				job = "rest"
				_rest_t = 3.0
				return
			if _move_to(camp.storage.drop_spot(), walk_speed, delta):
				camp.storage.deposit()
				carrying = false
				job = "rest"
				_rest_t = 1.0

func _on_chop_swing() -> void:
	if _dead or state != "work" or job != "chop" or anim.animation != "chop":
		return
	if not _tree_ok():
		return
	if tree.chop(self):
		tree = null
		carrying = true
		job = "return"

func _nearest_tree():
	var origin: Vector2 = global_position
	if camp and is_instance_valid(camp):
		origin = camp.global_position
	var best = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("trees"):
		var t = n
		if not t.standing:
			continue
		if t.claimed_by != null and is_instance_valid(t.claimed_by) and t.claimed_by != self:
			continue
		var d: float = origin.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	return best

func _tree_ok() -> bool:
	return tree != null and is_instance_valid(tree) and tree.standing and tree.claimed_by == self

func _release() -> void:
	if tree and is_instance_valid(tree) and tree.claimed_by == self:
		tree.claimed_by = null
	tree = null
	if job == "go" or job == "chop":
		job = "find"

func _on_alerted() -> void:
	_release()

func _on_death() -> void:
	_release()
	drop_wood()

func drop_wood() -> void:
	if not carrying:
		return
	carrying = false
	if job == "return":
		job = "find"
	var log_sprite := Sprite2D.new()
	log_sprite.texture = load("res://art/camp/png/log.png")
	log_sprite.z_index = -8
	get_parent().add_child(log_sprite)
	log_sprite.global_position = global_position
