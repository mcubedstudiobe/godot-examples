# Damage numbers and crits

A plush in a headband whacks another plush with a rubber chicken in a dojo at evening, and every hit
floats its damage over the victim's head. Every hit costs the same at every stage; what changes is how
much the number makes you feel it: five small layers, all of them named constants in
[popups.gd](popups.gd).

## Run it

Open `project.godot` in **Godot 4.7** (Forward+) and press **F5**. Everything the scene needs is in this
folder: the tatami, the shoji wall, the lanterns and the rubber chicken are built in code and by small
shaders, and the sounds are public-domain recordings in [sounds/](sounds/CREDITS.md). The first launch
compiles the shaders, so give it a moment.

| Key | Action |
| --- | --- |
| Space | The next hit: a normal one, a heavy one, a light one, round and round. |
| C | A crit. |
| F | A flurry of ten quick whacks. |
| 0-4 | Pick the layer (top-row digits) and reset the dojo. |
| R | Reset: a knocked-out plush gets back up. |
| P | Pause. Both plushes keep breathing, blinking and moving. |
| H | Show or hide the guide. |

## The five layers

Each layer keeps everything below it. Layer 0 is the plain label every game starts with.

| Layer | What it adds |
| --- | --- |
| 0 Plain | A number at the head for `PLAIN_SECONDS`, then gone. Every hit looks alike. |
| 1 Size | `scale_for()` maps the damage to the label's scale, between `MIN_SCALE` at `SMALL_HIT` and `MAX_SCALE` at `BIG_HIT`. |
| 2 Burst | The number starts `BURST_START` times too big and snaps to size in `BURST_SECONDS`, holds for `HOLD_SECONDS`, then drifts up `DRIFT_METRES` and fades. |
| 3 Scatter | Each number is nudged up to `SPREAD_METRES` to either side from a seeded `RandomNumberGenerator`, so a flurry stays readable and every run is identical. |
| 4 Crit | A crit gets `CRIT_COLOUR`, a thick `CRIT_OUTLINE_SIZE` outline, a bigger `CRIT_BURST_START`, a star behind it, a short `CRIT_DRIFT_METRES` float, a camera tremor and a sharper squeak. |

## How it is built

| Piece | Where to look |
| --- | --- |
| The popups | [popups.gd](popups.gd): a pool of `POOL_SIZE` billboard `Label3D` nodes reused for every hit, so nothing is created or freed during the fight. `spawn()` is the whole lesson. |
| The fight | [dojo.gd](dojo.gd) owns the hits, the damage (`DAMAGE`, `FLURRY_DAMAGE`, `MAX_HP`), the victim's reactions, the camera tremor and the sounds. |
| The plushes | Tibo's Godot Plush Character. [plush_motion.gd](plush_motion.gd) is a `SkeletonModifier3D`: the fighter's procedural swings, and a victim that keeps a guard, flinches on the wind-up, staggers on a hit (harder on a crit), goes dazed, and sits down with X eyes if it is knocked out. |
| The chicken | [chicken.gd](chicken.gd) builds the rubber chicken from primitives on a `BoneAttachment3D` on the fighter's hand bone. Its neck is a spring-driven curve, so it whips behind a swing. |
| The dojo | [scenery.gd](scenery.gd) with the `tatami`, `shoji`, `wood`, `lantern` and `scroll` shaders. |

Pausing keeps the plushes alive: `hold()` pauses the tree but sets both skeletons to always process, so a
held moment still breathes and blinks.

## Credits

- Godot Plush Character by Tibo, MIT licence: [plush/license.md](plush/license.md).
- Lilita One font by Juan Montoreano, SIL Open Font License: [fonts/OFL.txt](fonts/OFL.txt).
- Sounds: public domain (CC0), with sources and authors in [sounds/CREDITS.md](sounds/CREDITS.md).
- Everything else in this folder: MIT, see the repository [LICENSE](../LICENSE).
