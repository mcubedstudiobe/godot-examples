class_name InputFrame
extends RefCounted
## One physics tick of input. The player's controller writes one of these every tick and the ghost
## reads the very same object, so both characters are always fed identical inputs.

var move := 0.0 ## -1 left, 0 none, 1 right
var jump_pressed := false ## the jump button went down this tick
var jump_held := false ## the jump button is down
var jump_released := false ## the jump button went up this tick
