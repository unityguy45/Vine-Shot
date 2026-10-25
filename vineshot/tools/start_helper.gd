@tool
extends EditorScript

func _run() -> void:
	var base := EditorInterface.get_base_control()
	for c in base.get_children():
		if str(c.name).begins_with("GodotBuilderHelper"):
			c.free()
	var code := GDScript.new()
	code.source_code = FileAccess.get_file_as_string("res://.godot/builder/builder_helper.gd")
	if code.reload() != OK:
		push_error("The Godot builder helper did not load.")
		return
	var helper := Node.new()
	helper.name = "GodotBuilderHelper"
	helper.set_script(code)
	base.add_child(helper)
	print("Godot builder helper started.")
