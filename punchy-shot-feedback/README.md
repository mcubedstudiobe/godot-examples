# Punchy shot feedback

A small desert shooting range in Godot 4.7 that adds seven layers of shot feedback
one at a time, from "the health number went down" to a ragdoll knocked over by the
finishing hit. The shooter nods along, looks around and taps a foot, the target dances
until it is hit for the last time, and then its eyes turn into X's. One physics ray resolves each shot, and its hit point anchors the
tracer, the target reaction, the paint and the impact sound.

## Run it

Open `project.godot` in **Godot 4.7** (Forward+) and press **F5**. Everything the
scene needs is in this folder: the effects are built in code, and the four sounds are
public-domain recordings in [sounds/](sounds/CREDITS.md).

| Key | Action |
| --- | --- |
| Space | Fire at the target. Once it falls, the next shot reaches the wall. |
| W | Fire beside the target, at the wall. |
| 0–7 | Pick a feedback layer and reset the range (top-row digits). |
| R | Reset health, pose and debris. |
| H | Show or hide the guide. |

Start on **0** and shoot the target three times. Then press **7** and do the same.
Press **W** to compare a wall hit. Set `spread_degrees` to 0 on the root node for
perfectly repeatable tracers.

## The seven layers

Each layer keeps everything below it.

| Layer | What it adds |
| --- | --- |
| 0 | A three-hit target and a health label. Nothing else. |
| 1 | Muzzle flash (a star facing the camera plus crossed side flames), a 40 ms orange light, a smoke puff and barrel kick. |
| 2 | A little spread, a tracer from the muzzle to the hit point, and sparks, impact flash and dust on the wall. |
| 3 | The target flashes white, squashes and is pushed back a little, then recovers. |
| 4 | The shooter is pushed back and flinches, and the camera nudges and settles. |
| 5 | Paint droplets, paint decals on the floor and backstop, and brass casings. |
| 6 | Positional sound: a crack at the muzzle, a whiz along the line, a thud on the target and a ping on the wall. |
| 7 | The finishing hit: hold the struck pose for 55 ms, then knock the ragdoll up and over along the shot. |

At every layer the last hit turns the target into a ragdoll with X's for eyes.

Below layer 7 the final hit still drops the target as a ragdoll; it just tips over where
it stands instead of being thrown.

## How it is built

| Piece | Where to look |
| --- | --- |
| Shot | `fire()` in [range.gd](range.gd) casts a ray from the `Muzzle` marker on the world (1) and target (2) physics layers and keeps the first hit. |
| Muzzle flash | `Muzzle/Flash` holds three quads drawn by [flash.gdshader](flash.gdshader): no textures, colours above 1 so the environment glow picks them up. Each shot rolls and scales it a little so no two flashes match. |
| Tracer | A unit-depth box stretched from the muzzle to the hit. [tracer.gdshader](tracer.gdshader) burns white at the hit end, and a per-instance `tail` value eats the streak from the muzzle end while it thins over 60 ms. |
| Particles | [demo_assets.gd](demo_assets.gd) builds the sparks, paint and smoke. Sparks and paint use **Align Y** so each streak points along its velocity. |
| Characters | Tibo's [Godot Plush Character](https://github.com/gtibo/Godot-Plush-Character). [plush.gd](plush.gd) poses and tints one: a frame of `idle`, plus a few arm turns for the shooter. The model imports at 1.3 m (Root Scale in the import settings), so no physics body is ever scaled. |
| Motion | [plush_motion.gd](plush_motion.gd) is a `SkeletonModifier3D` that adds to the held pose every frame: a small bounce, a tapping foot and a nodding, looking-around head for the shooter (its hands stay on the rifle), a dance for the target, and a blink for both. A shot at layer 4 and up makes the shooter flinch and squint. |
| Eyes | Both eyes sample one square of the plush texture, so [plush.gdshader](plush.gdshader) can redraw it: a lid of body colour for a blink, or a white eye with a black X once the target is down. |
| Ragdoll | [target.tscn](target.tscn) adds a `PhysicalBoneSimulator3D` named `Ragdoll` under the plush's `Skeleton3D`, with ten `PhysicalBone3D` bodies (hips, the round head, upper arms, forearms, thighs and shins) on physics layer 4. They collide with the world only, so rays, casings and each other pass through them. |
| Hit reaction | `hit_target()` moves only the `Visual` node. The target's collision shape never moves, so the next shot's hitbox stays put. |
| Sound | Four short recordings, loaded with `preload()` and wrapped by `vary()` in [demo_assets.gd](demo_assets.gd) so each play has a slightly different pitch. `play_at()` places each one where it happens, at its own volume. |

Three ragdoll details that are easy to miss:

- **Keep the ragdoll out of physics while the character stands.** The squash on a hit
  and the idle pose both scale bones, and physics bodies cannot take a non-uniform
  scale. `stand()` sets the simulator's `process_mode` to disabled; `go_limp()` turns
  the dance off, clears the bone scales, enables the simulator and starts it.
- **Push every body, not just one.** `go_limp()` gives all the bodies the same
  velocity and spin, so the whole plush leaves the ground together instead of one
  arm being yanked.
- **Choose how it lands.** A round body rolls until it finds a side, and a face in the
  dirt hides the X eyes. The spin goes around the way the target faces, so it tips onto
  its side towards the camera, and extra angular damping on the hips and head stops it
  rolling on once it is down.

## Tuning order

1. Check that Space hits the target and W hits the wall. If both take the same path,
   check the physics layers and the muzzle's forward direction (-Z).
2. Size the flash and tracer from the camera distance you will play at.
3. Tune the squash and push with the camera offsets at zero, then add only as much
   camera motion as keeps the hit point readable.
4. Balance the layer 6 cues on their own: the crack leads, the whiz sits lower, and
   the body and the wall must sound different.
5. Compare the final hit at layers 6 and 7, and tune the hold and the knock-back
   together until both the hit and the defeat read at full speed.

## Credits

- Godot Plush Character by Tibo, MIT licence: [plush/license.md](plush/license.md).
- Sounds: public domain (CC0), with sources and authors in [sounds/CREDITS.md](sounds/CREDITS.md).
- The layered-feedback idea comes from a reel by Egor (@vasilev.yegor).
- Everything else in this folder: MIT, see the repository [LICENSE](../LICENSE).
