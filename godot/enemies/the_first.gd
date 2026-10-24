extends "res://enemies/stone_guardian.gd"

# "The First": the demo's final boss (main quest 5, "What They Made"). A beast
# the cult swelled with stolen life, half-finished and unstable. It fights like
# the Stone Guardian (slam, sweep, phase 2 at half health; use it on
# stone_guardian.tscn with this script swapped in), but:
#   - it's pale and glows, pulsing faster as it weakens;
#   - it leaks: every few seconds a ring of stolen light rolls out from it
#     (a shockwave: jump it), more often in phase 2;
#   - it wakes from the ritual, not as a statue: the RitualSite starts the fight;
#   - dying, it comes apart into light (no heart to take) and sets `slain_flag`,
#     which shows the stream of light flowing north (a DrainLine).

@export var slain_flag: String = "first_slain"
@export var leak_interval: float = 7.0
@export var leak_interval_phase_two: float = 4.0
@export var leak_damage: float = 10.0
## More than the Guardian's 400: it's the last fight (tuned with tests/test_first_fight.gd).
@export var boss_health: float = 550.0

const SKIN := Color(0.62, 0.64, 0.6)
const GLOW := Color(0.6, 1.0, 0.8)

var _leak_left := 0.0
var _pulse := 0.0


func _ready() -> void:
	super()
	if state == State.DEAD:
		return
	stats.max_health = boss_health
	stats.refill()
	_stone_material.albedo_color = SKIN
	_stone_material.emission_enabled = true
	_stone_material.emission = GLOW
	_stone_material.emission_energy_multiplier = 0.3
	model.scale = Vector3.ONE * 1.25   # swollen; the collision shape stays the guardian's
	shockwave_color = GLOW
	_eye_material.albedo_color = GLOW
	eye_light.light_color = GLOW
	eye_light.light_energy = 1.0
	_leak_left = leak_interval


func wake(player: Node3D) -> void:
	super(player)
	# It knows its own kind (systems/corruption.gd).
	if Corruption.tier() >= 2 and player.has_method("show_message"):
		GameState.set_flag("first_recognised_you")
		player.show_message("It stops. Its swollen head turns towards you, slowly, the way a dog turns to a familiar step. A sound comes out of it like wind in a hollow tree: \"...you smell like us.\"")
	Hints.show_once("boss_first", "It leaks stolen light: when the ground starts to glow around it, a ring is coming. Jump it.")


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.DEAD or state == State.DORMANT:
		return
	# Unstable: the glow pulses, faster as it weakens.
	var weakness := 1.0 - stats.health / stats.max_health
	_pulse += delta * (2.0 + weakness * 6.0)
	_stone_material.emission_energy_multiplier = 0.3 + (0.5 + 0.5 * sin(_pulse)) * (0.6 + weakness)
	_leak_left -= delta
	if _leak_left <= 0.0 and state != State.STAGGER:
		_leak_left = leak_interval_phase_two if phase == 2 else leak_interval
		leak()


## A ring of stolen light rolls outward from it along the ground.
func leak() -> void:
	var damage := shockwave_damage
	shockwave_damage = leak_damage
	_shockwave(global_position)
	shockwave_damage = damage
	SpellBurst.spawn(_world(), global_position + Vector3.UP * 0.1, 1.8, GLOW)


func _on_damaged(_amount: float) -> void:
	var flash := create_tween()
	flash.tween_property(_stone_material, "albedo_color", Color(1, 1, 1), 0.04)
	flash.tween_property(_stone_material, "albedo_color", SKIN, 0.2)
	if phase == 1 and stats.health <= stats.max_health * 0.5 and stats.health > 0.0:
		_enter_phase_two()


func _on_died() -> void:
	state = State.DEAD
	collision_layer = 0
	eye_light.light_energy = 0.0
	Sfx.play_at("guardian_crumble", global_position, 4.0)
	# It comes apart: every piece floats up, shrinks and fades into light.
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var tween := part.create_tween().set_parallel()
		tween.tween_property(part, "global_position:y", part.global_position.y + randf_range(0.5, 2.0), 1.6)
		tween.tween_property(part, "scale", Vector3.ONE * 0.05, 1.6)
	var flare := create_tween()
	flare.tween_property(_stone_material, "emission_energy_multiplier", 4.0, 0.6)
	flare.tween_property(_stone_material, "emission_energy_multiplier", 0.0, 1.0)
	GameState.set_flag(slain_flag)
	died.emit()
