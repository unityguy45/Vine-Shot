extends Node

signal skills_changed

const SKILLS := {
	"steady_draw": {"name": "Steady Draw", "branch": "Marksman", "cost": 1, "needs": "", "info": "Arrows fly faster and further."},
	"quick_nock": {"name": "Quick Nock", "branch": "Marksman", "cost": 1, "needs": "steady_draw", "info": "Shorter wait between shots."},
	"piercing_arrow": {"name": "Piercing Arrow", "branch": "Marksman", "cost": 2, "needs": "quick_nock", "info": "Arrows pass through the first enemy and can hit a second."},
	"split_shot": {"name": "Split Shot", "branch": "Marksman", "cost": 2, "needs": "piercing_arrow", "info": "Every shot fires three arrows in a small spread."},
	"arrow_rain": {"name": "Rain of Arrows", "branch": "Marksman", "cost": 3, "needs": "split_shot", "info": "Press Q to rain arrows on the spot under your mouse."},
	"soft_steps": {"name": "Soft Steps", "branch": "Shadow", "cost": 1, "needs": "", "info": "Sneak faster, and enemies must be closer to hear you."},
	"ambush": {"name": "Ambush", "branch": "Shadow", "cost": 1, "needs": "soft_steps", "info": "Sneak attacks deal 4x damage instead of 3x."},
	"leaf_cloak": {"name": "Leaf Cloak", "branch": "Shadow", "cost": 2, "needs": "ambush", "info": "Stay hidden for 2 seconds after leaving a bush."},
	"vanish": {"name": "Vanish", "branch": "Shadow", "cost": 2, "needs": "leaf_cloak", "info": "Dashing makes you vanish for a moment, so enemies lose track of you."},
	"silent_kill": {"name": "Silent Kill", "branch": "Shadow", "cost": 3, "needs": "vanish", "info": "Enemies taken down while unaware don't alert anyone nearby."},
	"snare": {"name": "Snare", "branch": "Trapper", "cost": 1, "needs": "", "info": "Press E to set a snare that holds an enemy for 3 seconds."},
	"bear_trap": {"name": "Bear Trap", "branch": "Trapper", "cost": 2, "needs": "snare", "info": "Snares also hurt, and woodcutters drop the wood they carry."},
	"spike_pit": {"name": "Spike Pit", "branch": "Trapper", "cost": 2, "needs": "bear_trap", "info": "Press F to dig a hidden pit that deals heavy damage."},
}
	
var skill_points: int = 0
var unlocked: Dictionary = {}

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

func reset_skills() -> void:
	skill_points = 0
	unlocked.clear()
	skills_changed.emit()

func add_points(amount: int) -> void:
	skill_points += amount
	skills_changed.emit()

func has_skill(id: String) -> bool:
	return unlocked.has(id)

func can_unlock(id: String) -> bool:
	if not SKILLS.has(id) or unlocked.has(id):
		return false
	var skill: Dictionary = SKILLS[id]
	if skill["needs"] != "" and not unlocked.has(skill["needs"]):
		return false
	return skill_points >= int(skill["cost"])

func unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	skill_points -= int(SKILLS[id]["cost"])
	unlocked[id] = true
	skills_changed.emit()
	return true
