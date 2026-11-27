class_name Jumper
extends CharacterBody3D
## A side-on runner on an axis-locked CharacterBody3D. The player and the strict ghost are the same
## script: the only difference is which cheats are switched on. Every number a cheat uses is a
## constant here.

const RUN_SPEED := 4.5
const RUN_ACCEL := 40.0
const AIR_ACCEL := 22.0
const JUMP_SPEED := 8.5
const GRAVITY := 22.0

## Cheat 1, coyote time: the jump stays alive for a tenth of a second after the ledge.
const COYOTE_SECONDS := 0.1
## Cheat 2, jump buffer: a press this long before landing is remembered.
const BUFFER_SECONDS := 0.1
## Cheat 3, variable height: letting go of the button while rising keeps this share of the speed.
const JUMP_CUT := 0.5
## Cheat 4, fall faster than you rise.
const FALL_GRAVITY_MULTIPLIER := 2.0

var cheats := Cheats.new()
var coyote_left := 0.0
var buffer_left := 0.0
var jumps := 0
var airborne_ticks := 0
## How the last jump started: "jump", "coyote" (after leaving the ledge) or "buffer" (pressed earlier).
var jump_kind := ""


## Back to a standing start at a point, with nothing remembered.
func respawn(at: Vector3) -> void:
	position = at
	velocity = Vector3.ZERO
	coyote_left = 0.0
	buffer_left = 0.0
	jumps = 0
	airborne_ticks = 0


## One physics tick: read the input frame, apply the cheats that are on, and move.
func physics_step(input: InputFrame, delta: float) -> void:
	if is_on_floor():
		coyote_left = COYOTE_SECONDS
		airborne_ticks = 0
	else:
		coyote_left = maxf(coyote_left - delta, 0.0)
		airborne_ticks += 1
	if input.jump_pressed:
		buffer_left = BUFFER_SECONDS
	else:
		buffer_left = maxf(buffer_left - delta, 0.0)

	var coyote := cheats.coyote and coyote_left > 0.0
	var can_jump := is_on_floor() or coyote
	var buffered := cheats.buffer and buffer_left > 0.0
	var wants_jump := input.jump_pressed or buffered
	if wants_jump and can_jump:
		jump_kind = "coyote" if not is_on_floor() else ("jump" if input.jump_pressed else "buffer")
		velocity.y = JUMP_SPEED
		coyote_left = 0.0
		buffer_left = 0.0
		jumps += 1
	if cheats.variable_height and input.jump_released:
		if velocity.y > 0.0:
			velocity.y *= JUMP_CUT

	var gravity := GRAVITY
	if cheats.fall_gravity and velocity.y < 0.0:
		gravity *= FALL_GRAVITY_MULTIPLIER
	velocity.y -= gravity * delta

	var accel := RUN_ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, input.move * RUN_SPEED, accel * delta)
	velocity.z = 0.0
	move_and_slide()
