class_name HealthBar
extends Control
## The bar this whole demo is about. Two real ProgressBars sit in one frame: the front bar is the
## health, and a pale one behind it is the receipt of what the last hit cost. Every number the
## tutorial talks about is a named constant below, one per layer. `layer` switches the layers on
## one by one, and each one keeps everything under it.

## Fired on every heartbeat, once the health is under a quarter. The plush trembles on it.
signal heartbeat

enum Layer { POLITE, RECEIPT, JOLT, COLOUR, WARNING }

const BEAT_SOUND := preload("res://sounds/heartbeat.wav")

## Layer 0, the polite bar: one fill that glides to its new value.
const POLITE_SLIDE_SECONDS := 0.45
## Layer 1, the receipt: the pale bar waits this long, then slides down to meet the front bar.
const RECEIPT_DELAY_SECONDS := 0.5
const RECEIPT_SLIDE_SECONDS := 0.6
## Layer 2, the jolt: a hit knocks the whole bar sideways and blinks it red.
const SHAKE_PIXELS := 26.0
const SHAKE_SECONDS := 0.4
const SHAKE_HZ := 17.0
const BLINK_COLOR := Color(1.0, 0.16, 0.14)
const BLINK_SECONDS := 0.22
const BLINK_COUNT := 2
## Layer 3, the colour: the fill blends from green to amber to red as it empties.
const COLOUR_FULL := Color(0.30, 0.80, 0.27)
const COLOUR_HALF := Color(1.0, 0.72, 0.16)
const COLOUR_EMPTY := Color(0.92, 0.17, 0.15)
## Layer 4, the warning: under a quarter the bar throbs on a heartbeat that speeds up as the
## health falls, from the first rate at a quarter to the second at empty.
const LOW_HP_FRACTION := 0.25
const HEARTBEAT_BPM_AT_LOW := 72.0
const HEARTBEAT_BPM_AT_ZERO := 150.0
const THROB_SCALE := 0.06
const HEARTBEAT_PITCH_RISE := 0.12

const RECEIPT_COLOUR := Color(1.0, 0.93, 0.82)
const TRACK_COLOUR := Color(0.10, 0.11, 0.17)

@export var layer: Layer = Layer.WARNING:
	set(value):
		layer = value
		if is_node_ready():
			_refresh()
## Units from the top of the screen to the bar. The window sizes the rest.
@export var top_margin := 36.0

var max_hp := 100.0
var hp := 100.0
var gradient: Gradient
var shake_time := 99.0
var blink_time := 99.0
var beat_clock := 0.0
## 1 on a heartbeat, falling away: what the throb and the plush read.
var pulse := 0.0
var receipt_tween: Tween
var slide_tween: Tween
var shown_hp := 100.0

var shaker: Control
var frame: Panel
var track: ProgressBar
var receipt: ProgressBar
var fill: ProgressBar
var heart: Control
var label: Label
var fill_style: StyleBoxFlat
var frame_style: StyleBoxFlat
var player: AudioStreamPlayer


func _ready() -> void:
	gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.85])
	gradient.colors = PackedColorArray([COLOUR_EMPTY, COLOUR_EMPTY, COLOUR_HALF, COLOUR_FULL])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	shaker = Control.new()
	shaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shaker)
	frame = Panel.new()
	frame_style = StyleBoxFlat.new()
	frame_style.bg_color = TRACK_COLOUR
	frame_style.set_border_width_all(7)
	frame_style.border_color = Color(1, 1, 1, 0.96)
	frame_style.shadow_color = Color(0.0, 0.0, 0.05, 0.4)
	frame_style.shadow_size = 14
	frame_style.shadow_offset = Vector2(0, 8)
	frame.add_theme_stylebox_override(&"panel", frame_style)
	shaker.add_child(frame)
	track = _bar(Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	receipt = _bar(Color(0, 0, 0, 0), RECEIPT_COLOUR)
	fill = _bar(Color(0, 0, 0, 0), COLOUR_FULL)
	fill_style = fill.get_theme_stylebox(&"fill") as StyleBoxFlat
	heart = Control.new()
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.draw.connect(_draw_heart)
	shaker.add_child(heart)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.05, 0.1, 0.9))
	label.add_theme_constant_override(&"outline_size", 10)
	shaker.add_child(label)
	player = AudioStreamPlayer.new()
	player.stream = BEAT_SOUND
	add_child(player)
	get_viewport().size_changed.connect(_layout)
	_layout()
	reset()


