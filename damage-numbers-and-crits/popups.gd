class_name DamagePopups
extends Node3D
## Floating damage numbers: the whole lesson. A pool of billboard Label3D nodes is reused for every
## hit, so no node is made or freed while the fight runs. `layer` says how much of the treatment is
## switched on, and each layer keeps everything below it:
##   PLAIN    the number appears at the head and vanishes. Every hit looks the same.
##   SIZE     the damage sets the size, so a heavy blow towers over a scratch.
##   BURST    it starts oversized, snaps to size, holds, then floats up and fades.
##   SCATTER  each number is nudged a seeded random distance sideways, so a flurry stays readable.
##   CRIT     a crit gets its own colour, a thick outline, a bigger burst and a star behind it.
## The camera tremor and the sharper squeak of a crit belong to dojo.gd, which asks `is_crit_layer()`.

enum Layer { PLAIN, SIZE, BURST, SCATTER, CRIT }

const FONT := preload("res://fonts/LilitaOne-Regular.ttf")
const STAR := preload("res://star.gdshader")

## The pool: more than the numbers a flurry can have alive at once.
const POOL_SIZE := 16
## How big a number is on the glyph grid: font pixels, and metres per pixel. 1.0 scale is about half a metre tall.
const FONT_SIZE := 160
const PIXEL_SIZE := 0.0034

## PLAIN: one size, white, shown for this long, then gone.
const PLAIN_SCALE := 0.8
const PLAIN_SECONDS := 0.9
const PLAIN_COLOUR := Color(1.0, 1.0, 1.0)
const PLAIN_OUTLINE_SIZE := 6

## SIZE: the damage sets the scale. A hit of SMALL_HIT or less gets MIN_SCALE, BIG_HIT or more MAX_SCALE.
const SMALL_HIT := 5
const BIG_HIT := 45
const MIN_SCALE := 0.55
const MAX_SCALE := 1.15

## BURST: start this many times bigger and snap down to size, hold, then drift up and fade.
const BURST_START := 2.6
const BURST_SECONDS := 0.1
const HOLD_SECONDS := 0.28
const DRIFT_METRES := 0.55
const DRIFT_SECONDS := 0.65

## SCATTER: a random distance to either side, in metres. The seed makes every run identical.
const SPREAD_METRES := 0.6
const SPREAD_SEED := 20261128

## CRIT: its own colour, a thick outline, an even bigger burst and bigger type.
const NORMAL_COLOUR := Color(1.0, 0.97, 0.9)
const NORMAL_OUTLINE_COLOUR := Color(0.32, 0.08, 0.05)
const NORMAL_OUTLINE_SIZE := 28
const CRIT_COLOUR := Color(1.0, 0.86, 0.1)
const CRIT_OUTLINE_COLOUR := Color(0.78, 0.04, 0.02)
const CRIT_OUTLINE_SIZE := 80
const CRIT_SCALE := 1.45
const CRIT_BURST_START := 2.2
const CRIT_HOLD_SECONDS := 0.5
## A crit number is the biggest, so it drifts less: it must not float out of the frame while it fades.
const CRIT_DRIFT_METRES := 0.35
const CRIT_STAR_SCALE := 1.6

var layer := Layer.CRIT
var pool: Array[Label3D] = []
var stars: Array[MeshInstance3D] = []
var tweens: Array[Tween] = []
var next := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	for i in POOL_SIZE:
		var label := Label3D.new()
		label.font = FONT
		label.font_size = FONT_SIZE
		label.pixel_size = PIXEL_SIZE
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.shaded = false
		label.double_sided = true
		label.no_depth_test = true
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		label.render_priority = 2
		label.outline_render_priority = 1
		label.visible = false
		add_child(label)
		pool.append(label)
		# Each number carries its own star, which only a crit shows.
		var star := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.62, 0.62)
		var material := ShaderMaterial.new()
		material.shader = STAR
		material.render_priority = 0
		quad.material = material
		star.mesh = quad
		star.visible = false
		label.add_child(star)
		stars.append(star)
		tweens.append(null)
	reset()


