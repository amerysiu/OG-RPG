extends RefCounted
class_name IsoMapBuilder

const MonsterScene := preload("res://scenes/iso_monster.tscn")

const MONSTER_NAMES := {
	"speed": ["Swift Sibilant", "Dashling", "Fuse Finch"],
	"audio": ["Echo Caster", "Howl Mage", "Chime Wisp"],
	"forge": ["Rune Titan", "Glyph Guardian", "Orthograph"],
}


static func build(world: Node2D, actors: Node2D) -> void:
	var ground := Node2D.new()
	ground.name = "Ground"
	ground.z_index = -8
	world.add_child(ground)
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	props.z_index = 1
	world.add_child(props)
	for zone_id in [1, 2, 3]:
		_build_zone(ground, props, actors, zone_id)


static func _build_zone(ground: Node2D, props: Node2D, actors: Node2D, zone_id: int) -> void:
	var z: Dictionary = ZoneCatalog.data(zone_id)
	var grid: Rect2i = z["grid"]
	var ga: Color = z["ground_a"]
	var gb: Color = z["ground_b"]
	var path_c: Color = z["path"]
	for y in range(grid.position.y, grid.position.y + grid.size.y):
		for x in range(grid.position.x, grid.position.x + grid.size.x):
			var center := IsoMath.cart_to_iso(x, y)
			var poly := Polygon2D.new()
			poly.polygon = IsoMath.diamond(Vector2.ZERO)
			poly.position = center
			var on_path: bool = absi(int(y) - (grid.position.y + int(grid.size.y / 2))) <= 1
			if on_path:
				poly.color = path_c
			else:
				poly.color = ga if ((x + y) % 2 == 0) else gb
			ground.add_child(poly)
	_banner(props, z)
	match zone_id:
		1:
			_village_props(props, grid)
			_spawn_pack(actors, zone_id, [
				{"mode": "speed", "g": Vector2(4, 6), "lv": 1},
				{"mode": "speed", "g": Vector2(11, 4), "lv": 3},
				{"mode": "audio", "g": Vector2(5, 12), "lv": 4},
				{"mode": "speed", "g": Vector2(12, 11), "lv": 5},
			])
		2:
			_woods_props(props, grid)
			_spawn_pack(actors, zone_id, [
				{"mode": "speed", "g": Vector2(20, 4), "lv": 6},
				{"mode": "audio", "g": Vector2(26, 6), "lv": 8},
				{"mode": "speed", "g": Vector2(22, 12), "lv": 7},
				{"mode": "audio", "g": Vector2(30, 10), "lv": 10},
				{"mode": "forge", "g": Vector2(28, 3), "lv": 12},
			])
		3:
			_citadel_props(props, grid)
			_spawn_pack(actors, zone_id, [
				{"mode": "audio", "g": Vector2(38, 5), "lv": 13},
				{"mode": "speed", "g": Vector2(44, 8), "lv": 14},
				{"mode": "audio", "g": Vector2(40, 12), "lv": 16},
				{"mode": "forge", "g": Vector2(47, 4), "lv": 18},
				{"mode": "forge", "g": Vector2(46, 13), "lv": 20},
			])
	_gate(props, grid)


static func _banner(props: Node2D, z: Dictionary) -> void:
	var grid: Rect2i = z["grid"]
	var pos := IsoMath.cart_to_iso(grid.position.x + 2, grid.position.y + 1)
	var lab := Label.new()
	lab.text = String(z["name"])
	lab.position = pos + Vector2(-90, -86)
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", z["accent"])
	props.add_child(lab)


static func _village_props(props: Node2D, grid: Rect2i) -> void:
	var homes := [Vector2(2, 3), Vector2(8, 2), Vector2(3, 9), Vector2(10, 8)]
	for g in homes:
		_iso_block(props, g, 3, Color(0.86, 0.62, 0.42, 1), Color(0.72, 0.32, 0.28, 1))
	for i in 18:
		var gx := grid.position.x + randi() % grid.size.x
		var gy := grid.position.y + randi() % grid.size.y
		if abs(gy - (grid.position.y + int(grid.size.y * 0.5))) <= 1:
			continue
		_tree(props, Vector2(gx, gy), Color(0.34, 0.62, 0.32, 1), Color(0.45, 0.28, 0.16, 1))
	_flowers(props, grid)


static func _woods_props(props: Node2D, grid: Rect2i) -> void:
	for i in 42:
		var gx := grid.position.x + randi() % grid.size.x
		var gy := grid.position.y + randi() % grid.size.y
		_tree(props, Vector2(gx, gy), Color(0.12, 0.28, 0.22, 1), Color(0.2, 0.12, 0.1, 1), 1.35)
	for g in [Vector2(24, 8), Vector2(29, 5)]:
		_iso_block(props, g, 2, Color(0.22, 0.18, 0.14, 1), Color(0.12, 0.2, 0.16, 1))


