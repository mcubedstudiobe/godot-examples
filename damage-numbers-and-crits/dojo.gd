extends Node3D
## A plush in a headband whacks another plush with a rubber chicken, and every hit shows its damage.
## What the numbers do is popups.gd; this script is the fight: who swings, when it lands, how much it
## costs, and how the victim reacts. A stage is how much of the popups' treatment is on: the same
## hits do the same damage at every stage.

enum Kind { LIGHT, HIT, HEAVY, CRIT, FLURRY }

const Effects := preload("res://effects.gd")
const Props := preload("res://props.gd")
const DIZZY_STAR := preload("res://dizzy_star.gdshader")
const SQUEAKS := [
	preload("res://sounds/rubber_chicken_squeak_a.wav"),
	preload("res://sounds/rubber_chicken_squeak_b.wav"),
	preload("res://sounds/rubber_chicken_squeak_c.wav"),
]
const CRIT_SQUEAK := preload("res://sounds/rubber_chicken_crit.wav")
const WHOOSH := preload("res://sounds/whoosh.wav")
const THUMP := preload("res://sounds/soft_thump.wav")
const STAGE_LABELS := [
	"Plain labels", "Size from the damage", "Burst in, drift and fade",
	"Scatter sideways", "Crits shout",
]

## What each hit costs. A crit is the hardest hit of all.
const DAMAGE := {Kind.LIGHT: 5, Kind.HIT: 14, Kind.HEAVY: 42, Kind.CRIT: 87}
## A flurry is ten quick whacks, each with its own damage.
const FLURRY_DAMAGE: Array[int] = [6, 9, 7, 12, 8, 11, 6, 10, 13, 7]
const MAX_HP := 200
## Space cycles through these.
const CYCLE: Array[Kind] = [Kind.HIT, Kind.HEAVY, Kind.LIGHT]
## The victim is dazed once it is below this fraction of its health, and for a while after a flurry.
const DAZE_BELOW := 0.4
const FLURRY_DAZE := 0.85
const FLURRY_DAZE_SECONDS := 2.4
## How the fighter's swing reads to the victim: it flinches over this long before the contact.
const FLINCH_SECONDS := 0.2
## The victim's stagger: how hard a hit leans it, how far it is shoved, and how long the shove takes
## to come back. A crit is shoved and staggered harder.
const STAGGER := 0.8
const SHOVE_METRES := 0.1
const CRIT_SHOVE_METRES := 0.2
const SHOVE_SECONDS := 0.18
## The camera tremor of a crit (from the crit stage on): how far it shakes, how fast, for how long.
const TREMOR_METRES := 0.05
const TREMOR_HZ := 46.0
const TREMOR_SECONDS := 0.4
## Where a number appears: this far above the head and this far towards the fighter, so the biggest
## ones stay in frame.
const POPUP_LIFT := 0.55
const POPUP_TOWARDS_FIGHTER := 0.3
## A crit number is the biggest, so it slides further towards the fighter to stay in frame.
const CRIT_POPUP_TOWARDS_FIGHTER := 0.55
## The sounds.
const SQUEAK_DB := -3.0
const CRIT_SQUEAK_DB := 1.5
const THUMP_DB := -4.0
const WHOOSH_DB := -9.0
## How much each plush turns towards the camera, in degrees.
const TURN_TO_CAMERA := 22.0
## The victim turns further, so it shows its face while the fighter stands behind it.
const VICTIM_TURN_TO_CAMERA := 50.0

@export var stage: DamagePopups.Layer = DamagePopups.Layer.CRIT
@export var look_at_point := Vector3(0.0, 1.0, 0.0)

@onready var camera: Camera3D = $Camera3D
@onready var fighter: Plush = $Fighter
@onready var victim: Plush = $Victim
@onready var popups: DamagePopups = $Popups
@onready var effects: Node3D = $Effects
@onready var guide: CanvasLayer = $Guide
@onready var stage_label: Label = $Guide/Stage
@onready var victim_rest: Vector3 = victim.position

