extends CharacterBody2D

signal died(enemy: Node)

const CONE_WORK := Color(1.0, 0.95, 0.55, 0.16)
const CONE_GUARDED := Color(1.0, 0.68, 0.35, 0.2)
const CONE_SEARCH := Color(1.0, 0.7, 0.3, 0.22)
const CONE_ALERT := Color(1.0, 0.3, 0.25, 0.26)
const METER_BACK := Color(0.12, 0.08, 0.1, 0.85)
const METER_LOW := Color(1.0, 0.86, 0.35)
const METER_HIGH := Color(1.0, 0.32, 0.25)

@export var max_health: float = 60.0
@export var walk_speed: float = 34.0
@export var run_speed: float = 70.0
@export var vision_range: float = 95.0
@export var vision_angle: float = 70.0
@export var hearing_range: float = 40.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 16.0
@export var attack_cooldown: float = 1.2
@export var alert_time: float = 0.6
@export var forget_time: float = 3.0
@export var search_time: float = 2.6
@export var sneak_multiplier: float = 3.0
@export var notice_speed: float = 0.85
@export var investigate_time: float = 2.4

var camp
var health: float
var facing: Vector2 = Vector2.RIGHT
var state: String = "work"
var player
var last_seen: Vector2 = Vector2.ZERO
var suspicion: float = 0.0

var _alert_t: float = 0.0
var _lost_t: float = 0.0
var _search_t: float = 0.0
var _turn_t: float = 0.0
var _attack_cd: float = 0.0
var _locked: String = ""
var _dead: bool = false
var _stuck_t: float = 0.0
var _side: float = 1.0
var _look_t: float = 0.0
var _scan_t: float = 0.0
var _search_points: Array[Vector2] = []
var _body = null
var _body_t: float = 0.0
var _cone_level: int = -1
var _shown_meter: float = 0.0
var _pause_t: float = 0.0
var _meter_back: ColorRect
var _meter_fill: ColorRect
var discovered: bool = false
var dragged: bool = false

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
	_scan_t = randf() * 0.25
	_make_meter()
	_setup()

func _setup() -> void:
	pass

func _work(_delta: float) -> void:
	pass

func _on_alerted() -> void:
	pass

func _on_death() -> void:
	pass

func _ranged(_delta: float, _dist: float) -> bool:
	return false

func _walk_anim() -> String:
	return "walk"

func alert_level() -> int:
	if camp and is_instance_valid(camp):
		return camp.alert_level
	return 0

func is_dead() -> bool:
	return _dead

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if _cone_level != alert_level():
		_build_cone()
	var seen := _player_visibility()
	var sees := seen > 0.0
	_update_suspicion(seen, delta)
	if state == "work" or state == "investigate" or state == "search":
		_scan_t -= delta
		if _scan_t <= 0.0:
			_scan_t = 0.25
			_look_for_bodies()
	match state:
		"work":
			if suspicion >= 1.0:
				_start_alert()
			elif sees and suspicion > 0.35:
				_start_investigate(player.global_position, true)
			else:
				_work(delta)
		"investigate":
			if suspicion >= 1.0:
				_start_alert()
			else:
				if sees:
					last_seen = player.global_position
				_investigate(delta)
		"body":
			_go_to_body(delta)
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
			if suspicion >= 1.0 or (sees and suspicion > 0.5):
				_start_alert()
			else:
				_search(delta)
	_update_cone()
	_update_meter()

func _vision_range() -> float:
	match alert_level():
		1:
			return vision_range * 1.12
		2:
			return vision_range * 1.35
	return vision_range

func _vision_half_angle() -> float:
	return vision_angle * 0.5 + (16.0 if alert_level() >= 2 else 0.0)

func _player_visibility() -> float:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return 0.0
	var to: Vector2 = player.global_position - global_position
	var d: float = to.length()
	if player.is_hidden():
		return 50.0 if state == "chase" and d < 14.0 else 0.0
	var sneaking: bool = player.is_sneaking()
	var rng := _vision_range() * (0.6 if sneaking else 1.0)
	if state == "chase" or state == "search":
		rng *= 1.3
	var heard: bool = d < hearing_range * player.noise_level()
	if d > rng and not heard:
		return 0.0
	if not heard and absf(rad_to_deg(facing.angle_to(to))) > _vision_half_angle():
		return 0.0
	if not _clear_line(player.global_position):
		return 0.0
	if heard or d < 18.0:
		return 4.0
	return 0.55 + (1.0 - clampf(d / rng, 0.0, 1.0)) * 2.2

func _clear_line(target: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -8), target + Vector2(0, -8), 1)
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _update_suspicion(seen: float, delta: float) -> void:
	if state == "chase" or state == "alert":
		suspicion = 1.0
		return
	if seen > 0.0:
		var before := suspicion
		var rate: float = notice_speed * [1.0, 1.3, 1.8][clampi(alert_level(), 0, 2)]
		suspicion = minf(suspicion + seen * rate * delta, 1.0)
		if before < 0.35 and suspicion >= 0.35:
			game_state.play_sfx("suspicious", global_position, -6.0)
	else:
		var floor_level := 0.2 if state == "investigate" else 0.0
		suspicion = maxf(suspicion - delta * 0.22, floor_level)

