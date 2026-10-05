extends Node

const INPUTS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E],
	"inventory": [KEY_I],
	"map": [KEY_M],
	"collection": [KEY_C],
	"bank": [KEY_B],
	"kitchen": [KEY_K],
	"chat": [KEY_T],
	"pets": [KEY_P],
	"room": [KEY_R],
	"farm": [KEY_J],
	"staff": [KEY_H],
	"encyclopedia": [KEY_F1],
	"career": [KEY_F2],
	"photo_album": [KEY_F4],
	"coop_panel": [KEY_F6],
	"wardrobe": [KEY_F3],
	"save_game": [KEY_F5],
	"load_game": [KEY_F9],
}

func _ready() -> void:
	for action_name in INPUTS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for keycode in INPUTS[action_name]:
			_add_key_if_missing(action_name, keycode)

func _add_key_if_missing(action_name: String, keycode: Key) -> void:
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)