var hp := MAX_HP
var hits := 0
var holding := false
## The attack the fighter is swinging (-1 for none), its damage, whether it is a crit, and whether it has landed.
var attack := -1
var attack_time := 0.0
var attack_damage := 0
var attack_crit := false
var landed := false
var whooshed := false
## Swings waiting their turn: a flurry queues ten.
var queue: Array = []
var flurry_running := false
var daze_boost := 0.0
var cycle_index := 0
var shove_tween: Tween
var tremor_time := 99.0
var puff: PackedScene
var burst: PackedScene
var chicken: RubberChicken
var dizzy: Array[MeshInstance3D] = []
var time := 0.0


func _ready() -> void:
	camera.look_at(look_at_point)
	puff = Effects.make_puff()
	burst = Effects.make_crit_burst()
	# Each plush faces the other, turned a little towards the camera so faces stay in view.
	face(fighter, victim.global_position - fighter.global_position, -TURN_TO_CAMERA)
	face(victim, fighter.global_position - victim.global_position, VICTIM_TURN_TO_CAMERA)
	var to_fighter := (fighter.global_position - victim.global_position).normalized()
	victim.motion.watch_yaw = rad_to_deg(wrapf(atan2(to_fighter.x, to_fighter.z) - victim.rotation.y, -PI, PI))
	dress_fighter()
	_make_dizzy_stars()
	reset_dojo()


## Turn a plush about the vertical to face a direction, then a few degrees more. The model looks along +Z.
func face(plush: Node3D, direction: Vector3, extra_degrees := 0.0) -> void:
	plush.rotation.y = atan2(direction.x, direction.z) + deg_to_rad(extra_degrees)


## The chicken rides a BoneAttachment3D on the fighter's right hand bone, so the arm bones the
## swing turns carry it. The legs sit in the paw and the body hangs off the far end. The headband
## sits on the head bone.
func dress_fighter() -> void:
	var grip := BoneAttachment3D.new()
	grip.bone_name = &"DEF-hand.R"
	fighter.skeleton.add_child(grip)
	chicken = RubberChicken.new()
	chicken.position = Vector3(0.0, 0.1, 0.0)
	grip.add_child(chicken)
	var head := BoneAttachment3D.new()
	head.bone_name = &"DEF-head"
	fighter.skeleton.add_child(head)
	head.add_child(Props.make_headband())


func _make_dizzy_stars() -> void:
	for i in 5:
		var star := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.17, 0.17)
		var material := ShaderMaterial.new()
		material.shader = DIZZY_STAR
		quad.material = material
		star.mesh = quad
		star.visible = false
		add_child(star)
		dizzy.append(star)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key >= KEY_0 and key <= KEY_4:
		stage = (key - KEY_0) as DamagePopups.Layer
		reset_dojo()
	elif key == KEY_SPACE:
		# The cycle moves on only when the swing was accepted, so mashing Space during a swing
		# does not skip a step of normal, heavy, light.
		if strike(CYCLE[cycle_index % CYCLE.size()]):
			cycle_index += 1
	elif key == KEY_C:
		strike(Kind.CRIT)
	elif key == KEY_F:
		strike(Kind.FLURRY)
	elif key == KEY_R:
		reset_dojo()
	elif key == KEY_P:
		hold(not holding)
	elif key == KEY_H:
		guide.visible = not guide.visible


## Pause the game. Both plushes keep breathing, blinking and reacting, and sounds that have
## started play out.
func hold(on: bool) -> void:
	holding = on
	get_tree().paused = on
	fighter.keep_alive(on)
	victim.keep_alive(on)
	for node: Node in effects.get_children():
		if node is AudioStreamPlayer:
			node.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT


# ---------- the fight ----------

func busy() -> bool:
	return attack >= 0 or not queue.is_empty()