func _start_investigate(pos: Vector2, from_sight: bool) -> void:
	if state == "investigate" and not from_sight:
		last_seen = pos
		_search_t = investigate_time
		return
	state = "investigate"
	last_seen = pos
	_search_t = investigate_time
	_turn_t = 0.6
	_show_mark("search")
	_on_alerted()
	_face(pos - global_position)

func _investigate(delta: float) -> void:
	if global_position.distance_to(last_seen) > 8.0:
		_move_to(last_seen, walk_speed * 1.25, delta)
		return
	_stand()
	_search_t -= delta
	_turn_t -= delta
	if _turn_t <= 0.0:
		_turn_t = 0.6
		_face(facing.rotated(randf_range(1.8, 2.8) * _side))
	if _search_t <= 0.0:
		state = "work"
		suspicion = minf(suspicion, 0.3)
		mark.visible = false

func hear_noise(pos: Vector2, radius: float) -> void:
	if _dead or state == "chase" or state == "alert" or state == "body":
		return
	if global_position.distance_to(pos) > radius * (1.25 if alert_level() >= 2 else 1.0):
		return
	suspicion = maxf(suspicion, 0.4)
	if state == "search":
		last_seen = pos
		_search_points.clear()
		_search_points.append(pos)
		return
	if state != "investigate":
		game_state.play_sfx("suspicious", global_position, -6.0)
	_start_investigate(pos, false)

func _look_for_bodies() -> void:
	var rng := _vision_range() * 1.1
	var half := _vision_half_angle()
	for n in get_tree().get_nodes_in_group("bodies"):
		var b = n
		if b == self or b.discovered or b.dragged or b.is_body_hidden():
			continue
		var to: Vector2 = b.global_position - global_position
		if to.length() > rng:
			continue
		if to.length() > 14.0 and absf(rad_to_deg(facing.angle_to(to))) > half:
			continue
		if not _clear_line(b.global_position):
			continue
		b.discovered = true
		_found_body(b)
		return

func _found_body(b) -> void:
	_body = b
	_body_t = 1.2
	state = "body"
	suspicion = maxf(suspicion, 0.6)
	_show_mark("alert")
	_lock("alert")
	game_state.play_sfx("alert", global_position, -2.0)
	_on_alerted()

func _go_to_body(delta: float) -> void:
	var target: Vector2 = _body.global_position if _body and is_instance_valid(_body) else last_seen
	if global_position.distance_to(target) > 14.0:
		_move_to(target, run_speed, delta)
		return
	_stand()
	_face(target - global_position)
	_body_t -= delta
	if _body_t <= 0.0:
		last_seen = target
		game_state.report_body(target)
		game_state.play_sfx("body_found", target, 2.0, 0.02)
		if camp and is_instance_valid(camp):
			camp.raise_alert(2, "body")
		_call_others(target, 200.0)
		_start_search()

func _start_alert() -> void:
	state = "alert"
	_alert_t = alert_time
	suspicion = 1.0
	if player:
		last_seen = player.global_position
	_lost_t = forget_time
	_show_mark("alert")
	_lock("alert")
	game_state.play_sfx("alert", global_position)
	game_state.report_spotted()
	_on_alerted()
	if camp and is_instance_valid(camp):
		camp.raise_alert(2, "spotted")
	_call_others(last_seen, 140.0)

func _call_others(pos: Vector2, radius: float) -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		var other = n
		if other != self and other.has_method("hear_alarm") and global_position.distance_to(other.global_position) < radius:
			other.hear_alarm(pos)

func hear_alarm(pos: Vector2) -> void:
	if _dead or state == "chase" or state == "alert" or state == "body":
		return
	last_seen = pos
	suspicion = maxf(suspicion, 0.6)
	_start_search()
	_on_alerted()

func _start_search() -> void:
	state = "search"
	_search_t = search_time * (1.4 if alert_level() >= 2 else 1.0)
	_pause_t = 0.0
	_turn_t = 0.7
	_search_points.clear()
	_search_points.append(last_seen)
	for i in range(3 if alert_level() >= 2 else 2):
		var a := randf() * TAU
		_search_points.append(last_seen + Vector2(cos(a), sin(a)) * randf_range(28.0, 60.0))
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
	if sees and _ranged(delta, d):
		return
	_move_to(last_seen, run_speed, delta)

func _strike() -> void:
	await get_tree().create_timer(0.3).timeout
	if _dead or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= attack_range + 6.0:
		player.take_damage(attack_damage, (player.global_position - global_position).normalized() * 120.0)

