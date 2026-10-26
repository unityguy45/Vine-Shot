extends CharacterBody2D

signal health_changed(current: float, maximum: float)
signal died

const ARROW_SCENE := "res://scenes/combat/arrow.tscn"

@export var max_speed: float = 120.0
@export var walk_speed: float = 60.0
@export var sneak_speed: float = 45.0
@export var acceleration: float = 1300.0
@export var friction: float = 1600.0
@export var turn_boost: float = 2.2
@export var dash_speed: float = 400.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 0.45
@export var dash_end_speed: float = 140.0
@export var ghost_interval: float = 0.022
@export var ghost_fade: float = 0.28
@export var ghost_color: Color = Color(0.75, 0.95, 1.0, 0.75)
@export var max_health: float = 100.0
@export var shot_cooldown: float = 0.45
@export var shot_delay: float = 0.12
@export var drag_speed: float = 34.0
@export var bush_heal: float = 5.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var health: float
var _facing: float = 1.0
var _dash_t: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _ghost_t: float = 0.0
var _attack_cd: float = 0.0
var _locked: String = ""
var _dead: bool = false
var _bushes: int = 0
var _squash_tween: Tween
var _dragging = null
var _shake: float = 0.0
var _calm_t: float = 0.0
var _drag_sound_t: float = 0.0
@onready var cam: Camera2D = $Camera2D
@onready var game_state = get_node("/root/GameState")

func _ready() -> void:
	add_to_group("player")
	anim.sprite_frames = game_state.frames("archer")
	health = max_health
	anim.animation_finished.connect(_on_anim_finished)
	_play("idle")
	health_changed.emit.call_deferred(health, max_health)

func is_dead() -> bool:
	return _dead

func is_sneaking() -> bool:
	return Input.is_action_pressed("sneak")

func is_dashing() -> bool:
	return _dash_t > 0.0

func is_dragging() -> bool:
	return _dragging != null

func noise_level() -> float:
	if _dash_t > 0.0:
		return 1.8
	var speed := velocity.length()
	if speed < 8.0 or is_sneaking():
		return 0.0
	if _dragging:
		return 0.6
	return 1.5 if speed > walk_speed + 10.0 else 0.8

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func is_hidden() -> bool:
	return _bushes > 0 and _locked != "attack" and _dash_t <= 0.0 and _dragging == null

func enter_bush() -> void:
	_bushes += 1

func exit_bush() -> void:
	_bushes = maxi(_bushes - 1, 0)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_update_shake(delta)
	_heal_in_bush(delta)
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sneaking := is_sneaking()
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * dash_speed
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = ghost_interval
			_spawn_ghost()
		if _dash_t <= 0.0:
			velocity = _dash_dir * dash_end_speed
			_squash(Vector2(0.9, 1.1), 0.12)
	else:
		var top := sneak_speed if sneaking else max_speed
		if _dragging:
			top = drag_speed
		var target := input_dir * top
		if _locked == "" and input_dir != Vector2.ZERO and velocity.length() > max_speed * 0.6 and velocity.normalized().dot(input_dir) < -0.4:
			_lock("skid")
			_squash(Vector2(0.88, 1.08), 0.12)
		if input_dir != Vector2.ZERO:
			var rate := acceleration
			if velocity.dot(target) < 0.0:
				rate *= turn_boost
			velocity = velocity.move_toward(target, rate * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	_pull_body(delta)
	if absf(velocity.x) > 5.0 and _locked != "attack" and _locked != "skid":
		_facing = signf(velocity.x)
	anim.flip_h = _facing < 0.0
	anim.modulate.a = 0.55 if is_hidden() else 1.0
	_update_animation(sneaking)

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event.is_action_pressed("drag"):
		_toggle_drag()
	elif event.is_action_pressed("dash"):
		_drop_body()
		_start_dash()
	elif event.is_action_pressed("attack"):
		_drop_body()
		_attack()

func _start_dash() -> void:
	if _dash_cd > 0.0 or _dash_t > 0.0:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = Vector2(_facing, 0.0)
	_dash_dir = dir.normalized()
	_dash_t = dash_time
	_dash_cd = dash_cooldown + dash_time
	_ghost_t = 0.0
	if absf(_dash_dir.x) > 0.1:
		_facing = signf(_dash_dir.x)
	_locked = ""
	_lock("dash")
	_squash(Vector2(1.3, 0.75), 0.18)
	game_state.play_sfx("dash", global_position, -6.0)
	game_state.spawn_effect(get_parent(), "dash_dust", "puff", global_position + Vector2(-_dash_dir.x * 6.0, -4.0))

func _attack() -> void:
	if _attack_cd > 0.0 or _locked == "attack" or _dash_t > 0.0:
		return
	_attack_cd = shot_cooldown
	var target := get_global_mouse_position()
	var aim := target - global_position
	if absf(aim.x) > 1.0:
		_facing = signf(aim.x)
	_lock("attack")
	_squash(Vector2(1.12, 0.9), 0.14)
	await get_tree().create_timer(shot_delay).timeout
	if _dead or not is_inside_tree():
		return
	game_state.play_sfx("bow", global_position, -3.0)
	var shot = load(ARROW_SCENE).instantiate()
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector2(_facing * 8.0, -12.0)
	shot.launch(target + Vector2(0.0, -8.0))

func _update_animation(sneaking: bool) -> void:
	if _locked != "":
		return
	var speed := velocity.length()
	if speed < 8.0:
		anim.speed_scale = 1.0
		_play("sneak" if sneaking else "idle")
		if sneaking:
			anim.speed_scale = 0.0
		return
	if sneaking:
		_play("sneak")
		anim.speed_scale = clampf(speed / sneak_speed, 0.4, 1.2)
	elif speed < walk_speed:
		_play("walk")
		anim.speed_scale = clampf(speed / walk_speed, 0.5, 1.2)
	else:
		_play("run")
		anim.speed_scale = clampf(speed / max_speed, 0.7, 1.35)

func _lock(anim_name: String) -> void:
	_locked = anim_name
	anim.speed_scale = 1.0
	anim.play(anim_name)
	anim.frame = 0

func _play(anim_name: String) -> void:
	if anim.animation != anim_name:
		anim.play(anim_name)

func _on_anim_finished() -> void:
	if _dead:
		return
	if anim.animation == _locked:
		_locked = ""

func _spawn_ghost() -> void:
	var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.flip_h = anim.flip_h
	g.offset = anim.offset
	g.centered = anim.centered
	g.scale = anim.scale
	g.modulate = ghost_color
	g.z_index = -1
	get_parent().add_child(g)
	g.global_position = anim.global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, ghost_fade)
	tw.tween_callback(g.queue_free)

