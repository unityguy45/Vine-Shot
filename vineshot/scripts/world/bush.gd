extends Area2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("bushes")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	anim.animation_finished.connect(_on_anim_finished)
	anim.play("idle")

func _on_body_entered(body) -> void:
	if body.has_method("enter_bush"):
		body.enter_bush()
		anim.play("rustle")

func _on_body_exited(body) -> void:
	if body.has_method("exit_bush"):
		body.exit_bush()
		anim.play("rustle")

func _on_anim_finished() -> void:
	anim.play("idle")
