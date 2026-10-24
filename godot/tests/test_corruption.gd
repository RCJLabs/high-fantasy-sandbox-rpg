extends "res://tests/test_base.gd"
# Corruption (systems/corruption.gd): swallowing Wisp Essence and taking the caged
# wisp's light raise it through Touched, Stained and Hollowing, each with its gains
# and costs on the player; people notice; The First recognises you; the ending
# changes; the shrine refuses to bless you and cleanses one tier per night's vigil;
# it's saved, and an old save that took the caged wisp's light gets its stain.
const LEVEL := "res://levels/test_level.tscn"
var f := 0
var step := 0
var wait := 0
var p
var C
var GS
var DM
var I
var clock
var base := {}

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file(LEVEL)

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func talk(file: String) -> String:
	if DM.is_active:
		DM.end()
	DM.start("res://dialogue/%s.json" % file, file)
	return DM.line_label.text

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Corruption"); GS = autoload("GameState"); DM = autoload("DialogueManager")
	I = autoload("Inventory"); clock = autoload("WorldClock")
	match step:
		0:
			wait = 5
		1:
			ok(C.tier() == 0 and p.hud.corruption_label.text == "", "clean at the start")
			base = {"health": p.stats.max_health, "magicka": p.stats.max_magicka,
					"spell": p.stats.modifier("spell_power"), "regen": p.stats.modifier("health_regen")}
			# Swallowing Wisp Essence: +40 Magicka, +10 corruption each.
			I.add("wisp_essence", 2)
			p.stats.magicka = 0.0
			ok(I.use("wisp_essence"), "swallow a Wisp Essence")
			near(p.stats.magicka, 40.0, 0.5, "it still restores Magicka")
			near(C.value, 10.0, 0.01, "+10 corruption")
			ok(C.tier() == 0, "not yet Touched")
			I.use("wisp_essence")
			ok(C.tier() == 1 and C.tier_name() == "Touched", "two make you Touched", C.value)
			ok(p.hud.corruption_label.text == "Corruption: Touched", "shown on the HUD", p.hud.corruption_label.text)
			ok(p.hud.message_label.text.contains("(Corruption: Touched)"), "you feel it", p.hud.message_label.text)
			near(p.stats.modifier("spell_power"), base["spell"] * 1.1, 0.001, "Touched: spells +10%")
			near(p.stats.modifier("health_regen"), base["regen"] * 0.75, 0.001, "Touched: health regen x0.75")
			ok(GS.has_flag("hint_corruption"), "the corruption hint")
			ok(load("res://systems/conditions.gd").met({"requires_corruption": 1}), "requires_corruption 1 met")
			ok(not load("res://systems/conditions.gd").met({"requires_corruption_below": 1}), "requires_corruption_below 1 not met")
			# People notice.
			GS.set_flag("met_zora")
			ok(talk("zora").contains("Drawn. Not much, yet."), "Zora notices", DM.line_label.text)
			ok(not talk("aurel").begins_with("Aurel looks at you over his spectacles"), "Aurel doesn't, yet")
			DM.end()
			# Taking the caged wisp's light: +35, to Stained.
			C.add(35.0, "the wisp's light")
		2:
			ok(C.tier() == 2, "Stained", C.value)
			near(p.stats.max_magicka, base["magicka"] + 20.0, 0.5, "Stained: +20 max Magicka")
			near(p.stats.modifier("health_regen"), base["regen"] * 0.5, 0.001, "Stained: health regen x0.5")
			ok(talk("aurel").begins_with("Aurel looks at you over his spectacles"), "Aurel notices", DM.line_label.text)
			DM.end()
			# The shrine, rekindled, won't bless you now.
			for flag in ["shrine_rekindled", "silent_shrine_started"]:
				GS.set_flag(flag)
			clock.advance(clock.hours_until(12.0))
			p.stats.health = 30.0
			n("RoadsideShrine").interact(p)
			near(p.stats.health, 30.0, 0.5, "no blessing while Stained")
			ok(p.hud.message_label.text.contains("won't bless what you carry"), "and it says why", p.hud.message_label.text)
			# On to Hollowing.
			var rep: int = autoload("Reputation").value("thornwood_free")
			C.add(30.0)
			ok(C.tier() == 3, "Hollowing", C.value)
			near(p.stats.max_health, base["health"] - 20.0, 0.5, "Hollowing: -20 max Health")
			near(p.stats.max_magicka, base["magicka"] + 40.0, 0.5, "Hollowing: +40 max Magicka")
			near(p.stats.modifier("spell_power"), base["spell"] * 1.3, 0.001, "Hollowing: spells +30%")
			ok(autoload("Reputation").value("thornwood_free") == rep - 20, "the outlaws turn cold")
			C.add(5.0)
			ok(autoload("Reputation").value("thornwood_free") == rep - 20, "only once")
			GS.set_flag("met_mirela")
			ok(talk("mirela").contains("Grey fingertips"), "Mirela sees it", DM.line_label.text)
			ok(not talk("mirela").contains("Grey fingertips"), "once")
			DM.end()
			# The First knows you.
			var first = n("TheFirst")
			first.wake(p)
			ok(GS.has_flag("first_recognised_you") and p.hud.message_label.text.contains("you smell like us"), "The First recognises you", p.hud.message_label.text)
			# The ending.
			GS.set_flag("read_letter")
			ok(talk("maren").begins_with("She looks at your hands before your face."), "Maren's Hollowing ending", DM.line_label.text)
			ok(GS.has_flag("demo_finished") and GS.has_flag("told_maren_end"), "it ends the demo")
			DM.end()
			var labels: Array = autoload("Openings")._card.find_children("*", "Label", true, false)
			ok(labels.size() == 2 and labels[1].text.contains("The light you took is still in you"), "the closing card knows", labels.map(func(l): return l.text))
			ok(autoload("QuestLog").status("what_they_made")["outcome"].contains("you smell like us"), "and so does the journal")
			# Saved.
			ok(autoload("SaveSystem").save_game(autoload("SaveSystem").QUICKSAVE), "saved")
			C.value = 0.0
			ok(autoload("SaveSystem").load_game(autoload("SaveSystem").QUICKSAVE), "loading")
			wait = 15
		3:
			near(C.value, 90.0, 0.01, "corruption survives a load")
			near(p.stats.max_health, base["health"] - 20.0, 0.5, "and its costs")
			# Cleansing: a vigil at night, one tier a night.
			GS.set_flag("shrine_answered")
			var shrine = n("RoadsideShrine")
			clock.advance(clock.hours_until(12.0))
			ok(shrine.prompt == "Pray at the shrine", "no vigil by day")
			clock.advance(clock.hours_until(23.0))
			ok(shrine.prompt == "Keep a vigil until dawn", "a vigil at night", shrine.prompt)
			shrine.interact(p)
			ok(C.tier() == 2, "one night: Hollowing to Stained", C.value)
			near(clock.hour, 6.0, 0.05, "until dawn")
			ok(p.hud.message_label.text.contains("Hollowing → Stained"), "the vigil's message", p.hud.message_label.text)
			for night in 2:
				clock.advance(clock.hours_until(23.0))
				shrine.interact(p)
			ok(C.tier() == 0 and C.value == 0.0, "three nights: clean", C.value)
			ok(p.hud.corruption_label.text == "", "gone from the HUD")
			near(p.stats.max_health, base["health"], 0.5, "max Health back")
			near(p.stats.modifier("spell_power"), base["spell"], 0.001, "and spell power")
			clock.advance(clock.hours_until(23.0))
			ok(shrine.prompt == "Pray at the shrine", "nothing left to cleanse")
			# An old save (version 10) that took the caged wisp's light.
			GS.set_flag("took_wisp_essence")
			var S = autoload("SaveSystem")
			S.save_game(S.QUICKSAVE)
			var path: String = S._path(S.QUICKSAVE)
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			data["version"] = 10
			data.erase("corruption")
			FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(data))
			S.load_game(S.QUICKSAVE)
			wait = 15
		4:
			near(C.value, 35.0, 0.01, "an old save that took the wisp's light starts Touched")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
