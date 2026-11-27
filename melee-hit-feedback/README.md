# Melee hit feedback

A plush knight swings an oversized sword at a plush training dummy in a castle yard at golden
hour, and a three-hit combo adds one kind of hit feedback at a time: from "the health number
went down" to a finisher that sends a tin bucket spinning and the dummy tumbling with X's for
eyes. Every hit does the same ten damage at every stage. Only what you see, feel and hear
changes. The knight's swing is procedural, so you can retime or re-aim it without an animation
editor, and the dummy dances until its last hit.

## Run it

Open `project.godot` in **Godot 4.7** (Forward+) and press **F5**. Everything the scene needs is
in this folder: the yard and the effects are built in code, and the four sounds are public-domain
recordings in [sounds/](sounds/CREDITS.md). The first launch compiles the shaders, so give it a
moment.

| Key | Action |
| --- | --- |
| Space | Swing the next attack of the combo. After the dummy falls, it stands it back up. |
| 0–5 | Pick a feedback stage and reset the yard (top-row digits). |
| R | Reset health, pose and debris. |
| H | Show or hide the guide. |

Start on **0** and attack three times. Then press **5** and do the same. Swing on a steady
rhythm of about one attack a second; a swing that is already running ignores a new press.

## The six stages

Each stage keeps everything below it.

| Stage | What it adds |
| --- | --- |
| 0 | A three-hit dummy and a health label. Ten damage a hit. Nothing else. |
| 1 | Time: on contact the game crawls for about sixty milliseconds of real time (hit-stop). |
| 2 | The target: the dummy flashes pure white, squashes and is shoved away from the blade, and the bucket on its head rings. |
| 3 | The room: sparks spray along the swing and the camera gives a small kick. |
| 4 | The ear: a whoosh, a meaty crunch on each hit, a clang from the bucket and a thud when the dummy lands. The crunch steps up a notch in pitch with every hit of the combo. |
| 5 | The finisher: the third hit doubles the hit-stop, flash, squash, shove, sparks, camera kick and crunch volume, and the bucket flies off. |

At every stage the third hit knocks the bucket off and turns the dummy into a ragdoll with X's
for eyes. Below stage 5 it just falls over more gently. Pressing Space once the dummy is down
brings it back up, squashed flat and then stretching out, dancing again.

## How it is built