func _bar(background: Color, fill_colour: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = max_hp
	bar.step = 0.01
	bar.value = max_hp
	var back := StyleBoxFlat.new()
	back.bg_color = background
	var front := StyleBoxFlat.new()
	front.bg_color = fill_colour
	bar.add_theme_stylebox_override(&"background", back)
	bar.add_theme_stylebox_override(&"fill", front)
	frame.add_child(bar)
	return bar


## Size and place the bar from the window: wide and chunky at the top of the action.
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var portrait := view.y > view.x
	var width := view.x * (0.86 if portrait else 0.5)
	var height := view.x * (0.084 if portrait else 0.046)
	var radius := int(height * 0.34)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heart_room := height * 1.1
	shaker.size = Vector2(width, height)
	shaker.position = Vector2((view.x - width) * 0.5 + heart_room * 0.5, top_margin)
	shaker.pivot_offset = shaker.size * 0.5
	frame.size = shaker.size
	frame_style.set_corner_radius_all(radius)
	frame_style.set_border_width_all(maxi(int(height * 0.1), 4))
	var inset := frame_style.border_width_left + 2.0
	for bar: ProgressBar in [track, receipt, fill]:
		bar.position = Vector2(inset, inset)
		bar.size = shaker.size - Vector2.ONE * inset * 2.0
		for slot in [&"background", &"fill"]:
			(bar.get_theme_stylebox(slot) as StyleBoxFlat).set_corner_radius_all(maxi(radius - int(inset), 2))
	heart.size = Vector2(heart_room, heart_room)
	heart.position = Vector2(-heart_room * 0.82, (height - heart_room) * 0.5)
	heart.pivot_offset = heart.size * 0.5
	label.size = Vector2(width - height * 0.5, height)
	label.position = Vector2.ZERO
	label.add_theme_font_size_override(&"font_size", int(height * 0.62))


func reset() -> void:
	_kill_tweens()
	hp = max_hp
	shown_hp = max_hp
	fill.value = max_hp
	receipt.value = max_hp
	shake_time = 99.0
	blink_time = 99.0
	beat_clock = 0.0
	pulse = 0.0
	shaker.position.y = top_margin
	_refresh()


func fraction() -> float:
	return hp / max_hp


## A hit. The health is already at its new value; the bar decides how to show it.
func take_hit(new_hp: float) -> void:
	hp = clampf(new_hp, 0.0, max_hp)
	if layer < Layer.RECEIPT:
		# The polite bar: the one fill glides down.
		_kill_tweens()
		slide_tween = create_tween()
		slide_tween.tween_property(fill, "value", hp, POLITE_SLIDE_SECONDS) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		receipt.value = hp
	else:
		# The front bar drops at once; the pale bar waits, then slides down to meet it.
		fill.value = hp
		if receipt_tween != null:
			receipt_tween.kill()
		receipt_tween = create_tween()
		receipt_tween.tween_interval(RECEIPT_DELAY_SECONDS)
		receipt_tween.tween_property(receipt, "value", hp, RECEIPT_SLIDE_SECONDS) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if layer >= Layer.JOLT:
		shake_time = 0.0
		blink_time = 0.0
	_refresh()


## The rate the heart beats at: a gentle one at a quarter, a frantic one at empty.
func heartbeat_bpm() -> float:
	var danger := 1.0 - fraction() / LOW_HP_FRACTION
	return lerpf(HEARTBEAT_BPM_AT_LOW, HEARTBEAT_BPM_AT_ZERO, clampf(danger, 0.0, 1.0))


func is_low() -> bool:
	return layer >= Layer.WARNING and hp > 0.0 and fraction() < LOW_HP_FRACTION


func colour_now() -> Color:
	return gradient.sample(fraction()) if layer >= Layer.COLOUR else COLOUR_FULL


func _refresh() -> void:
	if fill_style == null:
		return
	label.text = str(int(ceil(hp)))
	heart.queue_redraw()


func _kill_tweens() -> void:
	for tween in [receipt_tween, slide_tween]:
		if tween != null:
			tween.kill()


func _process(delta: float) -> void:
	shake_time += delta
	blink_time += delta
	# The jolt: a fast wobble that dies away.
	var shake := Vector2.ZERO
	if shake_time < SHAKE_SECONDS:
		var decay := pow(1.0 - shake_time / SHAKE_SECONDS, 2.0)
		shake = Vector2(sin(shake_time * TAU * SHAKE_HZ), cos(shake_time * TAU * SHAKE_HZ * 1.3) * 0.35) \
				* SHAKE_PIXELS * decay
	# ...and the red blink: the fill and the frame go red together.
	var blink := 0.0
	if blink_time < BLINK_SECONDS * BLINK_COUNT:
		blink = maxf(sin(blink_time * TAU / BLINK_SECONDS - PI * 0.5) * 0.5 + 0.5, 0.0)
		blink = smoothstep(0.0, 1.0, blink)
	# The warning: a heartbeat clock whose rate follows the health.
	var throb := 0.0
	if is_low():
		beat_clock += delta * heartbeat_bpm() / 60.0
		if beat_clock >= 1.0:
			beat_clock -= 1.0
			_beat()
		throb = pulse
	else:
		beat_clock = 0.9
	pulse = maxf(pulse - delta * 5.5, 0.0)
	var base := Vector2((get_viewport().get_visible_rect().size.x - shaker.size.x) * 0.5 + heart.size.x * 0.55, top_margin)
	shaker.position = base + shake
	shaker.scale = Vector2.ONE * (1.0 + THROB_SCALE * throb)
	heart.scale = Vector2.ONE * (1.0 + 0.55 * throb)
	var colour := colour_now().lerp(BLINK_COLOR, blink)
	fill_style.bg_color = colour
	frame_style.border_color = Color(1, 1, 1, 0.96).lerp(BLINK_COLOR, blink * 0.9)
	heart.modulate = Color.WHITE.lerp(Color(1.0, 0.7, 0.7), blink)
	heart.queue_redraw()


func _beat() -> void:
	pulse = 1.0
	player.pitch_scale = 1.0 + HEARTBEAT_PITCH_RISE * clampf(1.0 - fraction() / LOW_HP_FRACTION, 0.0, 1.0)
	player.play()
	heartbeat.emit()


func _draw_heart() -> void:
	var size_ := heart.size.x
	var centre := heart.size * 0.5 + Vector2(0.0, size_ * 0.03)
	var scale_ := size_ * 0.027
	var outline := PackedVector2Array()
	for i in 72:
		var t := TAU * float(i) / 72.0
		outline.append(centre + Vector2(16.0 * pow(sin(t), 3.0),
				-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * scale_)
	var shadow := PackedVector2Array()
	for point in outline:
		shadow.append(point + Vector2(0.0, size_ * 0.05))
	heart.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.05, 0.35))
	heart.draw_colored_polygon(outline, Color(1, 1, 1, 1))
	var inner := PackedVector2Array()
	for point in outline:
		inner.append(centre + (point - centre) * 0.82)
	heart.draw_colored_polygon(inner, Color(0.93, 0.2, 0.3).lerp(Color(1.0, 0.45, 0.4), pulse))
	var gloss := PackedVector2Array()
	for i in 14:
		var a := PI * 1.05 + float(i) / 13.0 * PI * 0.45
		gloss.append(centre + Vector2(-size_ * 0.14, -size_ * 0.12) + Vector2(cos(a), sin(a)) * size_ * 0.12)
	heart.draw_polyline(gloss, Color(1, 1, 1, 0.8), size_ * 0.035, true)
