extends CanvasLayer

@onready var health_back: ColorRect = $Panel/HealthBack
@onready var health_fill: ColorRect = $Panel/HealthBack/HealthFill
@onready var forest_label: Label = $Panel/ForestLabel
@onready var camps_label: Label = $Panel/CampsLabel
@onready var wood_label: Label = $Panel/WoodLabel
@onready var message: Label = $Message
@onready var end_screen: ColorRect = $EndScreen
@onready var end_title: Label = $EndScreen/Title
@onready var end_hint: Label = $EndScreen/Hint
@onready var end_stats: Label = $EndScreen/Stats
@onready var alert_label: Label = $AlertLabel

var _msg_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	end_screen.visible = false
	message.modulate.a = 0.0

func set_health(current: float, maximum: float) -> void:
	var ratio := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	health_fill.size.x = health_back.size.x * ratio

func set_forest(ratio: float) -> void:
	forest_label.text = "Forest: %d%%" % int(round(ratio * 100.0))
	forest_label.modulate = Color(1, 1, 1) if ratio > 0.65 else Color(1, 0.6, 0.5)

func set_camps(cleared: int, total: int) -> void:
	camps_label.text = "Camps cleared: %d/%d" % [cleared, total]

func set_wood(amount: int) -> void:
	wood_label.text = "Wood stolen: %d" % amount

func show_message(text: String, time: float = 3.0) -> void:
	message.text = text
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	message.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(time)
	_msg_tween.tween_property(message, "modulate:a", 0.0, 0.6)

func set_alert(level: int) -> void:
	match level:
		0:
			alert_label.text = ""
		1:
			alert_label.text = "Camps are suspicious"
			alert_label.modulate = Color(1.0, 0.85, 0.4)
		_:
			alert_label.text = "A camp is ON GUARD"
			alert_label.modulate = Color(1.0, 0.45, 0.35)

func show_end(win: bool, text: String, stats: String = "") -> void:
	end_screen.visible = true
	end_stats.text = stats
	end_title.text = text
	end_title.modulate = Color(1.0, 0.9, 0.4) if win else Color(1.0, 0.55, 0.5)
	end_hint.text = "Press R to play again   -   Esc for the title screen"
