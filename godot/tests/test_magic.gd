extends "res://tests/test_base.gd"
# Magic basics: hold-to-heal, switching spells with Q, learning Flames at the crystal, burning a wolf, spells saved.
var f := 0
var started := false
var SB; var S; var GS
var h0 := 0.0; var m0 := 0.0; var h_after := 0.0

func player(): return get_first_node_in_group("player")

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)

func ready_id() -> String: return SB.current().id if SB.current() else "Block"

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		SB = autoload("Spellbook"); S = autoload("Skills"); GS = autoload("GameState")
		autoload("SaveSystem").delete_save()
		var race = load("res://races/%s.tres" % arg("human"))
		GS.set_race(race); S.reset(race); SB.reset(race); GS.flags = {}
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		ok(SB.known == ["healing"], "starts knowing only Healing", SB.known)
		ok(ready_id() == "healing", "Healing is ready")
		ok(player().hud.spell_label.text.begins_with("Healing"), "HUD shows Healing", player().hud.spell_label.text)
		return false
	f += 1
	var p = player()
	if f > 305 and f < 600:
		# Keep the stream on the wolf, as a player would: once it's hurt it closes in
		# and circles to a random flank spot, which can be outside a fixed aim.
		var w = current_scene.get_node("GreyfangPack/Wolf1")
		var d: Vector3 = w.global_position - p.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.get_node("Head").rotation.x = atan2(w.global_position.y + 0.4 - (p.global_position.y + 1.6), Vector2(d.x, d.z).length())
	match f:
		30:
			p.stats.take_damage(50); h0 = p.stats.health; m0 = p.stats.magicka
			Input.action_press("cast")
		150:
			Input.action_release("cast")
			between(p.stats.health - h0, 20.0, 30.0, "health healed by 2 s of Healing")
			between(m0 - p.stats.magicka, 15.0, 25.0, "magicka spent on 2 s of Healing")
			ok(S.xp["restoration"] > 3.0, "Restoration gained XP", S.xp["restoration"])
			ok(p.is_casting and p.heal_particles.emitting, "casting with heal sparks while held")
		152:
			ok(not p.is_casting and not p.heal_particles.emitting, "casting and sparks stop on release")
			h_after = p.stats.health
		210: between(p.stats.health - h_after, 0.0, 2.0, "regen paused for about 1 s after casting")
		220:
			ok(ready_id() == "healing", "Healing still ready before Q")
			key(KEY_Q)
		222:
			ok(ready_id() == "Block", "Q switches to Block")
			ok(player().hud.spell_label.text.begins_with("Block"), "HUD shows Block", player().hud.spell_label.text)
		225:
			p.global_position = Vector3(-11, 0, -7); p.rotation.y = 0; p.get_node("Head").rotation.x = deg_to_rad(-2)
		230:
			ok(p.hud.prompt_label.text == "[E] Touch the crystal", "crystal prompt", p.hud.prompt_label.text)
			Input.action_press("interact")
		231: Input.action_release("interact")
		235:
			ok(SB.knows("flames"), "the crystal teaches Flames", SB.known)
			ok(ready_id() == "flames", "Flames is readied")
			ok(p.hud.message_label.text.begins_with("Cold light runs up your arm"), "crystal message", p.hud.message_label.text)
		240:
			SB.select("flames"); p.stats.magicka = p.stats.max_magicka
			var w = current_scene.get_node("GreyfangPack/Wolf1")
			for other in current_scene.get_node("GreyfangPack").get_children(): other.aggro_range = 0.0
			# Hold it still: an idle wolf wanders to random spots, and could walk out of the
			# stream before the first hit (it did with seed 14: 0 damage).
			w.wander_speed = 0.0
			p.global_position = w.global_position + Vector3(0, 0, 4.5); p.rotation.y = 0; p.get_node("Head").rotation.x = deg_to_rad(-12)
			p.velocity = Vector3.ZERO
		245:
			current_scene.get_node("GreyfangPack/Wolf1").set_meta("h", current_scene.get_node("GreyfangPack/Wolf1").stats.health)
			Input.action_press("cast")
		305:
			var w = current_scene.get_node("GreyfangPack/Wolf1")
			between(w.get_meta("h") - w.stats.health, 10.0, 35.0, "1 s of Flames damages the wolf")
			ok(S.xp["destruction"] > 1.0, "Destruction gained XP", S.xp["destruction"])
			ok(p.fire_particles.emitting, "fire particles while casting")
			ok(p.hud.enemy_bar.visible, "enemy health bar shows")
		600:
			Input.action_release("cast")
			var w = current_scene.get_node("GreyfangPack/Wolf1")
			ok(w.state == w.State.DEAD, "the wolf dies to Flames", w.State.keys()[w.state])
			ok(p.stats.health > 20.0, "player survives the wolf", p.stats.health)
		610: key(KEY_F5)
		615: SB.reset(load("res://races/orc.tres")); key(KEY_F9)
		630:
			ok(SB.known == ["healing", "flames"], "after load: both spells known", SB.known)
			ok(ready_id() == "flames", "after load: Flames ready")
			autoload("SaveSystem").delete_save()
			return done()
	return false
