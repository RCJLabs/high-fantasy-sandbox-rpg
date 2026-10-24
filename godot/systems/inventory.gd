extends Node

# The player's items, gold and equipped gear. Autoloaded as "Inventory".
#   Inventory.add("wolf_pelt")           Inventory.remove("wolf_pelt", 2)
#   Inventory.count("wolf_pelt")         Inventory.add_gold(10)
#   Inventory.use("minor_healing_potion")
#   Inventory.equip("iron_sword")        Inventory.equipped_item("main_hand")
# Equipped items stay in the inventory (like Skyrim); removing the last one
# unequips it.

signal changed
signal item_added(item: ItemData, amount: int)
signal gold_added(amount: int)
signal equipment_changed

## Every item in the game. Add new item files here.
const ITEM_FILES := [
	"res://items/wolf_pelt.tres",
	"res://items/minor_healing_potion.tres",
	"res://items/rune_shard.tres",
	"res://items/charcoal_rubbing.tres",
	"res://items/posting_orders.tres",
	"res://items/collegium_letter.tres",
	"res://items/wanted_notice.tres",
	"res://items/wagon_manifest.tres",
	"res://items/marked_coin.tres",
	"res://items/supply_crate.tres",
	"res://items/cult_notes.tres",
	"res://items/cult_letter.tres",
	"res://items/strongbox.tres",
	"res://items/rune_glass.tres",
	"res://items/iron_sword.tres",
	"res://items/hunting_dagger.tres",
	"res://items/leather_cuirass.tres",
	"res://items/leather_boots.tres",
	"res://items/iron_helmet.tres",
	"res://items/iron_axe.tres",
	"res://items/iron_mace.tres",
	"res://items/steel_greatsword.tres",
	"res://items/wooden_shield.tres",
	"res://items/hunting_bow.tres",
	"res://items/arrow.tres",
	"res://items/tome_firebolt.tres",
	"res://items/tome_frost_burst.tres",
	"res://items/tome_healing_ward.tres",
	"res://items/tome_mending.tres",
	"res://items/tome_stoneflesh.tres",
	"res://items/tome_candlelight.tres",
	"res://items/bread.tres",
	"res://items/apple.tres",
	"res://items/water_flask.tres",
	"res://items/raw_wolf_meat.tres",
	"res://items/cooked_wolf_meat.tres",
	"res://items/wisp_essence.tres",
	"res://items/guardian_heart.tres",
]

## What every new character starts with (equipped). Backgrounds will change this.
const STARTING_GEAR := ["iron_sword", "leather_cuirass", "leather_boots"]

var items: Dictionary = {}   # item id -> how many
var gold: int = 0
var equipped: Dictionary = {}   # slot name -> item id

var _catalog: Dictionary = {}   # item id -> ItemData


func _ready() -> void:
	for path in ITEM_FILES:
		var item: ItemData = load(path)
		_catalog[item.id] = item
	give_starting_gear()   # so levels run on their own (F6) armed


func get_item(id: String) -> ItemData:
	if not _catalog.has(id):
		push_error("Inventory: unknown item id '%s'. Is it listed in ITEM_FILES?" % id)
	return _catalog.get(id)


func add(id: String, amount: int = 1) -> void:
	var item := get_item(id)
	if item == null or amount <= 0:
		return
	items[id] = items.get(id, 0) + amount
	item_added.emit(item, amount)
	changed.emit()


## Returns false (and removes nothing) if there aren't enough.
func remove(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	items[id] -= amount
	if items[id] == 0:
		items.erase(id)
		for slot in equipped.keys():
			if equipped[slot] == id:
				unequip(slot)
	changed.emit()
	return true


func count(id: String) -> int:
	return items.get(id, 0)


func add_gold(amount: int) -> void:
	gold += amount
	gold_added.emit(amount)
	changed.emit()


## Uses a consumable on the player. Returns false if it can't be used.
func use(id: String) -> bool:
	var item := get_item(id)
	var player := get_tree().get_first_node_in_group("player")
	if item == null or item.type != ItemData.Type.CONSUMABLE or player == null or count(id) == 0:
		return false
	if item.teaches_spell != "":
		if Spellbook.knows(item.teaches_spell):
			player.hud.notify("You already know %s" % Spellbook.get_spell(item.teaches_spell).display_name)
			return false
		Spellbook.learn(item.teaches_spell)
		remove(id)
		return true
	var stats: Stats = player.stats
	Survival.ease(item)
	if item.side_effect != "" and randf() < item.side_effect_chance:
		player.effects.apply(item.side_effect)
	if item.corruption > 0.0:
		Corruption.add(item.corruption, item.display_name)
	stats.heal(item.restore_health)
	stats.stamina = minf(stats.stamina + item.restore_stamina, stats.max_stamina)
	stats.magicka = minf(stats.magicka + item.restore_magicka, stats.max_magicka)
	stats.changed.emit()
	remove(id)
	return true


# --- equipment ----------------------------------------------------------------------

func equip(id: String) -> bool:
	var item := get_item(id)
	if item == null or not item.is_equipment() or count(id) == 0:
		return false
	# Two-handed weapons and shields can't be used together.
	if item.slot_name() == "main_hand" and item.two_handed:
		equipped.erase("off_hand")
	elif item.slot_name() == "off_hand" and equipped_item("main_hand") and equipped_item("main_hand").two_handed:
		equipped.erase("main_hand")
	equipped[item.slot_name()] = id
	equipment_changed.emit()
	changed.emit()
	return true


func unequip(slot: String) -> void:
	if equipped.erase(slot):
		equipment_changed.emit()
		changed.emit()


func is_equipped(id: String) -> bool:
	return id in equipped.values()


func equipped_item(slot: String) -> ItemData:
	return get_item(equipped[slot]) if equipped.has(slot) else null


func armor_total() -> float:
	var total := 0.0
	for id in equipped.values():
		total += get_item(id).armor
	return total


func give_starting_gear() -> void:
	for id in STARTING_GEAR:
		if count(id) == 0:
			items[id] = 1
		equip(id)


func reset() -> void:
	items = {}
	gold = 0
	equipped = {}
	equipment_changed.emit()
	changed.emit()


func to_dict() -> Dictionary:
	return {"items": items, "gold": gold, "equipped": equipped}


func from_dict(data: Dictionary) -> void:
	items = {}
	for id in data["items"]:
		if _catalog.has(id):   # skip items removed from the game since the save
			items[id] = int(data["items"][id])
	gold = int(data["gold"])
	equipped = {}
	if data.has("equipped"):
		for slot in data["equipped"]:
			var id: String = data["equipped"][slot]
			if _catalog.has(id) and count(id) > 0:
				equipped[slot] = id
	else:
		give_starting_gear()   # saves from before equipment existed: don't leave them unarmed
	equipment_changed.emit()
	changed.emit()