func _squash(to: Vector2, time: float) -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	anim.scale = to
	_squash_tween = create_tween()
	_squash_tween.tween_property(anim, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if _dead or _dash_t > 0.0:
		return
	health = maxf(health - amount, 0.0)
	velocity += knockback
	_calm_t = 0.0
	_drop_body()
	health_changed.emit(health, max_health)
	game_state.play_sfx("player_hurt", global_position)
	shake(4.0)
	anim.modulate = Color(1.0, 0.45, 0.45)
	var tw := create_tween()
	tw.tween_property(anim, "modulate", Color.WHITE, 0.2)
	if health <= 0.0:
		_die()
		return
	_lock("hit")
	_squash(Vector2(0.85, 1.15), 0.16)

func _die() -> void:
	_dead = true
	_drop_body()
	_locked = "death"
	velocity = Vector2.ZERO
	anim.speed_scale = 1.0
	anim.modulate.a = 1.0
	anim.play("death")
	died.emit()

func _update_shake(delta: float) -> void:
	if cam == null:
		return
	if _shake > 0.05:
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = move_toward(_shake, 0.0, delta * 14.0)
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO
		_shake = 0.0

func _heal_in_bush(delta: float) -> void:
	_calm_t += delta
	if _bushes > 0 and _calm_t > 2.0 and health < max_health:
		var hunted := false
		for n in get_tree().get_nodes_in_group("enemies"):
			var e = n
			if e.state == "chase" or e.state == "alert":
				hunted = true
				break
		if not hunted:
			health = minf(health + bush_heal * delta, max_health)
			health_changed.emit(health, max_health)

func _toggle_drag() -> void:
	if _dragging:
		_drop_body()
		return
	if _dash_t > 0.0 or _locked == "attack":
		return
	var best = null
	var best_d := 20.0
	for n in get_tree().get_nodes_in_group("bodies"):
		var b = n
		var d: float = b.global_position.distance_to(global_position)
		if d < best_d and not b.dragged:
			best_d = d
			best = b
	if best == null:
		return
	_dragging = best
	best.dragged = true
	game_state.play_sfx("drag", global_position, -4.0)

func _drop_body() -> void:
	if _dragging == null:
		return
	if is_instance_valid(_dragging):
		_dragging.dragged = false
		if _dragging.is_body_hidden():
			game_state.popup_text(get_parent(), _dragging.global_position + Vector2(0, -20), "Hidden", Color(0.7, 1.0, 0.6))
	_dragging = null

func _pull_body(delta: float) -> void:
	if _dragging == null:
		return
	if not is_instance_valid(_dragging):
		_dragging = null
		return
	var spot := global_position + Vector2(-_facing * 11.0, 1.0)
	_dragging.global_position = _dragging.global_position.lerp(spot, clampf(delta * 10.0, 0.0, 1.0))
	if velocity.length() > 10.0:
		_drag_sound_t -= delta
		if _drag_sound_t <= 0.0:
			_drag_sound_t = 0.35
			game_state.play_sfx("drag", global_position, -10.0, 0.2)
