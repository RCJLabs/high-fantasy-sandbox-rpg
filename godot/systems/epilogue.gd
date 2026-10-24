extends Node

# The end of the demo. Autoloaded as "Epilogue". When the "demo_finished" flag
# is set (telling Maren, Brannoc or Mirela what you found at the Hollow Oak,
# main quest 5), a closing card says what's next, on the same card as the
# openings (Openings.show_card).

const FLAG := "demo_finished"
const TITLE := "To be continued"
const TEXT := "The First is dead. Eleven marks remain on a map of Vaelora, and somewhere in the north, at a place called the Pale Gate, someone is waiting for a harvest that isn't coming. Not this time.\n\nThank you for playing the Vaelora demo. You can keep exploring."
const SECONDS := 16.0
## At Hollowing (systems/corruption.gd) the ending knows what you carry.
const TEXT_HOLLOWING := "The First is dead. Eleven marks remain on a map of Vaelora, and somewhere in the north, at a place called the Pale Gate, someone is waiting for a harvest that isn't coming.\n\nThe light you took is still in you. It pulls north too, gently, like a hand on your sleeve.\n\nThank you for playing the Vaelora demo. You can keep exploring."


func _ready() -> void:
	GameState.flag_set.connect(func(flag): if flag == FLAG: show_ending())


func show_ending() -> void:
	Openings.show_card(TITLE, TEXT_HOLLOWING if Corruption.tier() >= 3 else TEXT, SECONDS)
