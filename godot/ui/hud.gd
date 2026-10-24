extends CanvasLayer

# On-screen crosshair, interaction prompt, short messages and the
# Magicka / Health / Stamina bars (left / centre / right, like Skyrim).

@onready var prompt_label: Label = $Prompt
@onready var message_label: Label = $Message
@onready var health_bar: ProgressBar = $Bars/Health
@onready var stamina_bar: ProgressBar = $Bars/Stamina
@onready var magicka_bar: ProgressBar = $Bars/Magicka
@onready var crosshair: Label = $Crosshair
@onready var damage_flash: ColorRect = $DamageFlash
@onready var enemy_bar: ProgressBar = $EnemyBar
@onready var notices: VBoxContainer = $Notices
@onready var spell_label: Label = $Bars/SpellLabel
@onready var effects_row: HBoxContainer = $Bars/Effects
@onready var powers_label: Label = $Bars/PowersLabel

var _message_time_left := 0.0
var _stats: Stats
var _enemy_stats: Stats
var _enemy_bar_time_left := 0.0
var _effects: StatusEffects
var _boss_stats: Stats
var _boss_bar: ProgressBar

var compass: Compass
var corruption_label: Label   # "Corruption: Stained", above the effects row; hidden at none


func _ready() -> void:
	compass = Compass.new()
	add_child(compass)
	get_viewport().size_changed.connect(_fit_bars)
	_fit_bars()
	corruption_label = Label.new()
	corruption_label.label_settings = prompt_label.label_settings.duplicate()
	corruption_label.label_settings.font_size = 16
	corruption_label.label_settings.font_color = Color(0.65, 0.95, 0.75)
	corruption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corruption_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	corruption_label.offset_left = -160.0
	corruption_label.offset_right = 160.0
	corruption_label.offset_top = -90.0
	corruption_label.offset_bottom = -68.0
	$Bars.add_child(corruption_label)
	Corruption.changed.connect(_refresh_corruption)
	_refresh_corruption()


## The bar row is 940 px wide; on a narrow screen (or a big Interface size) shrink it
## to fit rather than cut the ends off.
const BARS_WIDTH := 960.0

func _fit_bars() -> void:
	var bars: Control = $Bars
	var width := get_viewport().get_visible_rect().size.x
	var fit := minf(1.0, (width - 24.0) / BARS_WIDTH)
	bars.pivot_offset = Vector2(bars.size.x / 2.0, bars.size.y)
	bars.scale = Vector2(fit, fit)


func _process(delta: float) -> void:
	_update_powers()
	if _message_time_left > 0.0:
		_message_time_left -= delta
		if _message_time_left <= 0.0:
			message_label.text = ""
	if _enemy_bar_time_left > 0.0:
		_enemy_bar_time_left -= delta
		if is_instance_valid(_enemy_stats):
			enemy_bar.max_value = _enemy_stats.max_health
			enemy_bar.value = _enemy_stats.health
		enemy_bar.visible = _enemy_bar_time_left > 0.0
	if _boss_bar and _boss_bar.visible and is_instance_valid(_boss_stats):
		_boss_bar.value = _boss_stats.health


func _refresh_corruption() -> void:
	var tier_name := Corruption.tier_name()
	corruption_label.text = "Corruption: %s" % tier_name if tier_name != "" else ""


## Connects the bars to a Stats node so they update by themselves.
func track_stats(stats: Stats) -> void:
	_stats = stats
	stats.changed.connect(_refresh_bars)
	_refresh_bars()


func _refresh_bars() -> void:
	health_bar.max_value = _stats.max_health
	health_bar.value = _stats.health
	stamina_bar.max_value = _stats.max_stamina
	stamina_bar.value = _stats.stamina
	magicka_bar.max_value = _stats.max_magicka
	magicka_bar.value = _stats.magicka


func set_prompt(text: String) -> void:
	prompt_label.text = text


func show_message(text: String, seconds: float = 4.0) -> void:
	message_label.text = text
	_message_time_left = seconds


## Red edge flash when the player is hurt.
func flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(damage_flash, "color:a", 0.35, 0.05)
	tween.tween_property(damage_flash, "color:a", 0.0, 0.4)


## Crosshair turns red briefly when a swing connects.
func flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(crosshair, "modulate", Color(1, 0.2, 0.2), 0.03)
	tween.tween_property(crosshair, "modulate", Color.WHITE, 0.25)


var _hint_label: Label
var _hint_tween: Tween
var _hint_queue: Array = []


## A tutorial tip in the lower middle of the screen for a few seconds (Hints).
func show_hint(text: String, seconds: float = 7.0) -> void:
	if _hint_label == null:
		_hint_label = Label.new()
		_hint_label.label_settings = prompt_label.label_settings
		_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_hint_label.offset_left = -380.0
		_hint_label.offset_right = 380.0
		_hint_label.offset_top = -225.0
		_hint_label.offset_bottom = -165.0
		_hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_hint_label.modulate = Color(1, 0.9, 0.6)
		add_child(_hint_label)
	if _hint_tween and _hint_tween.is_running():
		_hint_queue.append(text)   # one at a time: this one shows next
		return
	_hint_label.text = text
	_hint_label.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(seconds)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 1.0)
	_hint_tween.tween_callback(func():
		if not _hint_queue.is_empty():
			show_hint(_hint_queue.pop_front(), seconds))


## The crosshair grows while a heavy attack charges, and turns gold when it's full.
func set_charge(amount: float) -> void:
	crosshair.pivot_offset = crosshair.size / 2.0
	crosshair.scale = Vector2.ONE * (1.0 + amount * 0.8)
	if amount >= 1.0:
		crosshair.modulate = Color(1, 0.8, 0.3)
	elif amount <= 0.0 and crosshair.modulate == Color(1, 0.8, 0.3):
		crosshair.modulate = Color.WHITE


