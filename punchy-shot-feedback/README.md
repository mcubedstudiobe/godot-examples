# Punchy shot feedback

A small desert shooting range in Godot 4.7 that adds seven layers of shot feedback
one at a time, from "the health number went down" to a ragdoll knocked over by the
finishing hit. One physics ray resolves each shot, and its hit point anchors the
tracer, the target reaction, the paint and the impact sound.

## Run it

Open `project.godot` in **Godot 4.7** (Forward+) and press **F5**. Everything the
scene needs is in this folder; the effects and sounds are built in code.

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
| 4 | The shooter is pushed back and the camera nudges and settles. |
| 5 | Paint droplets, paint decals on the floor and backstop, and brass casings. |
| 6 | Positional sound: a crack at the muzzle, a whiz along the line, a thud on the target and a ping on the wall. |
| 7 | The finishing hit: hold the struck pose for 55 ms, then knock the ragdoll up and over along the shot. |

Below layer 7 the final hit still drops the target as a ragdoll; it just folds where
it stands instead of being thrown.

## How it is built

| Piece | Where to look |
| --- | --- |
| Shot | `fire()` in [range.gd](range.gd) casts a ray from the `Muzzle` marker on the world (1) and target (2) physics layers and keeps the first hit. |
| Muzzle flash | `Muzzle/Flash` holds three quads drawn by [flash.gdshader](flash.gdshader): no textures, colours above 1 so the environment glow picks them up. Each shot rolls and scales it a little so no two flashes match. |
| Tracer | A unit-depth box stretched from the muzzle to the hit. [tracer.gdshader](tracer.gdshader) burns white at the hit end, and a per-instance `tail` value eats the streak from the muzzle end while it thins over 60 ms. |
| Particles | [demo_assets.gd](demo_assets.gd) builds the sparks, paint and smoke. Sparks and paint use **Align Y** so each streak points along its velocity. |
| Characters | Tibo's [Godot Plush Character](https://github.com/gtibo/Godot-Plush-Character). [plush.gd](plush.gd) poses and tints one; the shooter holds one frame of `idle` with a few arm turns, the target keeps playing `idle`. The model imports at 1.3 m (Root Scale in the import settings), so no physics body is ever scaled. |
| Ragdoll | [target.tscn](target.tscn) adds a `PhysicalBoneSimulator3D` named `Ragdoll` under the plush's `Skeleton3D`, with ten `PhysicalBone3D` bodies (hips, the round head, upper arms, forearms, thighs and shins) on physics layer 4. They collide with the world only, so rays, casings and each other pass through them. |
| Hit reaction | `hit_target()` moves only the `Visual` node. The target's collision shape never moves, so the next shot's hitbox stays put. |

Two ragdoll details that are easy to miss:

- **Keep the ragdoll out of physics while the character stands.** The squash on a hit
  and the idle animation both scale bones, and physics bodies cannot take a
  non-uniform scale. `stand()` sets the simulator's `process_mode` to disabled;
  `go_limp()` clears the bone scales, enables it and starts the simulation.
- **Push every body, not just one.** `go_limp()` gives all the bodies the same
  velocity and spin, so the whole plush leaves the ground together instead of one
  arm being yanked.

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
- The layered-feedback idea comes from a reel by Egor (@vasilev.yegor).
- Everything else in this folder: MIT, see the repository [LICENSE](../LICENSE).