## Swing for one hit, or queue a flurry. A strike while the fighter is busy is ignored, and once
## the victim is down the next one stands it back up. Returns true only when a swing was queued.
func strike(kind: Kind) -> bool:
	if hp <= 0:
		reset_dojo()
		return false
	if busy():
		return false
	match kind:
		Kind.LIGHT:
			queue.append([PlushMotion.Attack.LIGHT, DAMAGE[Kind.LIGHT], false])
		Kind.HIT:
			queue.append([PlushMotion.Attack.HIT, DAMAGE[Kind.HIT], false])
		Kind.HEAVY:
			queue.append([PlushMotion.Attack.HEAVY, DAMAGE[Kind.HEAVY], false])
		Kind.CRIT:
			queue.append([PlushMotion.Attack.CRIT, DAMAGE[Kind.CRIT], true])
		Kind.FLURRY:
			flurry_running = true
			for i in FLURRY_DAMAGE.size():
				var jab := PlushMotion.Attack.JAB_LEFT if i % 2 == 0 else PlushMotion.Attack.JAB_RIGHT
				queue.append([jab, FLURRY_DAMAGE[i], false])
	return true


func _process(delta: float) -> void:
	time += delta
	if attack < 0 and not queue.is_empty():
		var next: Array = queue.pop_front()
		attack = next[0]
		attack_damage = next[1]
		attack_crit = next[2]
		attack_time = 0.0
		landed = false
		whooshed = false
	elif attack < 0 and flurry_running:
		flurry_running = false
		daze_boost = FLURRY_DAZE_SECONDS
	# The victim flinches while the chicken winds up, and lets go the moment it lands.
	var winding := attack >= 0 and not landed and hp > 0
	victim.motion.threat = clampf(attack_time / FLINCH_SECONDS, 0.0, 1.0) if winding else 0.0
	_update_daze(delta)
	_update_tremor(delta)
	_update_dizzy()
	if attack < 0:
		return
	attack_time += delta
	fighter.motion.attack = attack
	fighter.motion.attack_time = attack_time
	var contact := PlushMotion.contact_time(attack)
	if not whooshed and attack_time >= contact - 0.16:
		whooshed = true
		var whoosh := play(WHOOSH, WHOOSH_DB + (0.0 if attack_damage >= 14 else -3.0))
		whoosh.pitch_scale = 1.0 + 0.25 * float(attack_crit) - 0.12 * float(attack_damage < 14)
	if not landed and attack_time >= contact:
		landed = true
		resolve_hit(attack_damage, attack_crit)
	if attack_time >= PlushMotion.duration(attack):
		attack = -1
		fighter.motion.attack = -1


## The hit lands: the cost, the popup, the sound, the victim's reaction.
func resolve_hit(damage: int, crit: bool) -> void:
	hits += 1
	hp -= damage
	var away := victim.global_position - fighter.global_position
	away.y = 0.0
	var push := away.normalized()
	# Where the chicken lands: the victim's near shoulder.
	var point := victim.global_position + Vector3(0.0, 1.0, 0.0) - push * 0.3
	# The damage number: above the victim's head, on the camera's side so nothing hides it.
	var side := camera.global_basis.x
	side.y = 0.0
	var pull := CRIT_POPUP_TOWARDS_FIGHTER if crit else POPUP_TOWARDS_FIGHTER
	popups.spawn(victim.head_point() + Vector3(0.0, POPUP_LIFT, 0.0) - push * pull, damage, crit, side)
	if crit and popups.is_crit_layer():
		play(CRIT_SQUEAK, CRIT_SQUEAK_DB)
		tremor_time = 0.0
		burst_at(point + push * 0.15, burst)
	else:
		var squeak := play(SQUEAKS[(hits - 1) % SQUEAKS.size()], SQUEAK_DB)
		squeak.pitch_scale = [1.0, 1.08, 0.94][(hits - 1) % 3]
	play(THUMP, THUMP_DB + (3.0 if crit else 0.0))
	burst_at(point, puff)
	react(push, damage, crit)
	if hp <= 0:
		knock_out()


