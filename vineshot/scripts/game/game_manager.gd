extends Node

const CAMP := "res://scenes/world/camp.tscn"
const TITLE := "res://scenes/ui/title_screen.tscn"

@export var world_size: Vector2 = Vector2(1280, 896)
@export var max_camps: int = 3
@export var first_camp_delay: float = 4.0
@export var camp_interval: float = 40.0
@export_range(0.0, 1.0) var lose_below_forest: float = 0.75

@onready var world: Node2D = %World
@onready var camps: Node2D = %Camps
@onready var hud = %HUD
@onready var spots: Node2D = %CampSpots
@onready var player = %Player
@onready var game_state = get_node("/root/GameState")

var total_trees: int = 0
var standing_trees: int = 0
var camps_spawned: int = 0
var camps_cleared: int = 0
var wood_stolen: int = 0
var _camp_timer: float = 0.0
var _over: bool = false
var _used_spots: Array[Node] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if owner and not owner.is_node_ready():
		await owner.ready
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = false
	_camp_timer = first_camp_delay
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(world_size.x)
	cam.limit_bottom = int(world_size.y)
	for n in get_tree().get_nodes_in_group("trees"):
		var t = n
		total_trees += 1
		t.felled.connect(_on_tree_felled)
	standing_trees = total_trees
	game_state.reset_skills()
	game_state.skills_changed.connect(_on_skills_changed)
	hud.set_points(0)
	hud.set_forest(1.0)
	hud.set_camps(0, max_camps)
	hud.set_wood(0)
	hud.show_message("Protect the forest! Hide in bushes and take the woodcutters by surprise.", 5.0)

func _process(delta: float) -> void:
	if _over:
		if Input.is_action_just_pressed("restart"):
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif Input.is_action_just_pressed("ui_cancel"):
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE)
		return
	if get_tree().paused:
		return
	if camps_spawned >= max_camps:
		return
	_camp_timer -= delta
	if camps_spawned > 0 and camps_spawned == camps_cleared:
		_camp_timer = minf(_camp_timer, 3.0)
	if _camp_timer <= 0.0:
		_camp_timer = camp_interval
		_spawn_camp()

func _unhandled_input(event: InputEvent) -> void:
	if not _over and event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(TITLE)

func _on_skills_changed() -> void:
	hud.set_points(game_state.skill_points)

func _spawn_camp() -> void:
	var options: Array[Node] = []
	for n in spots.get_children():
		var s: Node2D = n
		if s in _used_spots:
			continue
		if player and s.global_position.distance_to(player.global_position) < 170.0:
			continue
		options.append(s)
	if options.is_empty():
		for n in spots.get_children():
			if not n in _used_spots:
				options.append(n)
	if options.is_empty():
		return
	var spot: Node2D = options.pick_random()
	_used_spots.append(spot)
	var camp = load(CAMP).instantiate()
	camps.add_child(camp)
	camp.global_position = spot.global_position
	camp.cleared.connect(_on_camp_cleared)
	camp.wood_stolen.connect(_on_wood_stolen)
	camps_spawned += 1
	hud.show_message("A woodcutter camp has appeared in the forest!", 3.0)

func _on_tree_felled(_tree: Node) -> void:
	standing_trees -= 1
	var ratio := float(standing_trees) / float(maxi(total_trees, 1))
	hud.set_forest(ratio)
	if ratio < lose_below_forest:
		_end(false, "The forest has fallen...")

func _on_wood_stolen() -> void:
	wood_stolen += 1
	hud.set_wood(wood_stolen)

func _on_camp_cleared(_camp: Node) -> void:
	camps_cleared += 1
	game_state.add_points(3)
	hud.set_camps(camps_cleared, max_camps)
	if camps_cleared >= max_camps:
		_end(true, "The forest is safe!")
	else:
		hud.show_message("Camp cleared! Another one is coming...", 3.0)

func _on_player_died() -> void:
	await get_tree().create_timer(1.2).timeout
	_end(false, "You were defeated...")

func _end(win: bool, text: String) -> void:
	if _over:
		return
	_over = true
	get_tree().paused = true
	hud.show_end(win, text)
