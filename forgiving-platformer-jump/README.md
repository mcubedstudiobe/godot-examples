# Forgiving platformer jump

A plush runs a ledge course across floating toast and waffles, over a lake of hot cocoa, at a
breakfast table in soft morning light. Beside it runs a pale, see-through ghost plush that is fed
exactly the same inputs, tick by tick, with every cheat switched off. Where the strict ghost
misses by a hair, flails, looks dismayed and plops into the cocoa (X eyes, a marshmallow on its
head), the player, helped by four small cheats, makes the jump. The four cheats are named
constants in one short script, so every number is easy to find and change.

## Run it

Open `project.godot` in **Godot 4.7** (Forward+) and press **F5**. Everything the scene needs is
in this folder: the table, the cocoa and the props are built in code and by small shaders, and the
five sounds are public-domain recordings in [sounds/](sounds/CREDITS.md). The first launch
compiles the shaders, so give it a moment.

| Key | Action |
| --- | --- |
| A / D or the arrows | Run. |
| Space (or W, Up, Z) | Jump. |
| 0–4 | How many cheats the player has (top-row digits), and reset the ledge. |
| N | Next ledge. |
| Enter | Reset and replay the ledge's scripted run, the same one in every playthrough. |
| R | Reset: both plush back at the start, a plush in the cocoa pops back up dazed. |
| P | Pause. The plush keep breathing, blinking and moving their clips. |
| H | Show or hide the guide. |

Start on **0** and walk off the first ledge, pressing jump a moment late, then press **Enter**
and watch both plush fall in. Press **1** and **Enter**: the player's late press still jumps, the ghost
still falls.

## The four cheats

Each stage keeps everything below it. Stage 0 is the strict controller, which is what the ghost
always is.

| Stage | Cheat | What it adds |
| --- | --- | --- |
| 1 | Coyote time | A jump pressed up to a tenth of a second after walking off an edge still counts. |
| 2 | Jump buffer | A jump pressed up to a tenth of a second before landing is remembered and fires the moment you touch down. |
| 3 | Variable height | Letting go of the jump button while still rising halves the upward speed: tap for a hop, hold for a leap. |
| 4 | Fall faster | Gravity doubles on the way down, so the jump feels snappy instead of floaty. |

There are four ledges, each one a set piece that needs exactly one of the cheats: a late jump
off an edge, a drop onto a short platform with the jump pressed early, a hop onto a small island
and a landing that has to be quick enough to jump again. The scripted run of each ledge is a list
of `[tick, event]` pairs in [course.gd](course.gd); the same list drives the player and, through the
same input frames, the ghost.

## How it is built

| Piece | Where to look |
| --- | --- |
| The cheats | [jumper.gd](jumper.gd) is an axis-locked `CharacterBody3D` (it never leaves its lane). `physics_step()` reads an input frame and applies the cheats that are on. Every number is a `const` at the top: `COYOTE_SECONDS`, `BUFFER_SECONDS`, `JUMP_CUT`, `FALL_GRAVITY_MULTIPLIER`, and the run speed, jump speed and gravity they modify. |
| Coyote time | `coyote_left` refills while the body is on the floor and runs down in the air; `can_jump` is true on the floor or while `cheats.coyote` and `coyote_left` is above zero. |
| Jump buffer | `buffer_left` refills on every press and runs down; `wants_jump` is a press this tick or, with `cheats.buffer`, a press still remembered. The jump fires when `wants_jump` and `can_jump` meet. |
| Variable height | On `input.jump_released` while moving up, `velocity.y *= JUMP_CUT`. |
| Fall faster | `gravity *= FALL_GRAVITY_MULTIPLIER` while `velocity.y` is negative. |
| Which cheats are on | [cheats.gd](cheats.gd): four booleans, and `for_stage()` switches them on one by one. |
| One input, two plush | [input_frame.gd](input_frame.gd) holds one tick of input (move, jump pressed, held, released). [table.gd](table.gd) builds it once per physics tick, from the keyboard or the scripted run, and gives the same frame to the player and to the ghost in a lane behind it, a metre to the side so the two never hide each other. The ghost's platforms are a shifted copy of the player's, on another physics layer. |
| The ghost's fate | `_react_to_doom()` works out by plain ballistics whether the plush has a landing ahead: if it does not, it flails when it just walked off an edge, or looks dismayed when it jumped and is going to miss. `_sink()` plops it into the cocoa with X eyes; `_drop_marshmallow()` drops a marshmallow on its head a moment later; a reset pops it back up dazed. |
| Characters | Tibo's [Godot Plush Character](https://github.com/gtibo/Godot-Plush-Character). [plush.gd](plush.gd) builds an `AnimationTree` that blends the model's own `run`, `up`, `fall` and `idle` clips from the body's speed and vertical velocity. [plush_motion.gd](plush_motion.gd) is a `SkeletonModifier3D` that lays the flail, dismay and daze poses over them and keeps breath and blinks going. The model is drawn larger than its collision capsule so it reads at a distance. |
| The cocoa | [cocoa.gdshader](cocoa.gdshader) draws travelling waves, a foam rim and a glossy sheen on a flat disc; the water's reflections come from screen-space reflections, so the plush are reflected in it. [scenery.gd](scenery.gd) builds the lake, the marshmallows, the cloth and the props. |
| Toast and waffles | [slab.gd](slab.gd) builds a rounded slab; [bread.gdshader](bread.gdshader) and [waffle.gdshader](waffle.gdshader) paint a crust, a crumb, a waffle grid and syrup glints with no textures. |
| The ghost's look | [plush_ghost.gdshader](plush_ghost.gdshader) tints the plush pale cyan with a fresnel glow; [ghost_depth.gdshader](ghost_depth.gdshader) is a depth pre-pass so the translucent plush does not show its own back. |
| The camera | An orthographic camera looking side-on, so every arc reads as a profile. [table.gd](table.gd) glides it along with the player. |
| Sound | Five short recordings. A hop, a land, the plop, a chime when a cheat fires and a bop for the ghost's marshmallow. |

Two details that are easy to miss:

- **The ghost is not a replay file.** It runs the same `Jumper` script as the player, fed the same
  `InputFrame` each tick, with `Cheats` all off. Change a constant and both plush change with it.
- **Pausing keeps the plush alive.** `hold()` pauses the tree but sets the plush skeletons to
  always process, so the pause shows a held moment with characters that still breathe and blink.

## Tuning order

1. Get the strict jump right first (stage 0): `RUN_SPEED`, `JUMP_SPEED` and `GRAVITY` decide how
   far a jump reaches. A good platformer is tuned strict and then forgiven.
2. Add coyote time. Start near a tenth of a second; much longer and the player jumps off thin air
   they could plainly see.
3. Add the buffer. The same tenth works; the jump should fire on the touchdown tick, not after it.
4. Add the jump cut. `0.5` makes a tap a hop; closer to `1.0` makes the button feel unresponsive,
   closer to `0.0` makes a tap a stutter.
5. Add the fall multiplier last, and re-test every ledge: the faster fall shortens a jump's reach
   and brings landings forward.

## Credits

- Godot Plush Character by Tibo, MIT licence: [plush/license.md](plush/license.md).
- Sounds: public domain (CC0), with sources and authors in [sounds/CREDITS.md](sounds/CREDITS.md).
- Everything else in this folder, including the table and the props: MIT, see the repository
  [LICENSE](../LICENSE).
