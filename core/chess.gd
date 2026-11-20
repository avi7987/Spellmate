class_name Chess
extends RefCounted
## Shared constants: the two kingdoms and the kinds of map squares.
## (The class keeps the name "Chess" - the game was born from chess.)

enum Terrain { PLAIN, FOREST, HILL, WATER, BRIDGE, MINE, CASTLE, WALL, SPECIAL, SHRINE }

const WHITE := 0   ## the Sun kingdom (bottom of the map)
const BLACK := 1   ## the Void kingdom (top)

## Default map size for code that has no map yet.
const W := 15
const H := 21