## Hide every number and start the random spread over, so the same fight gives the same numbers.
func reset() -> void:
	rng.seed = SPREAD_SEED
	next = 0
	for i in POOL_SIZE:
		if tweens[i] != null:
			tweens[i].kill()
			tweens[i] = null
		pool[i].visible = false


func is_crit_layer() -> bool:
	return layer >= Layer.CRIT


## The label scale for a damage: small hits small, big hits big.
func scale_for(damage: int) -> float:
	return lerpf(MIN_SCALE, MAX_SCALE, clampf(inverse_lerp(SMALL_HIT, BIG_HIT, damage), 0.0, 1.0))


## Show a damage number at `origin`. `side` is the world direction the spread slides along.
func spawn(origin: Vector3, damage: int, crit: bool, side: Vector3) -> void:
	var index := next
	next = (next + 1) % POOL_SIZE
	if tweens[index] != null:
		tweens[index].kill()
	var label := pool[index]
	var star := stars[index]
	var shouts := crit and layer >= Layer.CRIT
	label.text = str(damage)
	label.position = origin
	star.visible = shouts
	if layer < Layer.BURST:
		_plain(label, damage, index)
		return
	var size := scale_for(damage) if layer >= Layer.SIZE else PLAIN_SCALE
	if shouts:
		size *= CRIT_SCALE
	if layer >= Layer.SCATTER:
		label.position += side.normalized() * rng.randf_range(-SPREAD_METRES, SPREAD_METRES)
	label.modulate = CRIT_COLOUR if shouts else NORMAL_COLOUR
	label.outline_modulate = CRIT_OUTLINE_COLOUR if shouts else NORMAL_OUTLINE_COLOUR
	label.outline_size = CRIT_OUTLINE_SIZE if shouts else NORMAL_OUTLINE_SIZE
	label.scale = Vector3.ONE * size * (CRIT_BURST_START if shouts else BURST_START)
	label.visible = true
	var hold := CRIT_HOLD_SECONDS if shouts else HOLD_SECONDS
	var tween := create_tween()
	tweens[index] = tween
	# Snap down to size.
	tween.tween_property(label, "scale", Vector3.ONE * size, BURST_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if shouts:
		(star.mesh.material as ShaderMaterial).set_shader_parameter(&"alpha", 1.0)
		star.scale = Vector3.ONE * CRIT_STAR_SCALE * 0.3
		tween.parallel().tween_property(star, "scale", Vector3.ONE * CRIT_STAR_SCALE, BURST_SECONDS * 1.5) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Hold, then float up and fade out together.
	tween.tween_interval(hold)
	tween.tween_property(label, "position:y", label.position.y + (CRIT_DRIFT_METRES if shouts else DRIFT_METRES), DRIFT_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, DRIFT_SECONDS)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, DRIFT_SECONDS)
	if shouts:
		tween.parallel().tween_method(_fade_star.bind(star), 1.0, 0.0, DRIFT_SECONDS)
	tween.tween_callback(label.hide)


## The bare minimum: one size, no motion, and it simply disappears.
func _plain(label: Label3D, damage: int, index: int) -> void:
	var size := scale_for(damage) if layer >= Layer.SIZE else PLAIN_SCALE
	label.scale = Vector3.ONE * size
	label.modulate = PLAIN_COLOUR
	label.outline_modulate = Color.BLACK
	label.outline_size = PLAIN_OUTLINE_SIZE
	label.visible = true
	var tween := create_tween()
	tweens[index] = tween
	tween.tween_interval(PLAIN_SECONDS)
	tween.tween_callback(label.hide)


func _fade_star(amount: float, star: MeshInstance3D) -> void:
	(star.mesh.material as ShaderMaterial).set_shader_parameter(&"alpha", amount)
