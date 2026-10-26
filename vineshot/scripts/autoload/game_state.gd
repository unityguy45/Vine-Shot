extends Node

signal spotted
signal body_found(pos: Vector2)

const SFX_DIR := "res://art/audio/"

var stats: Dictionary = {}
var _sounds: Dictionary = {}
var _last_spotted: float = -100.0
var _hitstop_on: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_stats()

func frames(frames_name: String) -> SpriteFrames:
	return load("res://resources/frames/" + frames_name + ".tres") as SpriteFrames

func spawn_effect(parent: Node, frames_name: String, anim_name: String, pos: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	if parent == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = frames(frames_name)
	fx.offset = offset
	fx.animation_finished.connect(fx.queue_free)
	parent.add_child(fx)
	fx.global_position = pos
	fx.play(anim_name)

func reset_stats() -> void:
	stats = {"takedowns": 0, "sneak_takedowns": 0, "spotted": 0, "bodies_found": 0, "time": 0.0}
	_last_spotted = -100.0

func add_stat(key: String, amount = 1) -> void:
	stats[key] = stats.get(key, 0) + amount

func report_spotted() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_spotted > 5.0:
		add_stat("spotted")
		spotted.emit()
	_last_spotted = now

func report_body(pos: Vector2) -> void:
	add_stat("bodies_found")
	body_found.emit(pos)

func play_sfx(sound: String, at = null, volume_db: float = 0.0, pitch_range: float = 0.08) -> void:
	if not _sounds.has(sound):
		var path := SFX_DIR + sound + ".wav"
		_sounds[sound] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _sounds[sound]
	if stream == null:
		return
	if at == null:
		var flat := AudioStreamPlayer.new()
		flat.stream = stream
		flat.volume_db = volume_db
		flat.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
		add_child(flat)
		flat.finished.connect(flat.queue_free)
		flat.play()
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var spatial := AudioStreamPlayer2D.new()
	spatial.stream = stream
	spatial.volume_db = volume_db
	spatial.max_distance = 420.0
	spatial.attenuation = 1.6
	spatial.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	scene.add_child(spatial)
	spatial.global_position = at
	spatial.finished.connect(spatial.queue_free)
	spatial.play()

func shake(amount: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("shake"):
		player.shake(amount)

func hitstop(seconds: float) -> void:
	if _hitstop_on or get_tree().paused:
		return
	_hitstop_on = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_on = false

func popup_text(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.z_index = 50
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(80, 12)
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.1))
	label.modulate = color
	parent.add_child(label)
	label.global_position = pos - Vector2(40, 6)
	var tw := label.create_tween()
	tw.tween_property(label, "global_position:y", label.global_position.y - 16.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.tween_callback(label.queue_free)

func make_noise(pos: Vector2, radius: float) -> void:
	for n in get_tree().get_nodes_in_group("enemies"):
		var enemy = n
		if enemy.has_method("hear_noise"):
			enemy.hear_noise(pos, radius)