## The victim's reaction: shoved, then back in its guard, staggering by how hard it was hit.
func react(push: Vector3, damage: int, crit: bool) -> void:
	if shove_tween != null:
		shove_tween.kill()
	var weight := clampf(float(damage) / DAMAGE[Kind.HEAVY], 0.3, 1.0)
	var shove := (CRIT_SHOVE_METRES if crit else SHOVE_METRES) * (0.5 + 0.5 * weight)
	victim.position = victim_rest + push * shove
	shove_tween = create_tween()
	shove_tween.tween_property(victim, "position", victim_rest, SHOVE_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hp > 0:
		victim.motion.hit(STAGGER * (0.5 + 0.7 * weight), push.dot(victim.global_basis.x), crit)


## Out cold: it sits down with X's for eyes.
func knock_out() -> void:
	victim.motion.ko_goal = 1.0
	victim.motion.hit(0.9, 1.0, true)
	get_tree().create_timer(0.3, false).timeout.connect(func():
		if hp <= 0:
			victim.set_dead(true))


func _update_daze(delta: float) -> void:
	daze_boost = maxf(daze_boost - delta, 0.0)
	var low := clampf(1.0 - float(maxi(hp, 0)) / MAX_HP / DAZE_BELOW, 0.0, 1.0)
	var after_flurry := FLURRY_DAZE * clampf(daze_boost / FLURRY_DAZE_SECONDS * 1.6, 0.0, 1.0)
	victim.motion.daze = maxf(low, after_flurry)


func _update_tremor(delta: float) -> void:
	tremor_time += delta
	if tremor_time > TREMOR_SECONDS:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	var left := 1.0 - tremor_time / TREMOR_SECONDS
	camera.h_offset = sin(tremor_time * TREMOR_HZ) * TREMOR_METRES * left
	camera.v_offset = sin(tremor_time * TREMOR_HZ * 1.31 + 1.0) * TREMOR_METRES * left * 0.7


## A ring of little stars circles a dazed or knocked-out head.
func _update_dizzy() -> void:
	var showing := victim.motion.daze > 0.5 or victim.motion.ko > 0.3
	var centre := victim.head_point() + Vector3(0.0, 0.5, 0.0)
	for i in dizzy.size():
		var star := dizzy[i]
		star.visible = showing
		var angle := time * 3.4 + TAU * i / dizzy.size()
		star.global_position = centre + Vector3(cos(angle) * 0.42, sin(angle * 2.0) * 0.04, sin(angle) * 0.2)


func reset_dojo() -> void:
	var was_down := hp <= 0
	if shove_tween != null:
		shove_tween.kill()
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	tremor_time = 99.0
	attack = -1
	queue.clear()
	flurry_running = false
	daze_boost = 0.0
	fighter.motion.attack = -1
	victim.position = victim_rest
	victim.set_dead(false)
	victim.motion.calm()
	popups.layer = stage
	popups.reset()
	for effect in effects.get_children():
		effect.queue_free()
	hp = MAX_HP
	hits = 0
	stage_label.text = "%d · %s" % [stage, STAGE_LABELS[stage]]
	if was_down:
		victim.motion.hit(0.4, -1.0)


func burst_at(point: Vector3, scene: PackedScene) -> void:
	var particles := scene.instantiate() as GPUParticles3D
	effects.add_child(particles)
	particles.global_position = point
	var all: Array[GPUParticles3D] = [particles]
	for child in particles.get_children():
		all.append(child)
	for part in all:
		part.seed = 100 + hits * 7
		part.restart()
	get_tree().create_timer(2.0, false).timeout.connect(particles.queue_free)


func play(stream: AudioStream, volume_db := 0.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	effects.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player
