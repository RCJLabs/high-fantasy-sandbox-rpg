extends Node

# Who the player is beyond their race: name, background, traits, perks, the
# optional Survival / Hardcore modes, active powers (Z race, X background),
# and unspent perk / attribute points. Autoloaded as "Character".
#
# The options themselves are data in res://character/*.json (backgrounds,
# traits, perks, abilities) - placeholders to rename and rebalance freely.
#
# Traits, perks and Hardcore give *permanent* modifiers: modifier("skill_xp"),
# modifier("damage_taken")... The player's Stats multiplies these with its
# status effects, so every system that asks Stats.modifier() sees both.

signal changed
signal notice(text: String)

const FILES := {
	"backgrounds": "res://character/backgrounds.json",
	"traits": "res://character/traits.json",
	"perks": "res://character/perks.json",
	"abilities": "res://character/abilities.json",
}
## Hardcore v0: the world hits harder and you heal slowly (more in ROADMAP Phase 2-3).
const HARDCORE_MODIFIERS := {"damage_taken": 1.5, "damage_dealt": 1.2, "health_regen": 0.25}
const STARTING_PERK_POINTS := 1
## Character creation rules (drafts).
const CREATION_ATTRIBUTE_POINTS := 4
const MAX_POSITIVE_TRAITS := 2        # +1 more for each flaw taken
const MAX_NEGATIVE_TRAITS := 1

var backgrounds: Dictionary = {}
var trait_list: Dictionary = {}
var perk_list: Dictionary = {}
var ability_list: Dictionary = {}

var player_name := "Traveller"
var background := ""          # "" when a level is run directly (F6)
var traits: Array = []
var perks: Array = []
var perk_points := 0
var attribute_points := 0
var modes := {"survival": false, "hardcore": false}
var cooldowns: Dictionary = {}   # ability id -> seconds left


func _ready() -> void:
	for key in FILES:
		var data = JSON.parse_string(FileAccess.get_file_as_string(FILES[key]))
		if not data is Dictionary:
			push_error("Character: %s is missing or not valid JSON." % FILES[key])
			continue
		match key:
			"backgrounds": backgrounds = data
			"traits": trait_list = data
			"perks": perk_list = data
			"abilities": ability_list = data
	Skills.leveled_up.connect(_on_leveled_up)


func _process(delta: float) -> void:
	for id in cooldowns.keys():
		cooldowns[id] -= delta
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)
			notice.emit("%s is ready" % ability_list[id]["name"])


# --- creating a character -----------------------------------------------------------

## Starts a brand-new character. Resets every other system and applies the
## race, background, traits, spent attribute points and modes.
func create(race: RaceData, new_name: String, background_id: String, trait_ids: Array,
		attribute_spend: Dictionary, new_modes: Dictionary) -> void:
	GameState.set_race(race)
	GameState.flags = {}
	GameState.play_time = 0.0
	Skills.reset(race)
	Attributes.reset(race)
	Inventory.reset()
	Spellbook.reset(race)
	Reputation.reset()
	WorldState.reset()
	WorldClock.reset()
	Survival.reset()
	Corruption.reset()

	player_name = new_name.strip_edges() if new_name.strip_edges() != "" else "Traveller"
	background = background_id
	traits = trait_ids.duplicate()
	perks = []
	perk_points = STARTING_PERK_POINTS
	attribute_points = 0
	modes = {"survival": bool(new_modes.get("survival", false)), "hardcore": bool(new_modes.get("hardcore", false))}
	cooldowns = {}

	var bg: Dictionary = backgrounds.get(background_id, {})
	_add_attributes(bg.get("attributes", {}))
	for skill in bg.get("skills", {}):
		Skills.levels[skill] += int(bg["skills"][skill])
	for id in bg.get("gear", []):
		Inventory.items[id] = Inventory.count(id) + 1
		Inventory.equip(id)
	for id in bg.get("items", {}):
		Inventory.items[id] = Inventory.count(id) + int(bg["items"][id])
	Inventory.gold = int(bg.get("gold", 0))
	# Everyone packs a little food (it heals a bit; in Survival it's essential).
	Inventory.items["bread"] = Inventory.count("bread") + 2
	Inventory.items["water_flask"] = Inventory.count("water_flask") + 2
	for spell in bg.get("spells", []):
		Spellbook.learn(spell)
	_add_reputation(bg.get("reputation", {}))
	for id in traits:
		_add_attributes(trait_list[id].get("attributes", {}))
		_add_reputation(trait_list[id].get("reputation", {}))
	_add_attributes(attribute_spend)

	Skills.changed.emit()
	Inventory.changed.emit()
	QuestLog.reset_baseline()
	changed.emit()


## Why this trait selection isn't allowed, or "" if it is.
func traits_blocker(trait_ids: Array) -> String:
	var positive := trait_ids.filter(func(id): return trait_list[id]["positive"]).size()
	var negative := trait_ids.size() - positive
	if negative > MAX_NEGATIVE_TRAITS:
		return "At most %d flaw." % MAX_NEGATIVE_TRAITS
	if positive > MAX_POSITIVE_TRAITS + negative:
		return "At most %d strengths (+1 for taking a flaw)." % MAX_POSITIVE_TRAITS
	return ""


