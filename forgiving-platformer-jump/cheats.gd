class_name Cheats
extends RefCounted
## The four secret cheats a forgiving platformer gives its player. The strict controller has none.

var coyote := false ## jump still works for a moment after walking off a ledge
var buffer := false ## a jump pressed just before landing is remembered
var variable_height := false ## letting go of the button early cuts the jump short
var fall_gravity := false ## gravity is stronger on the way down


## Stage 0 has no cheats; every stage after it adds the next one on top of the last.
static func for_stage(stage: int) -> Cheats:
	var cheats := Cheats.new()
	cheats.coyote = stage >= 1
	cheats.buffer = stage >= 2
	cheats.variable_height = stage >= 3
	cheats.fall_gravity = stage >= 4
	return cheats