func _search(delta: float) -> void:
	if _pause_t > 0.0:
		_stand()
		_pause_t -= delta
		_turn_t -= delta
		if _turn_t <= 0.0:
			_turn_t = 0.45
			_face(facing.rotated(randf_range(1.6, 3.0) * _side))
		return
	if not _search_points.is_empty():
		var target: Vector2 = _search_points[0]
		if global_position.distance_to(target) > 6.0 and not _move_to(target, walk_speed * 1.4, delta):
			if _stuck_t > 1.2:
				_search_points.pop_front()
			return
		_search_points.pop_front()
		_pause_t = 0.9
		_turn_t = 0.0
		return
	_stand()
	_search_t -= delta
	_turn_t -= delta
	if _turn_t <= 0.0:
		_turn_t = 0.6
		_face(facing.rotated(randf_range(1.6, 3.0) * _side))
	if _search_t <= 0.0:
		state = "work"
		suspicion = minf(suspicion, 0.25)
		mark.visible = false
		if camp and is_instance_valid(camp):
			camp.raise_alert(1, "search")

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
	if anim.animation == _locked and not _dead:
		_locked = ""

func _show_mark(kind: String) -> void:
	mark.sprite_frames = game_state.frames(kind)
	mark.visible = true
	mark.play("bounce")

func _build_cone() -> void:
	_cone_level = alert_level()
	var pts := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(_vision_half_angle())
	var reach := _vision_range()
	for i in range(11):
		var a := -half + (half * 2.0) * float(i) / 10.0
		pts.append(Vector2(cos(a), sin(a)) * reach)
	cone.polygon = pts

func _update_cone() -> void:
	cone.rotation = facing.angle()
	match state:
		"work":
			cone.color = CONE_GUARDED if alert_level() >= 2 else CONE_WORK
		"search", "investigate":
			cone.color = CONE_SEARCH
		_:
			cone.color = CONE_ALERT

func _make_meter() -> void:
	_meter_back = ColorRect.new()
	_meter_back.color = METER_BACK
	_meter_back.size = Vector2(18, 4)
	_meter_back.position = Vector2(-9, -47)
	_meter_back.z_index = 20
	_meter_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_back.visible = false
	add_child(_meter_back)
	_meter_fill = ColorRect.new()
	_meter_fill.position = Vector2(1, 1)
	_meter_fill.size = Vector2(0, 2)
	_meter_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_back.add_child(_meter_fill)

func _update_meter() -> void:
	var show := suspicion if (state == "work" or state == "investigate" or state == "search") else 0.0
	if absf(show - _shown_meter) < 0.01:
		return
	_shown_meter = show
	_meter_back.visible = show > 0.02
	_meter_fill.size.x = 16.0 * show
	_meter_fill.color = METER_LOW.lerp(METER_HIGH, show)

func take_hit(amount: float, from_pos: Vector2) -> void:
	if _dead:
		return
	var unaware := state != "chase" and state != "alert"
	if unaware:
		amount *= sneak_multiplier
	health -= amount
	velocity = (global_position - from_pos).normalized() * 110.0
	_flash()
	if health <= 0.0:
		_die(unaware)
		return
	game_state.play_sfx("arrow_hit", global_position)
	game_state.shake(1.5)
	_lock("hit")
	if unaware:
		if player:
			last_seen = player.global_position
		_lost_t = forget_time
		suspicion = 1.0
		state = "chase"
		_show_mark("alert")
		game_state.play_sfx("alert", global_position)
		game_state.report_spotted()
		_on_alerted()
		if camp and is_instance_valid(camp):
			camp.raise_alert(2, "hit")
		_call_others(last_seen, 140.0)

func _flash() -> void:
	anim.modulate = Color(3.0, 3.0, 3.0)
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color.WHITE, 0.12)

func _die(unaware: bool = false) -> void:
	_dead = true
	cone.visible = false
	mark.visible = false
	suspicion = 0.0
	_shown_meter = 0.0
	_meter_back.visible = false
	body_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_locked = "death"
	anim.play("death")
	game_state.add_stat("takedowns")
	if unaware:
		game_state.add_stat("sneak_takedowns")
		game_state.popup_text(get_parent(), global_position + Vector2(0, -30), "Silent takedown", Color(0.7, 1.0, 0.6))
		game_state.play_sfx("takedown", global_position)
		game_state.hitstop(0.07)
	else:
		game_state.play_sfx("enemy_death", global_position)
	game_state.shake(2.5)
	game_state.make_noise(global_position, 42.0)
	_on_death()
	died.emit(self)
	var lie_frame := mini(6, anim.sprite_frames.get_frame_count("death") - 1)
	while anim.is_playing() and anim.animation == "death" and anim.frame < lie_frame:
		await anim.frame_changed
	anim.pause()
	anim.frame = lie_frame
	_become_body()

func _become_body() -> void:
	z_index = -1
	add_to_group("bodies")
	remove_from_group("enemies")
	set_physics_process(false)
	anim.modulate = Color(0.85, 0.85, 0.85)

func is_body_hidden() -> bool:
	for n in get_tree().get_nodes_in_group("bushes"):
		var bush: Node2D = n
		if global_position.distance_to(bush.global_position + Vector2(0, -4)) < 13.0:
			return true
	return false
