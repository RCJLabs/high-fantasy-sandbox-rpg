extends Node

# Saving and loading, with slots. Autoloaded as "SaveSystem".
#   F5 = quicksave (its own slot), F9 = load the most recent save.
#   The pause menu (Esc) saves to / loads from manual slots 1-5.
#   Resting (beds, campfires) autosaves to its own slot.
#   Hardcore characters can only save by resting (save_game refuses otherwise).
# Saves live in user://saves/<slot>.json. Find that folder with
# Project > Open User Data Folder (in the editor).
#
# What is saved: current level, race, story flags, attributes, skills and character level,
# inventory and gold, known spells, faction reputation, play time, player
# position/look direction and Health/Stamina/Magicka. Quest progress comes
# from flags and items. Things not driven by flags (e.g. a door you left
# open) reset when you load.

const SAVE_DIR := "user://saves/"
const OLD_SAVE_PATH := "user://savegame.json"   # before slots existed
const SAVE_VERSION := 11  # 2: skills, 3: inventory, 4: spells, 5: reputation, 6: slots + play time,
                          # 7: attributes, equipment, status effects, 8: character (background, traits, perks, modes),
                          # 9: world clock and survival needs, 10: the main questline (see _migrate_story),
                          # 11: corruption
const QUICKSAVE := "quicksave"
const AUTOSAVE := "autosave"
const MANUAL_SLOTS := ["slot_1", "slot_2", "slot_3", "slot_4", "slot_5"]

var _pending_player_state: Dictionary = {}
var _pending_marker := ""   # where to put the player after travelling


var _pending_message := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if FileAccess.file_exists(OLD_SAVE_PATH) and not FileAccess.file_exists(_path(QUICKSAVE)):
		DirAccess.rename_absolute(OLD_SAVE_PATH, _path(QUICKSAVE))   # keep the old save as the quicksave


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quicksave"):
		save_game(QUICKSAVE)
	elif event.is_action_pressed("quickload"):
		load_game()


func slot_title(slot: String) -> String:
	if slot == QUICKSAVE:
		return "Quicksave"
	if slot == AUTOSAVE:
		return "Autosave"
	return "Slot %s" % slot.trim_prefix("slot_")


## True if `slot` has a save. With no slot: true if any save exists.
func has_save(slot: String = "") -> bool:
	if slot != "":
		return FileAccess.file_exists(_path(slot))
	return not list_saves().is_empty()


## Every save, newest first: [{"slot": "slot_1", "meta": {...}}, ...]
func list_saves() -> Array:
	var saves := []
	for slot in [AUTOSAVE, QUICKSAVE] + MANUAL_SLOTS:
		if has_save(slot):
			var data = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
			if data is Dictionary:
				saves.append({"slot": slot, "meta": data.get("meta", {})})
	saves.sort_custom(func(a, b): return a["meta"].get("saved_at", 0) > b["meta"].get("saved_at", 0))
	return saves


func most_recent_slot() -> String:
	var saves := list_saves()
	return saves[0]["slot"] if not saves.is_empty() else ""


## One line describing a save, for menus.
func describe(meta: Dictionary) -> String:
	var minutes := int(meta.get("play_time", 0.0) / 60.0)
	var who: String = meta.get("race", "?")
	if meta.get("background", "") != "":
		who += " " + meta["background"]
	if meta.get("name", "") != "":
		who = "%s (%s)" % [meta["name"], who]
	return "%s, level %d  -  %s  -  %dh %02dm played  -  %s" % [
		who, meta.get("character_level", 1), meta.get("location", "?"),
		minutes / 60, minutes % 60, meta.get("saved_at_text", "")]


## `resting`: the save comes from sleeping (always allowed, even in Hardcore).
func save_game(slot: String = QUICKSAVE, resting: bool = false) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false   # e.g. on the title screen
	if DialogueManager.is_active or player.is_dead:
		player.show_message("You can't save right now.")
		return false
	if hardcore_saves_locked() and not resting:
		player.show_message("Hardcore: you can only save by resting at a bed or a campfire.")
		return false

	var level := get_tree().current_scene
	WorldState.collect()
	var data := {
		"version": SAVE_VERSION,
		"meta": {
			"saved_at": Time.get_unix_time_from_system(),
			"saved_at_text": Time.get_datetime_string_from_system(false, true).substr(0, 16),
			"race": GameState.race,
			"name": Character.player_name,
			"background": Character.backgrounds.get(Character.background, {}).get("name", ""),
			"character_level": Skills.character_level,
			"location": level.name.capitalize(),   # "TestLevel" -> "Test Level"
			"play_time": GameState.play_time,
		},
		"level": level.scene_file_path,
		"race": GameState.race_data.resource_path,
		"flags": GameState.flags,
		"play_time": GameState.play_time,
		"skills": Skills.to_dict(),
		"attributes": Attributes.to_dict(),
		"character": Character.to_dict(),
		"inventory": Inventory.to_dict(),
		"spells": Spellbook.to_dict(),
		"reputation": Reputation.to_dict(),
		"world": WorldState.to_dict(),
		"clock": WorldClock.to_dict(),
		"survival": Survival.to_dict(),
		"corruption": Corruption.to_dict(),
		"player": player.get_save_data(),
	}
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: can't write %s (error %d)" % [_path(slot), FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	player.show_message("Game saved (%s)." % slot_title(slot))
	return true