## The attributes create() would give, without changing anything.
func preview_attributes(race: RaceData, background_id: String, trait_ids: Array,
		attribute_spend: Dictionary) -> Dictionary:
	var result := {}
	for id in Attributes.ATTRIBUTES:
		result[id] = Attributes.BASE + int(race.attribute_bonuses.get(id, 0))
	var sources: Array = [backgrounds.get(background_id, {}).get("attributes", {}), attribute_spend]
	for id in trait_ids:
		sources.append(trait_list[id].get("attributes", {}))
	for bonuses in sources:
		for id in bonuses:
			result[id] += int(bonuses[id])
	return result


func _add_attributes(bonuses: Dictionary) -> void:
	for id in bonuses:
		Attributes.increase(id, int(bonuses[id]))


# Starting reputation is set directly: no race/Presence multipliers, no notices.
func _add_reputation(amounts: Dictionary) -> void:
	for faction in amounts:
		Reputation.values[faction] = clampi(Reputation.value(faction) + int(amounts[faction]), -100, 100)
	Reputation.changed.emit()


# --- permanent modifiers ----------------------------------------------------------------

## Product of every trait, perk and mode multiplier for `key` (1.0 if none).
func modifier(key: String) -> float:
	var result := 1.0
	for id in traits:
		result *= float(trait_list[id].get("modifiers", {}).get(key, 1.0))
	for id in perks:
		result *= float(perk_list[id].get("modifiers", {}).get(key, 1.0))
	if modes["hardcore"]:
		result *= float(HARDCORE_MODIFIERS.get(key, 1.0))
	return result * Corruption.modifier(key)


## Flat bonus to "health" / "stamina" / "magicka" maximums from perks and traits.
func stat_bonus(stat: String) -> float:
	var total := 0.0
	for id in perks:
		total += float(perk_list[id].get("stat_bonus", {}).get(stat, 0.0))
	for id in traits:
		total += float(trait_list[id].get("stat_bonus", {}).get(stat, 0.0))
	return total + Corruption.stat_bonus(stat)


# --- active powers (Z = race, X = background) ------------------------------------------

## [race power id, background power id] ("" if none).
func powers() -> Array:
	var bg_power: String = backgrounds.get(background, {}).get("ability", "")
	return [GameState.race_data.ability_id, bg_power]


## Uses power 0 (race) or 1 (background). Returns true if it worked.
func use_power(index: int) -> bool:
	var id: String = powers()[index]
	var player := get_tree().get_first_node_in_group("player")
	if id == "" or player == null or player.is_dead:
		return false
	var power: Dictionary = ability_list[id]
	if cooldowns.has(id):
		notice.emit("%s isn't ready (%ds)" % [power["name"], ceili(cooldowns[id])])
		return false
	if power.has("effect"):
		player.effects.apply(power["effect"])
	var restore: Dictionary = power.get("restore", {})
	if restore.has("health"):
		player.stats.heal(float(restore["health"]))
	if restore.has("stamina"):
		player.stats.stamina = minf(player.stats.stamina + float(restore["stamina"]), player.stats.max_stamina)
	if restore.has("magicka"):
		player.stats.magicka = minf(player.stats.magicka + float(restore["magicka"]), player.stats.max_magicka)
	player.stats.changed.emit()
	cooldowns[id] = float(power["cooldown"])
	notice.emit("%s!" % power["name"])
	return true


# --- level-ups: points to spend in the Tab menu -----------------------------------------

func _on_leveled_up(_level: int) -> void:
	perk_points += 1
	attribute_points += 1
	changed.emit()


func spend_attribute_point(id: String) -> bool:
	if attribute_points <= 0:
		return false
	attribute_points -= 1
	Attributes.increase(id)
	changed.emit()
	return true


## Why a perk can't be taken right now, or "" if it can.
func perk_blocker(id: String) -> String:
	var perk: Dictionary = perk_list[id]
	if id in perks:
		return "taken"
	if Skills.levels.get(perk["skill"], 0) < int(perk["level"]):
		return "needs %s %d" % [Skills.SKILLS[perk["skill"]]["name"], int(perk["level"])]
	if perk.has("requires") and not perk["requires"] in perks:
		return "needs %s" % perk_list[perk["requires"]]["name"]
	if perk_points <= 0:
		return "no perk points"
	return ""


func take_perk(id: String) -> bool:
	if perk_blocker(id) != "":
		return false
	perks.append(id)
	perk_points -= 1
	changed.emit()
	return true


# --- saving --------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"name": player_name, "background": background, "traits": traits, "perks": perks,
			"perk_points": perk_points, "attribute_points": attribute_points,
			"modes": modes, "cooldowns": cooldowns}


func from_dict(data: Dictionary) -> void:
	player_name = data.get("name", "Traveller")
	background = data.get("background", "")
	traits = data.get("traits", []).filter(func(id): return trait_list.has(id))
	perks = data.get("perks", []).filter(func(id): return perk_list.has(id))
	perk_points = int(data.get("perk_points", 0))
	attribute_points = int(data.get("attribute_points", 0))
	var saved_modes: Dictionary = data.get("modes", {})
	modes = {"survival": bool(saved_modes.get("survival", false)), "hardcore": bool(saved_modes.get("hardcore", false))}
	cooldowns = {}
	for id in data.get("cooldowns", {}):
		if ability_list.has(id):
			cooldowns[id] = float(data["cooldowns"][id])
	changed.emit()


## For saves from before characters existed: no background, traits or perks.
func reset() -> void:
	from_dict({})