| Piece | Where to look |
| --- | --- |
| The combo | `strike()`, `_process()` and `resolve_hit()` in [yard.gd](yard.gd). The knight's attack runs in `_process()`; when its clock reaches the contact time, `resolve_hit()` takes the damage and switches on each layer for the current stage. Every number the layers use is a `const` at the top of the file. |
| Hit-stop | `hit_stop()` sets `Engine.time_scale` to a crawl and waits on `get_tree().create_timer(seconds, true, false, true)`. The two `true`s are `process_always` and `ignore_time_scale`: a timer that counted scaled time would be stretched by the very slowdown it is timing, and one that stopped with the tree would hang forever if the game were paused mid-hit. An `epoch` counter lets a reset cancel a hit-stop already waiting. |
| The swing | [plush_motion.gd](plush_motion.gd) is a `SkeletonModifier3D`. The three attacks are lists of keys (blade angles, lunge, lift, hip twist, easing) in `ATTACKS`. Each frame it aims the sword arm's bones so the blade points where the key says, with the forearm square to the blade. The swing runs on game time, so it crawls during hit-stop and holds when the tree is paused, while the breathing, blinking and dancing carry on. |
| Holding the sword | The plush's arms hang off its head bone. `dress_knight()` in [yard.gd](yard.gd) puts the sword on a `BoneAttachment3D` on the sword hand's bone, and `make_sword()` in [props.gd](props.gd) builds it in that bone's own frame, so the crossguard stays on the paw through every pose. |
| The bucket | [props.gd](props.gd) builds a tin bucket from primitives with a noise normal map. The worn one sits tipped back on the dummy's head bone. On the last hit a `RigidBody3D` copy picks up from the worn bucket's pose and flies off, and its landing clangs. |
| White flash | A `flash` uniform in [plush.gdshader](plush.gdshader) washes the whole plush to pure white. `react()` sets it and a real-time timer clears it. |
| Squash and shove | `react()` scales and moves the dummy's root only, then tweens it back. The collision shape belongs to the stand, so it never moves. |
| Sparks | [demo_assets.gd](demo_assets.gd) builds a one-shot `GPUParticles3D`: streaks that use **Align Y** to point along their velocity, a star flash and a few dust puffs. `burst()` aims it along the swing and gives it a fixed seed, so the same hit always sprays the same way. No turbulence, so a repeat run matches. |
| Camera kick | `kick_camera()` offsets the camera's `h_offset` and `v_offset` along the swing and tweens them back, so the camera node itself never moves. |
| Sound | Four short recordings, loaded with `preload()`. `resolve_hit()` sets the crunch's `pitch_scale` to a semitone step per combo hit, and `play_at()` puts each sound where it happens. |
| Characters | Tibo's [Godot Plush Character](https://github.com/gtibo/Godot-Plush-Character). [plush.gd](plush.gd) holds one pose of its `idle` animation and tints one. The model imports at 1.3 m (Root Scale in the import settings), so no physics body is ever scaled. |
| Eyes | Both eyes sample one square of the plush texture, so [plush.gdshader](plush.gdshader) can redraw it: a lid of body colour for a blink, or a white eye with a black X once the dummy is down. |
| Ragdoll | [dummy.tscn](dummy.tscn) adds a `PhysicalBoneSimulator3D` named `Ragdoll` under the plush's `Skeleton3D`, with ten `PhysicalBone3D` bodies on their own physics layer. `stand()` keeps the simulator off while the dummy dances, because physics bodies cannot take a squash; `go_limp()` turns the dance off, clears the bone scales and hands every body the same push and spin so the whole plush leaves the ground together. |
| The yard | [scenery.gd](scenery.gd) builds the walls, towers, fence, hay, banners and props from primitives, with small procedural shaders ([sky.gdshader](sky.gdshader), [ground.gdshader](ground.gdshader), [stone.gdshader](stone.gdshader), [hay.gdshader](hay.gdshader), [banner.gdshader](banner.gdshader)). [yard.tscn](yard.tscn) holds the lights, fog and camera. |

Two details that are easy to miss:

- **The dummy lands facing the camera.** `go_limp()` spins it around the way it faces, so it
  tips onto its side with its face, and its X eyes, towards the viewer. The dummy itself stands
  turned half towards the knight and half towards the camera for the same reason.
- **A reset cancels what is in flight.** `reset_yard()` bumps `epoch`, kills the tweens, puts
  `Engine.time_scale` back to 1 and frees the effects, so pressing a number key in the middle of a
  hit never leaves the game crawling.

## Tuning order

1. Make the unadorned hit readable first: stage 0 should still tell you where the blade met
   the bucket. Change the contact keys in `ATTACKS` until it does.
2. Set the hit-stop length and scale. Sixty milliseconds is about four frames at 60 fps;
   longer starts to read as lag.
3. Tune the flash, squash and shove together, so the dummy looks struck instead of nudged.
4. Add the room: spark count and camera kick, with the kick small enough that the hit point
   stays put on screen.
5. Balance the ear on its own: the crunch leads, the clang sits under it, and the pitch step
   should be audible by the third hit without sounding like a different sound.
6. Compare stage 4 with stage 5. The finisher should feel like the same hit, only more of it.

## Credits

- Godot Plush Character by Tibo, MIT licence: [plush/license.md](plush/license.md).
- Sounds: public domain (CC0), with sources and authors in [sounds/CREDITS.md](sounds/CREDITS.md).
- Everything else in this folder, including the yard and the props: MIT, see the repository
  [LICENSE](../LICENSE).
