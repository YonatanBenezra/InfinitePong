extends Object
class_name Arena
## Authoritative arena dimensions. Every chunk is authored against this
## frame — center on (0, 0), walls at ±HALF_WIDTH, ConnectTop at the
## top, ConnectBottom at the bottom.
##
## If the arena ever changes size, update HERE and every chunk + the
## camera + the wall snap stay coherent.
##
## Coordinate convention (designer-facing):
##   x = 0       → CENTER of the arena
##   x = -HALF_WIDTH (= -320)  → just past the LEFT edge
##   x = +HALF_WIDTH (= +320)  → just past the RIGHT edge
##   y = 0       → TOP of the chunk (where ConnectTop sits)
##   y = chunk_height (positive) → BOTTOM (where ConnectBottom sits)
##
## See docs/chunks_guide.md for a diagram and a step-by-step.

## Total playable width in pixels.
const WIDTH := 640.0
## Half the playable width — distance from the centerline to either edge.
const HALF_WIDTH := WIDTH * 0.5  # = 320.0
## X position of the centerline. With the (0,0)-centered convention this
## is always 0. Kept as a named constant so code that references "the
## center" reads as Arena.CENTER_X instead of a literal 0.
const CENTER_X := 0.0

## Canonical position for the *body* (the center) of a left edge wall.
## Matches the runtime-normalized position so editor and game agree.
## Inner face sits at LEFT_WALL_INNER_X = LEFT_WALL_X + EDGE_WALL_WIDTH/2 = -260.
const LEFT_WALL_X := -300.0
const RIGHT_WALL_X := 300.0

## Canonical edge-wall thickness used by chunk_generator's wall snap.
## Authored chunk walls may vary slightly; the generator forces them to
## this width and to the canonical inner face so chunk seams stay flush.
const EDGE_WALL_WIDTH := 80.0
## Inner face of the left edge wall after the generator's snap.
const LEFT_WALL_INNER_X := -HALF_WIDTH + 60.0   # = -260.0
## Inner face of the right edge wall after the generator's snap.
const RIGHT_WALL_INNER_X := HALF_WIDTH - 60.0   # = 260.0

## A wall whose authored x is more negative than this is treated by the
## generator as an "edge" wall and gets snapped. Inward walls (e.g. the
## gauntlet's narrow walls at x ≈ ±180) stay untouched.
const EDGE_WALL_LEFT_THRESHOLD := -HALF_WIDTH + 90.0   # = -230.0
const EDGE_WALL_RIGHT_THRESHOLD := HALF_WIDTH - 90.0   # = 230.0
