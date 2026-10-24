extends Node

# Corruption ("Stain"): what drawing on other living things' light does to you.
# Autoloaded as "Corruption". Design: docs/CORRUPTION.md.
#
# A value from 0 to 100, raised by corrupt acts (swallowing Wisp Essence, taking
# the caged wisp's light) and never falling on its own. Three tiers each give a
# gain and a cost:
#   1 Touched   (20+)  spells +10%                  health regen x0.75
#   2 Stained   (50+)  spells +20%, +20 Magicka     health regen x0.5, the shrine won't bless you
#   3 Hollowing (80+)  spells +30%, +40 Magicka     health regen x0.5, -20 max Health, outlaws turn cold
# The gains and costs reach the player through Character.modifier() and
# Character.stat_bonus(). Cleansing (cleanse_tier) is a night's vigil at the
# rekindled roadside shrine: one tier per night.
# Dialogue and quests can check the tier: "requires_corruption": 2 (at least),
# "requires_corruption_below": 1 (see systems/conditions.gd).

signal changed
signal tier_changed(tier: int, old_tier: int)

const MAX := 100.0
const THRESHOLDS := [0.0, 20.0, 50.0, 80.0]   # where each tier starts
const NAMES := ["", "Touched", "Stained", "Hollowing"]
const MODIFIERS := [
	{},
	{"spell_power": 1.1, "health_regen": 0.75},
	{"spell_power": 1.2, "health_regen": 0.5},
	{"spell_power": 1.3, "health_regen": 0.5},
]
const STAT_BONUS := [{}, {}, {"magicka": 20.0}, {"magicka": 40.0, "health": -20.0}]
const DESCRIPTIONS := [
	"",
	"Something cold has settled behind your eyes. Spells come easier; wounds close slower.",
	"Your veins show faintly green in the dark. Spells come easily, wounds close slowly, and the roadside shrine won't bless you.",
	"Your fingertips have gone grey, like Dunya's. Great power, a weaker body, and people who know what it means can see it.",
]
const ARRIVE_MESSAGES := [
	"The stolen light fades out of you. You feel heavier, and cleaner.",
	"Something cold settles behind your eyes. Spells come easier; wounds close slower. (Corruption: Touched)",
	"In the dark, your veins show faintly green. (Corruption: Stained)",
	"Your fingertips have gone grey, like Dunya's. The light in you pulls north, like a tide. (Corruption: Hollowing)",
]
## Thornwood Free reputation lost the first time you reach Hollowing: they've seen this before.
const HOLLOWING_REPUTATION := -20

var value := 0.0


func tier() -> int:
	for t in range(THRESHOLDS.size() - 1, -1, -1):
		if value >= THRESHOLDS[t]:
			return t
	return 0


func tier_name() -> String:
	return NAMES[tier()]


func description() -> String:
	return DESCRIPTIONS[tier()]


## A corrupt act. `what` is for the notice ("Wisp Essence").
func add(amount: float, what: String = "") -> void:
	if amount <= 0.0:
		return
	_set_value(value + amount, what)
	Hints.show_once("corruption", "Corruption: drawing on another living thing's light stains you. It makes spells stronger and your body weaker. A rekindled shrine can cleanse it, one step a night.")


## One night's vigil: down one tier (to the start of the tier below). Returns
## false if there's nothing to cleanse.
func cleanse_tier() -> bool:
	var t := tier()
	if t == 0:
		return false
	_set_value(THRESHOLDS[t - 1], "")
	return true


func modifier(key: String) -> float:
	return float(MODIFIERS[tier()].get(key, 1.0))


func stat_bonus(stat: String) -> float:
	return float(STAT_BONUS[tier()].get(stat, 0.0))


func _set_value(new_value: float, what: String) -> void:
	var old_tier := tier()
	value = clampf(new_value, 0.0, MAX)
	var new_tier := tier()
	changed.emit()
	if new_tier == old_tier:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.show_message(ARRIVE_MESSAGES[new_tier] if new_tier > 0 else ARRIVE_MESSAGES[0])
	if new_tier == 3 and not GameState.has_flag("reached_hollowing"):
		GameState.set_flag("reached_hollowing")
		Reputation.add("thornwood_free", HOLLOWING_REPUTATION)
	tier_changed.emit(new_tier, old_tier)
	Character.changed.emit()   # the player recalculates max Health and Magicka


func reset() -> void:
	value = 0.0
	changed.emit()


func to_dict() -> Dictionary:
	return {"value": value}


func from_dict(data: Dictionary) -> void:
	value = clampf(float(data.get("value", 0.0)), 0.0, MAX)
	changed.emit()
