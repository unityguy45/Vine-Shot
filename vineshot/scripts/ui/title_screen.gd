extends Control

const GAME := "res://scenes/main.tscn"

@onready var play_button: Button = $PlayButton
@onready var quit_button: Button = $QuitButton
@onready var preview: AnimatedSprite2D = $ArcherPreview
@onready var trees: Node2D = $Trees

func _ready() -> void:
	get_tree().paused = false
	play_button.pressed.connect(_start)
	quit_button.pressed.connect(get_tree().quit)
	preview.play("idle")
	for t in trees.get_children():
		var sprite = t
		sprite.play("sway")
		sprite.frame = randi() % 4
	play_button.grab_focus()

func _start() -> void:
	get_tree().change_scene_to_file(GAME)
