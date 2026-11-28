class_name PauseKeys
extends Node
## Listens for keys while the game is paused. A paused yard stops getting input, so without this
## a second P could never resume it. Only runs while paused, so it never doubles up with the
## yard's own keys.

var yard: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key == KEY_P or key == KEY_R:
		get_viewport().set_input_as_handled()
		yard.hold(false)
		if key == KEY_R:
			yard.reset_yard()
