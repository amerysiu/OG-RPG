extends Node

const ZONES := {
	1: {
		"id": 1,
		"key": "village",
		"name": "Phoneme Village",
		"level_min": 1,
		"level_max": 5,
		"task": "Single graphemes, short vowels, continuous consonants",
		"modulate": Color(1.06, 1.0, 0.9),
		"light": Color(1.0, 0.92, 0.7, 0.55),
		"ground_a": Color(0.55, 0.78, 0.42, 1),
		"ground_b": Color(0.46, 0.7, 0.36, 1),
		"path": Color(0.86, 0.74, 0.5, 1),
		"accent": Color(0.98, 0.72, 0.32, 1),
		"fog": Color(1.0, 0.95, 0.78, 0.18),
		"grid": Rect2i(0, 0, 15, 15),
		"spawn": Vector2(7, 11),
	},
	2: {
		"id": 2,
		"key": "woods",
		"name": "Syllable Woods",
		"level_min": 6,
		"level_max": 12,
		"task": "CVC blending and simple digraphs",
		"modulate": Color(0.7, 0.78, 0.92),
		"light": Color(0.45, 0.7, 1.0, 0.4),
		"ground_a": Color(0.18, 0.32, 0.28, 1),
		"ground_b": Color(0.14, 0.26, 0.24, 1),
		"path": Color(0.32, 0.28, 0.22, 1),
		"accent": Color(0.38, 0.72, 0.7, 1),
		"fog": Color(0.35, 0.5, 0.62, 0.28),
		"grid": Rect2i(17, 0, 16, 16),
		"spawn": Vector2(18, 8),
	},
	3: {
		"id": 3,
		"key": "citadel",
		"name": "Orthography Citadel",
		"level_min": 13,
		"level_max": 20,
		"task": "Multi-syllabic decoding, affixes, irregulars",
		"modulate": Color(0.92, 0.82, 1.05),
		"light": Color(0.95, 0.7, 1.0, 0.5),
		"ground_a": Color(0.28, 0.24, 0.38, 1),
		"ground_b": Color(0.22, 0.18, 0.32, 1),
		"path": Color(0.55, 0.46, 0.38, 1),
		"accent": Color(0.92, 0.78, 0.32, 1),
		"fog": Color(0.55, 0.32, 0.72, 0.22),
		"grid": Rect2i(35, 0, 16, 16),
		"spawn": Vector2(36, 8),
	},
}


func data(zone_id: int) -> Dictionary:
	return ZONES.get(zone_id, ZONES[1])


func zone_at_cart(cart: Vector2) -> int:
	for id in [3, 2, 1]:
		var grid: Rect2i = ZONES[id]["grid"]
		if grid.has_point(Vector2i(int(floor(cart.x)), int(floor(cart.y)))):
			return id
	var nearest := 1
	var best := INF
	for id in ZONES.keys():
		var g: Rect2i = ZONES[id]["grid"]
		var c := Vector2(g.position) + Vector2(g.size) * 0.5
		var d := cart.distance_to(c)
		if d < best:
			best = d
			nearest = int(id)
	return nearest


func monster_level_for(zone_id: int, slot: int) -> int:
	var z: Dictionary = data(zone_id)
	var lo: int = int(z["level_min"])
	var hi: int = int(z["level_max"])
	return clampi(lo + slot, lo, hi)
