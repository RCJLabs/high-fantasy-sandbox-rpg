extends StaticBody3D

# The roadside shrine (side quest "Silent Shrine"). Its prayers stopped working.
# Until it's rekindled, using it (E) opens res://dialogue/shrine.json: pray (nothing
# answers), read the inscription, offer Wisp Essence ("shrine_rekindled").
# Rekindled, the candle burns bright, and praying:
#   - after dark, the first time: something answers ("shrine_answered");
#   - after dark, if you're corrupted: a vigil until dawn that cleanses one tier
#     (systems/corruption.gd);
#   - otherwise heals you fully and blesses you, once a day; but not from
#     Stained up: it won't bless what you carry.

const DIALOGUE := "res://dialogue/shrine.json"

@onready var candle_light: OmniLight3D = $CandleLight

var prompt: String:
	get: return "Keep a vigil until dawn" if _vigil_ready() else "Pray at the shrine"
var _base_energy := 0.5


func _ready() -> void:
	_base_energy = candle_light.light_energy
	if GameState.has_flag("shrine_rekindled"):
		_kindle(false)
	GameState.flag_set.connect(func(flag): if flag == "shrine_rekindled": _kindle(true))


func interact(player: Node) -> void:
	if not GameState.has_flag("shrine_rekindled"):
		DialogueManager.start(DIALOGUE, "Roadside shrine")
		return
	if WorldClock.is_night() and not GameState.has_flag("shrine_answered"):
		GameState.set_flag("shrine_answered")
		player.show_message("You say the old words in the dark, and something answers. Not a voice: a pull, faint and patient, from somewhere above and to the north, the way the tide pulls at a boat. Then the candle steadies, and you're alone again.")
		return
	if _vigil_ready():
		_keep_vigil(player)
		return
	if Corruption.tier() >= 2:
		player.show_message("The candle gutters as you kneel. Whatever answers here won't bless what you carry. (Keep a vigil here at night to cleanse it.)")
		return
	var today := "shrine_blessed_day_%d" % WorldClock.day
	if GameState.has_flag(today):
		player.show_message("The candle burns steady. You've had today's blessing.")
		return
	GameState.set_flag(today)
	player.stats.refill()
	player.effects.apply("blessing")
	player.show_message("Warmth runs through you, and every ache eases. The shrine remembers how.")


func _vigil_ready() -> bool:
	return GameState.has_flag("shrine_rekindled") and GameState.has_flag("shrine_answered") \
			and WorldClock.is_night() and Corruption.tier() > 0


# Kneel until dawn: the night passes, and one tier of corruption with it.
func _keep_vigil(player: Node) -> void:
	var hours := WorldClock.hours_until(6.0)
	WorldClock.advance(hours)
	Survival.tick(hours, false)
	var before := Corruption.tier_name()
	Corruption.cleanse_tier()
	GameState.set_flag("kept_vigil")
	var after := Corruption.tier_name()
	player.show_message("You kneel until dawn. Some time before first light, the cold behind your eyes thins and goes out like a candle. (%s → %s)" % [before, after if after != "" else "clean"])


func _kindle(animate: bool) -> void:
	candle_light.light_color = Color(1, 0.85, 0.6)
	# The candle flickers (flicker_light.gd), so turn up what it flickers around.
	if animate:
		create_tween().tween_method(candle_light.set_base_energy, _base_energy, _base_energy * 4.0, 1.5)
	else:
		candle_light.set_base_energy(_base_energy * 4.0)
