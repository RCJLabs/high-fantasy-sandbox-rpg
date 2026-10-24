class_name Conditions

# The condition rules shared by dialogue (choices, start entries) and quests
# (started_when, done_when, ...). A condition is a Dictionary; every key in it
# must pass:
#   "requires_flag": "name" or ["a", "b"]       all of these flags are set
#   "requires_not_flag": "name" or ["a", "b"]   none of these flags are set
#   "requires_race": "Orc"
#   "requires_background": "soldier" or ["soldier", "hunter"]   any of these
#   "requires_trait": "charming" or ["a", "b"]                   all of these
#   "requires_item": "id" or {"id": "id", "count": 3}
#   "requires_not_item": "id"                    you carry none of it
#   "requires_gold": 50
#   "requires_reputation": {"riverwatch": 10}        at least this much
#   "requires_reputation_below": {"riverwatch": 0}   less than this
#   "requires_corruption": 2          corruption tier at least this (1 Touched, 2 Stained, 3 Hollowing)
#   "requires_corruption_below": 2    corruption tier lower than this
# An empty Dictionary always passes.


static func met(entry: Dictionary) -> bool:
	for flag in as_list(entry.get("requires_flag", [])):
		if not GameState.has_flag(flag):
			return false
	for flag in as_list(entry.get("requires_not_flag", [])):
		if GameState.has_flag(flag):
			return false
	if entry.has("requires_race") and entry["requires_race"] != GameState.race:
		return false
	if entry.has("requires_background") and not Character.background in as_list(entry["requires_background"]):
		return false
	for id in as_list(entry.get("requires_trait", [])):
		if not id in Character.traits:
			return false
	if entry.has("requires_item"):
		var need := item_and_count(entry["requires_item"])
		if Inventory.count(need[0]) < need[1]:
			return false
	if entry.has("requires_not_item") and Inventory.count(item_and_count(entry["requires_not_item"])[0]) > 0:
		return false
	if entry.has("requires_gold") and Inventory.gold < int(entry["requires_gold"]):
		return false
	for faction in entry.get("requires_reputation", {}):
		if Reputation.value(faction) < int(entry["requires_reputation"][faction]):
			return false
	for faction in entry.get("requires_reputation_below", {}):
		if Reputation.value(faction) >= int(entry["requires_reputation_below"][faction]):
			return false
	if entry.has("requires_corruption") and Corruption.tier() < int(entry["requires_corruption"]):
		return false
	if entry.has("requires_corruption_below") and Corruption.tier() >= int(entry["requires_corruption_below"]):
		return false
	return true


static func as_list(value) -> Array:
	return value if value is Array else [value]


# "id" -> ["id", 1];  {"id": "id", "count": 3} -> ["id", 3]
static func item_and_count(value) -> Array:
	if value is Dictionary:
		return [value["id"], int(value.get("count", 1))]
	return [value, 1]