static func _citadel_props(props: Node2D, grid: Rect2i) -> void:
	for g in [Vector2(39, 3), Vector2(43, 3), Vector2(47, 3), Vector2(39, 11), Vector2(47, 11)]:
		_iso_block(props, g, 5, Color(0.42, 0.38, 0.52, 1), Color(0.72, 0.58, 0.28, 1))
	_iso_block(props, Vector2(43, 7), 7, Color(0.5, 0.44, 0.62, 1), Color(0.95, 0.78, 0.32, 1))
	for i in 10:
		var gx := grid.position.x + 1 + randi() % (grid.size.x - 2)
		var gy := grid.position.y + 1 + randi() % (grid.size.y - 2)
		_tree(props, Vector2(gx, gy), Color(0.28, 0.16, 0.4, 1), Color(0.18, 0.12, 0.22, 1), 0.9)


static func _iso_block(props: Node2D, grid: Vector2, stories: int, wall: Color, roof: Color) -> void:
	var base := IsoMath.cart_to_iso(grid.x, grid.y)
	var h := 16.0 * stories
	var left := Polygon2D.new()
	left.position = base
	left.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-36, 18), Vector2(-36, 18 - h), Vector2(0, -h)])
	left.color = wall.darkened(0.18)
	var right := Polygon2D.new()
	right.position = base
	right.polygon = PackedVector2Array([Vector2(0, 0), Vector2(36, 18), Vector2(36, 18 - h), Vector2(0, -h)])
	right.color = wall
	var top := Polygon2D.new()
	top.position = base
	top.polygon = IsoMath.diamond(Vector2(0, -h), 72, 36)
	top.color = roof
	props.add_child(left)
	props.add_child(right)
	props.add_child(top)


static func _tree(props: Node2D, grid: Vector2, canopy: Color, trunk: Color, scale := 1.0) -> void:
	var base := IsoMath.cart_to_iso(grid.x, grid.y)
	var t := Polygon2D.new()
	t.position = base
	t.polygon = PackedVector2Array([Vector2(-5, 6), Vector2(5, 6), Vector2(3, -18 * scale), Vector2(-3, -18 * scale)])
	t.color = trunk
	var c := Polygon2D.new()
	c.position = base
	c.polygon = PackedVector2Array([
		Vector2(0, -70 * scale), Vector2(28 * scale, -40 * scale), Vector2(18 * scale, -18 * scale),
		Vector2(-18 * scale, -18 * scale), Vector2(-28 * scale, -40 * scale),
	])
	c.color = canopy
	props.add_child(t)
	props.add_child(c)


static func _flowers(props: Node2D, grid: Rect2i) -> void:
	var colors := [Color(0.96, 0.55, 0.72, 1), Color(0.99, 0.84, 0.32, 1), Color(0.62, 0.78, 0.98, 1)]
	for i in 24:
		var p := IsoMath.cart_to_iso(grid.position.x + randi() % grid.size.x, grid.position.y + randi() % grid.size.y)
		var f := Polygon2D.new()
		f.position = p + Vector2(randf_range(-10, 10), randf_range(-6, 6))
		f.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
		f.color = colors[i % colors.size()]
		props.add_child(f)


static func _gate(props: Node2D, grid: Rect2i) -> void:
	var edge := Vector2(grid.position.x + grid.size.x - 1, grid.position.y + int(grid.size.y * 0.5))
	var pos := IsoMath.cart_to_iso(edge.x, edge.y)
	var arch := Polygon2D.new()
	arch.position = pos
	arch.polygon = PackedVector2Array([Vector2(-18, 10), Vector2(18, 10), Vector2(14, -40), Vector2(-14, -40)])
	arch.color = Color(0.85, 0.78, 0.45, 0.85)
	props.add_child(arch)


static func _spawn_pack(actors: Node2D, zone_id: int, pack: Array) -> void:
	for i in pack.size():
		var spec: Dictionary = pack[i]
		var m: Node = MonsterScene.instantiate()
		var mode := String(spec["mode"])
		m.display_name = MONSTER_NAMES[mode][i % MONSTER_NAMES[mode].size()]
		m.word_level = int(spec["lv"])
		m.zone_id = zone_id
		m.max_hits = maxi(3, 2 + int(spec["lv"]) / 4)
		m.sprite_index = i
		match mode:
			"audio":
				m.combat_mode = 1
			"forge":
				m.combat_mode = 2
			_:
				m.combat_mode = 0
		var g: Vector2 = spec["g"]
		m.position = IsoMath.cart_to_iso(g.x, g.y)
		actors.add_child(m)
