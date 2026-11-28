# Health bar that hurts

A plush hides behind a pillow fort in a sunny backyard while a tennis-ball pitching machine lobs
balls at it. At the top of the screen is the health bar: two real `ProgressBar` nodes, one on top
of the other. Every bonk costs the same damage. What changes, stage by stage, is how much the bar
makes you feel it: five small layers, each one a few lines, all of them named constants in
[health_bar.gd](health_bar.gd).

## Run it

Open `project.godot` in **Godot 4.7** (Forward+) and press **F5**. Everything the scene needs is
in this folder: the yard, the fort, the machine and the grass are built in code and by small
shaders, and the sounds are public-domain recordings in [sounds/](sounds/CREDITS.md). The first
launch compiles the shaders, so give it a moment. The machine fires on its own; the keys let you
take over.

| Key | Action |
| --- | --- |
| Space | A quick shot at the plush's head. |
| L | A slow lob that lands on the cushions (the plush peeks out again). |
| 0-4 | Pick the stage (top-row digits) and reset the plush. |
| R | Reset: the plush pops back up dazed after a knockout. |
| A | Switch the machine's own firing on or off. |
| P | Pause. The plush keeps breathing, blinking and moving. |
| H | Show or hide the guide. |

## The five layers

Each stage keeps everything below it. Stage 0 is a bar that politely slides down.

| Stage | Layer | What it adds |
| --- | --- | --- |
| 0 | Polite | The fill slides down over `POLITE_SLIDE_SECONDS`. You never see how big the hit was. |
| 1 | Receipt | The front drops at once; a pale bar behind it waits `RECEIPT_DELAY_SECONDS`, then slides down over `RECEIPT_SLIDE_SECONDS`. The gap is the damage. |
| 2 | Jolt | The bar shakes (`SHAKE_PIXELS`, `SHAKE_SECONDS`, `SHAKE_HZ`) and blinks red (`BLINK_COUNT` times, `BLINK_SECONDS` each). |
| 3 | Colour | The fill colour comes from a `Gradient` (`COLOUR_FULL`, `COLOUR_HALF`, `COLOUR_EMPTY`), so the bar reads green, amber, red before you read the number. |
| 4 | Warning | Under `LOW_HP_FRACTION` the bar throbs and a heartbeat plays; its rate rises from `HEARTBEAT_BPM_AT_LOW` to `HEARTBEAT_BPM_AT_ZERO` as health falls. The plush trembles and sweats in time with it. |

## How it is built

| Piece | Where to look |
| --- | --- |
| The bar | [health_bar.gd](health_bar.gd): `take_hit()` is the whole lesson. Every number is a `const` at the top. `heartbeat_bpm()` maps health to the heartbeat rate and `_beat()` is one beat: a throb, a pitch step and a sound. |
| The yard | [yard.gd](yard.gd) owns health, the machine's shots and the hit test (a sphere around the plush's head). `DAMAGE` and `MAX_HP` live here. |
| The plush | Tibo's Godot Plush Character. [plush_motion.gd](plush_motion.gd) is a `SkeletonModifier3D` that lays peeking, ducking, flinching, rubbing its head, trembling and the knockout over the model's own breathing and blinking. |
| The machine | [machine.gd](machine.gd) builds the toy cannon from rounded boxes; the ball leaves along a ballistic arc, then becomes a `RigidBody3D` that bounces off the plush and rolls round the lawn. |
| The scenery | [scenery.gd](scenery.gd) builds the lawn, the fort and its blanket roof; [soft.gd](soft.gd) makes the cushions with smooth normals so no facets show. |

Pausing keeps the plush alive: `hold()` pauses the tree but sets the plush's skeleton to always
process, so a held moment still breathes and blinks.

## Credits

- Godot Plush Character by Tibo, MIT licence: [plush/license.md](plush/license.md).
- Sounds: public domain (CC0), with sources and authors in [sounds/CREDITS.md](sounds/CREDITS.md).
- Everything else in this folder: MIT, see the repository [LICENSE](../LICENSE).
