extends Node

## The 8 zones of the world, in OG order. Content (which stages live where)
## comes from the curriculum; this file only holds the look and layout.
##
##   0 Echo Meadow        A1-A7  sounds only, no letters
##   1 Phoneme Village    B1-B6  letters and their sounds
##   2 Closed-Syllable Woods C1-C8
##   3 Long-Vowel Lake    D1-D3
##   4 Growling Caves     D4-D7
##   5 Syllable Mountains E1-E6
##   6 Morpheme Citadel   F1-F4
##   7 Root Ruins         F5-F6
##
## Zones sit in a row along the cartesian x axis, ZONE_SIZE tiles square with
## a GAP-tile bridge between them. A zone opens when the previous boss falls.

const ZONE_SIZE := 14
const GAP := 3

const LOOKS := {
	0: {"modulate": Color(1.08, 1.04, 0.92), "light": Color(1.0, 0.95, 0.75, 0.55), "ground_a": Color(0.62, 0.82, 0.46), "ground_b": Color(0.56, 0.77, 0.42), "path": Color(0.9, 0.82, 0.58), "accent": Color(1.0, 0.86, 0.4), "fog": Color(1.0, 0.98, 0.85, 0.15)},
	1: {"modulate": Color(1.06, 1.0, 0.9), "light": Color(1.0, 0.92, 0.7, 0.55), "ground_a": Color(0.55, 0.78, 0.42), "ground_b": Color(0.46, 0.7, 0.36), "path": Color(0.86, 0.74, 0.5), "accent": Color(0.98, 0.72, 0.32), "fog": Color(1.0, 0.95, 0.78, 0.18)},
	2: {"modulate": Color(0.78, 0.86, 0.94), "light": Color(0.45, 0.7, 1.0, 0.4), "ground_a": Color(0.2, 0.36, 0.28), "ground_b": Color(0.16, 0.3, 0.25), "path": Color(0.36, 0.3, 0.22), "accent": Color(0.42, 0.8, 0.72), "fog": Color(0.35, 0.5, 0.62, 0.25)},
	3: {"modulate": Color(0.9, 0.98, 1.08), "light": Color(0.6, 0.85, 1.0, 0.5), "ground_a": Color(0.3, 0.55, 0.78), "ground_b": Color(0.26, 0.5, 0.72), "path": Color(0.86, 0.8, 0.6), "accent": Color(0.6, 0.9, 1.0), "fog": Color(0.7, 0.85, 1.0, 0.2)},
	4: {"modulate": Color(0.8, 0.74, 0.7), "light": Color(1.0, 0.6, 0.35, 0.5), "ground_a": Color(0.34, 0.28, 0.26), "ground_b": Color(0.3, 0.24, 0.22), "path": Color(0.48, 0.38, 0.3), "accent": Color(1.0, 0.6, 0.3), "fog": Color(0.5, 0.35, 0.3, 0.25)},
	5: {"modulate": Color(0.95, 0.98, 1.05), "light": Color(0.9, 0.95, 1.0, 0.45), "ground_a": Color(0.6, 0.62, 0.66), "ground_b": Color(0.54, 0.56, 0.6), "path": Color(0.78, 0.74, 0.66), "accent": Color(0.85, 0.92, 1.0), "fog": Color(0.9, 0.95, 1.0, 0.25)},
	6: {"modulate": Color(0.92, 0.82, 1.05), "light": Color(0.95, 0.7, 1.0, 0.5), "ground_a": Color(0.28, 0.24, 0.38), "ground_b": Color(0.22, 0.18, 0.32), "path": Color(0.55, 0.46, 0.38), "accent": Color(0.92, 0.78, 0.32), "fog": Color(0.55, 0.32, 0.72, 0.22)},
	7: {"modulate": Color(1.0, 0.92, 0.8), "light": Color(1.0, 0.8, 0.5, 0.45), "ground_a": Color(0.62, 0.54, 0.4), "ground_b": Color(0.56, 0.48, 0.36), "path": Color(0.78, 0.68, 0.5), "accent": Color(0.95, 0.75, 0.4), "fog": Color(0.85, 0.7, 0.5, 0.2)},
}


func count() -> int:
	return OGCurriculum.zone_count()


func grid(zone_id: int) -> Rect2i:
	return Rect2i(zone_id * (ZONE_SIZE + GAP), 0, ZONE_SIZE, ZONE_SIZE)


func path_row() -> int:
	return int(ZONE_SIZE / 2)


## Everything the world needs to draw and label one zone.
func data(zone_id: int) -> Dictionary:
	var z := OGCurriculum.zone(clampi(zone_id, 0, count() - 1))
	var out: Dictionary = LOOKS.get(int(z["id"]), LOOKS[0]).duplicate()
	out["id"] = int(z["id"])
	out["key"] = String(z["key"])
	out["name"] = String(z["name"])
	out["task"] = String(z["task"])
	out["boss"] = String(z["boss"])
	out["stages"] = z["stages"]
	out["grid"] = grid(int(z["id"]))
	out["spawn"] = Vector2(grid(int(z["id"])).position.x + 1, path_row())
	return out


func zone_at_cart(cart: Vector2) -> int:
	var x := int(floor(cart.x))
	var step := ZONE_SIZE + GAP
	var z := clampi(int(floor(float(x + int(GAP / 2)) / float(step))), 0, count() - 1)
	return z


## World-space bounds of every zone (for camera limits and the backdrop).
func world_bounds() -> Rect2:
	var r := Rect2(IsoMath.cart_to_iso(0, 0), Vector2.ZERO)
	for z in count():
		var g := grid(z)
		for p in [Vector2(g.position.x, g.position.y), Vector2(g.end.x, g.position.y), Vector2(g.position.x, g.end.y), Vector2(g.end.x, g.end.y)]:
			r = r.expand(IsoMath.cart_to_iso(p.x, p.y))
	return r.grow(160)
