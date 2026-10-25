extends CharacterBody2D

signal died(enemy: Node)

const CONE_WORK := Color(1.0, 0.95, 0.55, 0.16)
const CONE_SEARCH := Color(1.0, 0.7, 0.3, 0.22)
const CONE_ALERT := Color(1.0, 0.3, 0.25, 0.26)

@export var max_health: float = 60.0
@export var walk_speed: float = 34.0
@export var run_speed: float = 70.0
@export var vision_range: float = 95.0
@export var vision_angle: float = 70.0
@export var hearing_range: float = 22.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 16.0
@export var attack_cooldown: float = 1.2
@export var alert_time: float = 0.6
@export var forget_time: float = 3.0
@export var search_time: float = 2.6
@export var sneak_multiplier: float = 3.0

var camp
var health: float
var facing: Vector2 = Vector2.RIGHT
var state: String = "work"
var player
var last_seen: Vector2 = Vector2.ZERO

var _alert_t: float = 0.0
var _lost_t: float = 0.0
var _search_t: float = 0.0
var _turn_t: float = 0.0
var _attack_cd: float = 0.0
var _locked: String = ""
var _dead: bool = false
var _stuck_t: float = 0.0
var _side: float = 1.0
var _root_t: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var cone: Polygon2D = $VisionCone
@onready var mark: AnimatedSprite2D = $Mark
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var game_state = get_node("/root/GameState")

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_side = 1.0 if randf() < 0.5 else -1.0
	_build_cone()
	mark.visible = false
	anim.animation_finished.connect(_on_anim_done)
	anim.animation_looped.connect(_on_anim_done)
	anim.play("idle")
	_setup()

func _setup() -> void:
	pass

func _work(_delta: float) -> void:
	pass

func _on_alerted() -> void:
	pass

func _on_death() -> void:
	pass

func _walk_anim() -> String:
	return "walk"

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	var sees := _can_see_player()
	if _root_t > 0.0:
		_root_t -= delta
		velocity = Vector2.ZERO
		_play("idle")
		if sees and state == "work":
			_start_alert()
		elif sees and player:
			_face(player.global_position - global_position)
		_update_cone()
		return
	match state:
		"work":
			if sees:
				_start_alert()
			else:
				_work(delta)
		"alert":
			_stand()
			if player:
				_face(player.global_position - global_position)
			_alert_t -= delta
			if _alert_t <= 0.0:
				state = "chase"
		"chase":
			if sees:
				last_seen = player.global_position
				_lost_t = forget_time
			else:
				_lost_t -= delta
			if _lost_t <= 0.0 or (player and player.is_dead()):
				_start_search()
			else:
				_chase(delta, sees)
		"search":
			if sees:
				_start_alert()
			else:
				_search(delta)
	_update_cone()

func _can_see_player() -> bool:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return false
	var to: Vector2 = player.global_position - global_position
	var d: float = to.length()
	if player.is_hidden():
		return state == "chase" and d < 14.0
	var sneaking: bool = player.is_sneaking()
	var soft: bool = game_state.has_skill("soft_steps")
	var rng := vision_range * ((0.5 if soft else 0.6) if sneaking else 1.0)
	if state == "chase" or state == "search":
		rng *= 1.3
	var heard := d < hearing_range * (0.5 if soft else 1.0) and not sneaking
	if d > rng and not heard:
		return false
	if not heard and absf(rad_to_deg(facing.angle_to(to))) > vision_angle * 0.5:
		return false
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -8), player.global_position + Vector2(0, -8), 1)
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _start_alert() -> void:
	state = "alert"
	_alert_t = alert_time
	if player:
		last_seen = player.global_position
	_lost_t = forget_time
	_show_mark("alert")
	_lock("alert")
	_on_alerted()
	for n in get_tree().get_nodes_in_group("enemies"):
		var other = n
		if other != self and other.has_method("hear_alarm") and global_position.distance_to(other.global_position) < 130.0:
			other.hear_alarm(last_seen)

func root_for(seconds: float) -> void:
	_root_t = maxf(_root_t, seconds)

func lose_track() -> void:
	if state == "chase" or state == "alert":
		_lost_t = minf(_lost_t, 0.3)
		state = "chase"

func hear_alarm(pos: Vector2) -> void:
	if _dead or state != "work":
		return
	last_seen = pos
	_start_search()
	_on_alerted()

