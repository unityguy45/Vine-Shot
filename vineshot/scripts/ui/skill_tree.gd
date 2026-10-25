extends CanvasLayer

@onready var screen: Control = $Screen
@onready var points_label: Label = $Screen/PointsLabel
@onready var info_label: Label = $Screen/InfoLabel
@onready var game_state = get_node("/root/GameState")

var _buttons: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	screen.visible = false
	for b in screen.find_children("*", "Button", true, false):
		var button = b
		var id := str(button.name)
		if game_state.SKILLS.has(id):
			_buttons.append(button)
			button.pressed.connect(_on_pressed.bind(id))
			button.mouse_entered.connect(_show_info.bind(id))
			button.focus_entered.connect(_show_info.bind(id))
	g