## Hardcore characters save only when they rest.
func hardcore_saves_locked() -> bool:
	return bool(Character.modes.get("hardcore", false))


## Loads `slot`, or the most recent save if no slot is given.
func load_game(slot: String = "") -> bool:
	if slot == "":
		slot = most_recent_slot()
	if slot == "" or not has_save(slot):
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.show_message("No save yet. Press F5 to save.")
		return false

	var data = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if not data is Dictionary or not int(data.get("version", 0)) in range(1, SAVE_VERSION + 1):
		push_error("SaveSystem: %s is damaged or from a newer version of the game." % _path(slot))
		return false

	if DialogueManager.is_active:
		DialogueManager.end()
	get_tree().paused = false
	QuestLog.silent = true   # restoring flags/items isn't "progress" - don't announce it
	GameState.set_race(load(data["race"]))
	GameState.flags = data["flags"]
	_pending_message = _migrate_story(int(data["version"]))
	GameState.play_time = float(data.get("play_time", 0.0))
	if data.has("attributes"):
		Attributes.from_dict(data["attributes"])
	else:
		Attributes.reset(GameState.race_data)   # older saves: race values
	if data.has("character"):
		Character.from_dict(data["character"])
	else:
		Character.reset()   # older saves: no background, traits or perks
	if data.has("skills"):
		Skills.from_dict(data["skills"])
	else:
		Skills.reset(GameState.race_data)   # version 1 saves had no skills
	if data.has("inventory"):
		Inventory.from_dict(data["inventory"])
	else:
		Inventory.reset()                   # versions 1-2 had no inventory
	if data.has("spells"):
		Spellbook.from_dict(data["spells"])
	else:
		Spellbook.reset(GameState.race_data)   # versions 1-3 had no spells
	if data.has("reputation"):
		Reputation.from_dict(data["reputation"])
	else:
		Reputation.reset()                     # versions 1-4 had no reputation
	WorldState.from_dict(data.get("world", {}))   # versions 1-6: nothing remembered yet
	WorldClock.from_dict(data.get("clock", {}))   # versions 1-8: morning of day 1
	Survival.from_dict(data.get("survival", {}))  # versions 1-8: no needs yet
	Corruption.from_dict(data.get("corruption", {}))   # versions 1-10: none
	if not data.has("corruption") and GameState.has_flag("took_wisp_essence"):
		Corruption.value = 35.0   # took the caged wisp's light before corruption existed
	QuestLog.silent = false
	QuestLog.reset_baseline()
	_pending_player_state = data["player"]
	_pending_marker = ""
	_change_scene_at_end_of_frame(data["level"])
	return true


## Saves from before the main questline (version 9 and older): start it, so the
## character isn't locked out of the story, and keep a finished Waking Stones
## finished (it gained a last step, the drain-line, which these saves never saw).
## Returns a note for the player about what changed, or "".
func _migrate_story(version: int) -> String:
	if version >= 10:
		return ""
	var changes := []
	if not GameState.has_flag("wrong_things_started"):
		GameState.set_flag("wrong_things_started")
		changes.append("Maren at the waystation has news.")
	if GameState.has_flag("stones_quest_done") and not GameState.has_flag("saw_drain_line"):
		GameState.set_flag("saw_drain_line")
		changes.append("A thread of light now runs north from the stone circle.")
	if changes.is_empty():
		return ""
	return "This save is from an older version of the game. " + " ".join(changes)


## Called by the player when it spawns: a one-off message after loading, or "".
func take_pending_message() -> String:
	var message := _pending_message
	_pending_message = ""
	return message


# change_scene_to_file() takes the current level out of the tree immediately.
# Travel and loading are usually triggered from inside the player's own update
# (E on a door, dying), so the rest of that update would run on a player that's
# no longer in the world. Deferring the change avoids that.
func _change_scene_at_end_of_frame(scene_path: String) -> void:
	get_tree().call_deferred("change_scene_to_file", scene_path)


## Go to another location (used by location doors). The current location is
## remembered, and the player keeps health, effects, items and so on, arriving
## at the Marker3D named `marker` in the new scene.
func travel(scene_path: String, marker: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not ResourceLoader.exists(scene_path):
		push_error("SaveSystem.travel: can't go to %s" % scene_path)
		return
	WorldState.collect()
	_pending_player_state = player.get_save_data()
	_pending_player_state.erase("position")   # the marker decides where you appear
	_pending_marker = marker
	_change_scene_at_end_of_frame(scene_path)


## Called by the player when it spawns: the Marker3D name to appear at, or "".
func take_pending_marker() -> String:
	var marker := _pending_marker
	_pending_marker = ""
	return marker


## Called by the player when it spawns. Returns {} unless a load is in progress.
func take_pending_player_state() -> Dictionary:
	var state := _pending_player_state
	_pending_player_state = {}
	return state


## Deletes one slot, or every save if no slot is given.
func delete_save(slot: String = "") -> void:
	for s in ([slot] if slot != "" else [AUTOSAVE, QUICKSAVE] + MANUAL_SLOTS):
		if has_save(s):
			DirAccess.remove_absolute(_path(s))
	if slot == "" and FileAccess.file_exists(OLD_SAVE_PATH):
		DirAccess.remove_absolute(OLD_SAVE_PATH)


func _path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"
