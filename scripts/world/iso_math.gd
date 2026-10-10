extends RefCounted
class_name IsoMath

const TILE_W := 72.0
const TILE_H := 36.0
const ORIGIN := Vector2(980, 220)

static func cart_to_iso(gx: float, gy: float) -> Vector2:
	return ORIGIN + Vector2((gx - gy) * TILE_W * 0.5, (gx + gy) * TILE_H * 0.5)


static func iso_to_cart(pos: Vector2) -> Vector2:
	var p := pos - ORIGIN
	var x := (p.x / (TILE_W * 0.5) + p.y / (TILE_H * 0.5)) * 0.5
	var y := (p.y / (TILE_H * 0.5) - p.x / (TILE_W * 0.5)) * 0.5
	return Vector2(x, y)


static func diamond(center: Vector2, w: float = TILE_W, h: float = TILE_H) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -h * 0.5),
		center + Vector2(w * 0.5, 0),
		center + Vector2(0, h * 0.5),
		center + Vector2(-w * 0.5, 0),
	])
