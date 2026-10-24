extends "res://tests/test_base.gd"
# Old saves and the main questline (save version 10): a version-9 save from
# before the main quest starts it on load; one that had finished The Waking
# Stones keeps it finished (and sees the drain-line); a one-off message says
# so. A version-9 save that already had the story gets no message. Current
# saves are untouched.
var f := 0
var step := 0
var wait := 0
var S
var GS
var Q

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func rewrite(slot: String, edit: Callable) -> void:
	var path: String = S._path(slot)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	edit.call(data)
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(data))

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	S = autoload("SaveSystem"); GS = autoload("GameState"); Q = autoload("QuestLog")
	var p = get_first_node_in_group("player")
	match step:
		0:
			wait = 5
		1:
			ok(S.SAVE_VERSION >= 10, "save version 10 or later")
			# An old character who finished The Waking Stones before the main story existed.
			for flag in ["met_brannoc", "touched_crystal", "stones_quest_started", "shards_decided", "shards_given", "stones_quest_done"]:
				GS.set_flag(flag)
			ok(S.save_game(S.QUICKSAVE), "saved")
			rewrite(S.QUICKSAVE, func(d):
				d["version"] = 9
				d["flags"].erase("wrong_things_started")
				d["flags"].erase("saw_drain_line"))
			ok(S.load_game(S.QUICKSAVE), "old save loads")
			wait = 15
		2:
			ok(GS.has_flag("wrong_things_started"), "the main quest has started")
			ok(Q.status("wrong_things")["state"] == "active", "Wrong Things active")
			ok(Q.status("waking_stones")["state"] == "completed", "The Waking Stones stays finished")
			ok(Q.status("ask_forest")["state"] == "active", "and the drain-line leads on: Ask the Forest")
			ok(current_scene.get_node("DrainLine").visible, "the drain-line shows")
			var msg: String = p.hud.message_label.text
			ok(msg.begins_with("This save is from an older version") and msg.contains("Maren") and msg.contains("thread of light"), "a note about what changed", msg)
			# A version-9 save that already had the main story (made with the openings build).
			ok(S.save_game(S.QUICKSAVE), "saved again")
			rewrite(S.QUICKSAVE, func(d): d["version"] = 9)
			p.hud.show_message("")
			ok(S.load_game(S.QUICKSAVE), "loads")
			wait = 15
		3:
			ok(p.hud.message_label.text == "", "nothing to say when nothing changed", p.hud.message_label.text)
			ok(S._pending_message == "", "no message left over")
			# A current save: untouched.
			GS.flags.erase("saw_drain_line")
			ok(S.save_game(S.QUICKSAVE), "a current save")
			ok(S.load_game(S.QUICKSAVE), "loads")
			wait = 15
		4:
			ok(not GS.has_flag("saw_drain_line"), "current saves aren't migrated")
			ok(Q.status("waking_stones")["state"] == "active", "(so this one's Waking Stones waits on the crystal)")
			S.delete_save()
			return done()
	step += 1
	return false
