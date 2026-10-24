extends "res://tests/test_base.gd"
# Wolf pathfinding: the pack reaches a player behind a U-shaped wall, and when an
# attacker dies, a waiting wolf steps in. Argument: nav_kill (default) or direct
# (no navmesh; only for comparison, it doesn't check the kill).
# Wolves start north of a U (open to the south, where the player stands).
# Straight-line chasing hits the back of the U; pathfinding goes around it.
var f := 0
var started := false
var mode := "nav_kill"
var level
var killed := ""

func wall(wall_name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new(); body.name = wall_name; body.position = pos
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size; shape.shape = box
	body.add_child(shape); level.add_child(body)

func wolves() -> Array: return level.get_node("GreyfangPack").get_children()

func states() -> Array: return wolves().map(func(w): return w.State.keys()[w.state])
# For failure messages: where each wolf is and how far from the player. (These checks
# used to fail about 1 run in 8 under load: a wolf queued behind the one biting and
# never got round it. Fixed in wolf.gd by sidestepping off a blocking packmate.)
func detail() -> Array:
	var player = level.get_node("Player")
	return wolves().map(func(w): return "%s %s at (%.1f, %.1f), %.1f m" % [w.name, w.State.keys()[w.state],
			w.global_position.x, w.global_position.z, w.global_position.distance_to(player.global_position)])

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		mode = arg("nav_kill")
		level = load("res://levels/test_level.tscn").instantiate()
		# U around the pack's approach: back wall at z=-22 (x 0..16), arms going south to z=-14
		wall("UBack", Vector3(8, 1.5, -22), Vector3(16, 3, 0.5))
		wall("ULeft", Vector3(0, 1.5, -18), Vector3(0.5, 3, 8))
		wall("URight", Vector3(16, 1.5, -18), Vector3(0.5, 3, 8))
		if mode == "direct":
			level.get_node("NavigationRegion3D").free()
		root.add_child(level); current_scene = level
		var p = level.get_node("Player"); p.position = Vector3(8, 0, -17); p.stats.max_health = 9999; p.stats.health = 9999
		for w in wolves(): w.aggro_range = 20.0   # all three join in
		return false
	f += 1
	var p = level.get_node("Player")
	if f == 2 and mode != "direct":
		var reg = level.get_node_or_null("NavigationRegion3D")
		ok(reg != null and reg.navigation_mesh.get_polygon_count() > 50, "navmesh baked", reg.navigation_mesh.get_polygon_count() if reg else 0)
	if f == 30:
		ok(wolves().all(func(w): return w.state == w.State.CHASE), "all three wolves give chase", states())
	if f == 600:
		var attacking := wolves().filter(func(w): return w.state == w.State.ATTACK).size()
		ok(attacking >= 2, "at least two wolves got around the wall and attack within 10 s", detail())
		between(9999 - p.stats.health, 10.0, 120.0, "player health lost in 10 s")
	if f == 610 and mode == "nav_kill":
		for w in wolves():
			if w.state == w.State.ATTACK:
				w.stats.take_damage(999); killed = w.name; break
	if f >= 720:
		if mode == "nav_kill":
			var alive := wolves().filter(func(w): return w.state != w.State.DEAD)
			ok(alive.size() == 2, "one wolf killed (%s), two left" % killed, states())
			ok(alive.all(func(w): return w.state == w.State.ATTACK), "both remaining wolves attack 2 s later", detail())
			ok(alive.all(func(w): return Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length() < 2.0), "remaining wolves are next to the player")
		return done()
	return false