func _start_search() -> void:
	state = "search"
	_search_t = search_time
	_turn_t = 0.7
	_show_mark("search")

func _chase(delta: float, sees: bool) -> void:
	var d: float = global_position.distance_to(player.global_position)
	if sees and d <= attack_range:
		_stand()
		_face(player.global_position - global_position)
		if _attack_cd <= 0.0:
			_attack_cd = attack_cooldown
			_lock("chop")
			_strike()
		return
	_move_to(last_seen, run_speed, delta)

func _strike() -> void:
	await get_tree().create_timer(0.3).timeout
	if _dead or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= attack_range + 6.0:
		player.take_damage(attack_damage, (player.global_position - global_position).normalized() * 120.0)

func _search(delta: float) -> void:
	if global_position.distance_to(last_seen) > 6.0 and _search_t > search_time - 0.1:
		if not _move_to(last_seen, walk_speed * 1.3, delta):
			return
	_stand()
	_search_t -= delta
	_turn_t -= delta
	if _turn_t <= 0.0:
		_turn_t = 0.7
		_face(-facing)
	if _search_t <= 0.0:
		state = "work"
		mark.visible = false

func _move_to(target: Vector2, speed: float, delta: float) -> bool:
	var to := target - global_position
	if to.length() < 4.0:
		_stand()
		return true
	var dir := to.normalized()
	if _stuck_t > 0.35:
		dir = dir.rotated(_side * 1.2)
	velocity = dir * speed
	var before := global_position
	move_and_slide()
	if global_position.distance_to(before) < speed * delta * 0.3:
		_stuck_t += delta
	else:
		_stuck_t = maxf(_stuck_t - delta * 2.0, 0.0)
	if _stuck_t > 1.4:
		_stuck_t = 0.0
		_side = -_side
	_face(dir)
	_play("run" if speed > walk_speed * 1.5 else _walk_anim())
	return false

func _stand() -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 600.0 * get_physics_process_delta_time())
	move_and_slide()
	_play("idle")

func _face(dir: Vector2) -> void:
	if dir.length() > 0.1:
		facing = dir.normalized()
		anim.flip_h = facing.x < 0.0

func _play(anim_name: String) -> void:
	if _locked == "" and anim.animation != anim_name:
		anim.play(anim_name)

func _lock(anim_name: String) -> void:
	_locked = anim_name
	anim.play(anim_name)
	anim.frame = 0

func _on_anim_done() -> void:
	if anim.animation == _locked:
		_locked = ""

func _show_mark(kind: String) -> void:
	mark.sprite_frames = game_state.frames(kind)
	mark.visible = true
	mark.play("bounce")

func _build_cone() -> void:
	var pts := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(vision_angle * 0.5)
	for i in range(9):
		var a := -half + (half * 2.0) * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * vision_range)
	cone.polygon = pts

func _update_cone() -> void:
	cone.rotation = facing.angle()
	match state:
		"work":
			cone.color = CONE_WORK
		"search":
			cone.color = CONE_SEARCH
		_:
			cone.color = CONE_ALERT

func take_hit(amount: float, from_pos: Vector2, sneak_bonus: bool = true) -> void:
	if _dead:
		return
	var unaware := state == "work" or state == "search"
	if unaware and sneak_bonus:
		amount *= 4.0 if game_state.has_skill("ambush") else sneak_multiplier
	health -= amount
	velocity = (global_position - from_pos).normalized() * 110.0
	if health <= 0.0:
		_die(unaware)
		return
	_lock("hit")
	if state == "work" or state == "search":
		if player:
			last_seen = player.global_position
		_lost_t = forget_time
		state = "chase"
		_show_mark("alert")
		_on_alerted()

func _die(unaware: bool = false) -> void:
	_dead = true
	game_state.add_points(1)
	if not (unaware and game_state.has_skill("silent_kill")):
		for n in get_tree().get_nodes_in_group("enemies"):
			var other = n
			if other != self and other.has_method("hear_alarm") and global_position.distance_to(other.global_position) < 110.0:
				other.hear_alarm(global_position)
	cone.visible = false
	mark.visible = false
	body_shape.set_deferred("disabled", true)
	_locked = "death"
	anim.play("death")
	_on_death()
	died.emit(self)
	await anim.animation_finished
	game_state.spawn_effect(get_parent(), "poof", "poof", global_position + Vector2(0, -8))
	queue_free()