## The Stamina bar blinks when there isn't enough for an attack or dodge.
func flash_tired() -> void:
	var tween := create_tween()
	tween.tween_property(stamina_bar, "modulate", Color(1, 0.3, 0.3), 0.05)
	tween.tween_property(stamina_bar, "modulate", Color.WHITE, 0.3)


## Blue crosshair flash for a block; gold and "Parry!" for a parry.
func flash_block(parried: bool) -> void:
	var tween := create_tween()
	tween.tween_property(crosshair, "modulate", Color(1, 0.85, 0.3) if parried else Color(0.5, 0.7, 1), 0.03)
	tween.tween_property(crosshair, "modulate", Color.WHITE, 0.3)
	if parried:
		var label := Label.new()
		label.text = "Parry!"
		label.label_settings = prompt_label.label_settings
		label.modulate = Color(1, 0.85, 0.3)
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.position = get_viewport().get_visible_rect().size / 2.0 + Vector2(-30, 24)
		add_child(label)
		var fade := label.create_tween()
		fade.tween_interval(0.4)
		fade.tween_property(label, "modulate:a", 0.0, 0.4)
		fade.tween_callback(label.queue_free)


## Shows the health of whatever you just hit, at the top of the screen.
func show_enemy_health(stats: Stats) -> void:
	if stats == _boss_stats:
		return   # the boss has its own bar
	_enemy_stats = stats
	_enemy_bar_time_left = 4.0
	enemy_bar.max_value = stats.max_health
	enemy_bar.value = stats.health
	enemy_bar.visible = true


## Short top-left notice that fades out by itself, e.g. a skill increase.
func notify(text: String) -> void:
	while notices.get_child_count() >= 5:   # keep the newest few
		var oldest := notices.get_child(0)
		notices.remove_child(oldest)
		oldest.queue_free()
	var label := Label.new()
	label.text = text
	label.label_settings = prompt_label.label_settings
	notices.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)


## Free text for the left hand (shield, two-handed weapon, bow), above the Magicka bar.
func set_left_hand(text: String) -> void:
	spell_label.text = text


## What the left hand is doing (a spell, or Block), above the Magicka bar.
## `both_hands`: the right hand is free, so both buttons cast (dual-cast).
func set_spell(spell: SpellData, known_count: int, both_hands: bool = false) -> void:
	var hand := "Block"
	if spell:
		hand = "%s (%s%s)" % [spell.display_name, spell.cast_hint(), ", both hands to dual-cast" if both_hands and spell.can_dual_cast else ""]
	spell_label.text = hand + ("   [%s] switch" % InputHints.label("switch_spell") if known_count > 0 else "")


## The Magicka bar blinks when a spell can't be afforded.
func flash_magicka() -> void:
	var tween := create_tween()
	tween.tween_property(magicka_bar, "modulate", Color(1, 0.3, 0.3), 0.05)
	tween.tween_property(magicka_bar, "modulate", Color.WHITE, 0.3)


## Shows the player's status effects (name, stacks, seconds left) above the bars.
func track_effects(effects: StatusEffects) -> void:
	_effects = effects
	effects.changed.connect(_refresh_effects)
	_refresh_effects()


func _refresh_effects() -> void:
	var entries: Array = _effects.active.values()
	while effects_row.get_child_count() < entries.size():
		var label := Label.new()
		label.label_settings = prompt_label.label_settings.duplicate()
		label.label_settings.font_size = 16
		effects_row.add_child(label)
	for i in effects_row.get_child_count():
		var label: Label = effects_row.get_child(i)
		label.visible = i < entries.size()
		if not label.visible:
			continue
		var entry: Dictionary = entries[i]
		var data: StatusEffectData = entry["data"]
		var text := data.display_name
		if entry["stacks"] > 1:
			text += " x%d" % entry["stacks"]
		if data.duration > 0.0:
			text += "  %ds" % ceili(entry["time_left"])
		label.text = text
		label.label_settings.font_color = Color(1, 0.45, 0.4) if data.is_harmful else Color(0.55, 1, 0.6)


# "Z Battle Fury   X Second Wind 42s"
func _update_powers() -> void:
	var parts := []
	var keys := [InputHints.label("power_race"), InputHints.label("power_background")]
	var ids: Array = Character.powers()
	for i in ids.size():
		var id: String = ids[i]
		if id == "":
			continue
		var text: String = "%s %s" % [keys[i], Character.ability_list[id]["name"]]
		if Character.cooldowns.has(id):
			text += " %ds" % ceili(Character.cooldowns[id])
		parts.append(text)
	powers_label.text = "   ".join(parts)


## A boss's name and a wide health bar at the top of the screen, until hide_boss().
func show_boss(boss_name: String, stats: Stats) -> void:
	if _boss_bar == null:
		_boss_bar = enemy_bar.duplicate()
		_boss_bar.offset_left = -300.0
		_boss_bar.offset_right = 300.0
		_boss_bar.offset_top = 76.0   # under the compass
		_boss_bar.offset_bottom = 90.0
		add_child(_boss_bar)
		var label := Label.new()
		label.name = "BossName"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, -26)
		label.size = Vector2(600, 24)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		_boss_bar.add_child(label)
	_boss_stats = stats
	_boss_bar.get_node("BossName").text = boss_name
	_boss_bar.max_value = stats.max_health
	_boss_bar.value = stats.health
	_boss_bar.visible = true
	enemy_bar.visible = false


func hide_boss() -> void:
	_boss_stats = null
	if _boss_bar:
		_boss_bar.visible = false
