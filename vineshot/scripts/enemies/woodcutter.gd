extends "res://scripts/enemies/enemy.gd"

var job: String = "rest"
var tree = null
var carrying: bool = false
var _rest_t: float = 1.0
var _throw_cd: float = 1.0
var _looking: float = 0.0

const AXE := "res://scenes/combat/thrown_axe.tscn"

@export var throw_cooldown: float = 2.6
@export var throw_range: float = 120.0

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
			if _looking > 0.0:
				_looking -= delta
				_play("idle")
				return
			if alert_level() >= 2:
				_look_t -= delta
				if _look_t <= 0.0:
					_look_t = randf_range(2.5, 4.5)
					_looking = randf_range(1.0, 1.6)
					_face(Vector2.RIGHT.rotated(randf() * TAU))
					return
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
	game_state.play_sfx("chop", global_position, -8.0, 0.15)
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
	if carrying:
		var log_sprite := Sprite2D.new()
		log_sprite.texture = load("res://art/camp/png/log.png")
		log_sprite.z_index = -8
		get_parent().add_child(log_sprite)
		log_sprite.global_position = global_position

func _physics_process(delta: float) -> void:
	_throw_cd = maxf(_throw_cd - delta, 0.0)
	super(delta)

func _ranged(_delta: float, dist: float) -> bool:
	if _throw_cd > 0.0 or dist < 34.0 or dist > throw_range or _locked != "":
		return false
	_throw_cd = throw_cooldown * randf_range(0.85, 1.2)
	_stand()
	_face(player.global_position - global_position)
	_lock("chop")
	_throw_axe()
	return true

func _throw_axe() -> void:
	await get_tree().create_timer(0.22).timeout
	if _dead or player == null or not is_instance_valid(player) or not is_inside_tree():
		return
	var axe = load(AXE).instantiate()
	get_parent().add_child(axe)
	axe.global_position = global_position + Vector2(facing.x * 6.0, -12.0)
	var lead: Vector2 = player.velocity * 0.18
	axe.launch(player.global_position + lead + Vector2(0, -8), attack_damage)
	game_state.play_sfx("axe_throw", global_position, -3.0)
