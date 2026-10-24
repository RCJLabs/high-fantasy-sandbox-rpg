extends StaticBody3D

# The last caged wisp in the barrow's hidden chamber (main quest 4). Use it (E)
# for res://dialogue/caged_wisp.json, which sets one of two flags:
#   freed_wisp          it flies out and follows you as a light (WispCompanion)
#   took_wisp_essence   you draw its light into yourself: +25 max Magicka, Corruption
#                       +35 (Touched), and the outlaws hear about it (-15 Thornwood Free)
# Either also sets wisp_choice_made. Add an "Orb" MeshInstance3D and a "Light"
# OmniLight3D as children for the wisp inside the cage.

const DIALOGUE := "res://dialogue/caged_wisp.json"
const ESSENCE_MAGICKA := 25
const ESSENCE_REPUTATION := -15
const ESSENCE_CORRUPTION := 35.0

var prompt: String = "Look at the caged wisp"

@onready var orb: Node3D = $Orb
@onready var light: OmniLight3D = $Light


func _ready() -> void:
	if GameState.has_flag("wisp_choice_made"):
		_empty()
	GameState.flag_set.connect(_on_flag_set)


func interact(_player: Node) -> void:
	if not GameState.has_flag("wisp_choice_made"):
		DialogueManager.start(DIALOGUE, "Caged wisp")


func _on_flag_set(flag: String) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	match flag:
		"freed_wisp":
			prompt = ""
			var tween := create_tween()
			tween.tween_property(orb, "position", orb.position + Vector3(0, 1.2, 0), 0.8)
			tween.tween_callback(func():
				_empty()
				if player:
					WispCompanion.ensure(player))
		"took_wisp_essence":
			prompt = ""
			Skills.grant_bonus("magicka", ESSENCE_MAGICKA)
			Reputation.add("thornwood_free", ESSENCE_REPUTATION)
			Corruption.add(ESSENCE_CORRUPTION, "the wisp's light")
			var tween := create_tween().set_parallel()
			if player:
				tween.tween_property(orb, "global_position", player.global_position + Vector3.UP * 1.3, 0.6)
			tween.tween_property(orb, "scale", Vector3.ONE * 0.1, 0.6)
			tween.tween_property(light, "light_energy", 0.0, 0.6)
			tween.chain().tween_callback(_empty)


func _empty() -> void:
	prompt = ""
	orb.visible = false
	light.visible = false
