extends RefCounted
class_name IsoMapBuilder

## Builds the 8-zone world: ground, props, bridges, gates and monsters.
## One monster guards each OG stage (left to right in teaching order), the
## zone boss waits by the exit gate, and a rare Rule-breaker (heart words)
## roams every zone from Phoneme Village on. The Daily Quest Board stands in
## Phoneme Village.

const MonsterScene := preload("res://scenes/iso_monster.tscn")

## Monster family names per zone, with the combat mode that picks the sprite
## set and the starred (signature) attack: audio = Wand, speed = Light, forge = Heavy.
const FAMILIES := {
	0: [["Echo Bat", "audio"], ["Hum Bee", "audio"], ["Clap Toad", "speed"]],
	1: [["Letter Sprite", "audio"], ["Mirror Imp", "speed"], ["Glyph Pup", "forge"]],
	2: [["Speed Wolf", "speed"], ["Forge Boar", "forge"], ["Thicket Wisp", "audio"]],
	3: [["Magic-e Mage", "audio"], ["Twin Heron", "speed"], ["Open Otter", "forge"]],
	4: [["Bossy-R Bear", "forge"], ["Oi-Oy Goblin", "audio"], ["Silent Ghost", "speed"]],
	5: [["Splitter Ram", "forge"], ["Schwa Yeti", "audio"], ["Peak Hawk", "speed"]],
	6: [["Affix Knight", "forge"], ["Rule Warden", "speed"], ["Suffix Squire", "audio"]],
	7: [["Root Wraith", "audio"], ["Greek Sphinx", "forge"], ["Rune Owl", "speed"]],
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
	for zone_id in ZoneCatalog.count():
		_build_zone(ground, props, actors, zone_id)
		if zone_id < ZoneCatalog.count() - 1:
			_bridge(ground, zone_id)


static func _build_zone(ground: Node2D, props: Node2D, actors: Node2D, zone_id: int) -> void:
	var z: Dictionary = ZoneCatalog.data(zone_id)
	var grid: Rect2i = z["grid"]
	var path_y := ZoneCatalog.path_row()
	for y in range(grid.position.y, grid.end.y):
		for x in range(grid.position.x, grid.end.x):
			var poly := Polygon2D.new()
			poly.polygon = IsoMath.diamond(Vector2.ZERO)
			poly.position = IsoMath.cart_to_iso(x, y)
			if absi(y - path_y) <= 1:
				poly.color = z["path"]
			else:
				poly.color = z["ground_a"] if ((x + y) % 2 == 0) else z["ground_b"]
			ground.add_child(poly)
	_banner(props, z)
	match String(z["key"]):
		"meadow":
			_flowers(props, grid, 46)
		"village":
			_village_props(props, grid)
		"woods":
			_woods_props(props, grid)
		"lake":
			_lake_props(ground, props, grid)
		"caves":
			_cave_props(props, grid)
		"mountains":
			_mountain_props(props, grid)
		"citadel":
			_citadel_props(props, grid)
		"ruins":
			_ruin_props(props, grid)
	_spawn_zone_monsters(actors, zone_id, z)
	if zone_id < ZoneCatalog.count() - 1:
		_gate(props, grid, zone_id)


static func _spawn_zone_monsters(actors: Node2D, zone_id: int, z: Dictionary) -> void:
	var grid: Rect2i = z["grid"]
	var stages: Array = z["stages"]
	var path_y := ZoneCatalog.path_row()
	var fam: Array = FAMILIES.get(zone_id, FAMILIES[2])
	var n := stages.size()
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var gx := grid.position.x + 1.5 + t * (grid.size.x - 4.5)
		var gy := path_y + (-3.2 if i % 2 == 0 else 3.2)
		var f: Array = fam[i % fam.size()]
		_spawn(actors, {
			"name": String(f[0]), "mode": String(f[1]), "zone": zone_id, "stage": String(stages[i]),
			"kind": "stage", "g": Vector2(gx, gy), "sprite": i,
		})
	var boss_mode := String(fam[0][1])
	_spawn(actors, {
		"name": String(z["boss"]), "mode": boss_mode, "zone": zone_id, "stage": String(stages[n - 1]),
		"kind": "boss", "g": Vector2(grid.end.x - 1.6, path_y), "sprite": 2, "stages": stages,
	})
	if zone_id >= 1:
		_spawn(actors, {
			"name": "Rule-breaker", "mode": "speed", "zone": zone_id, "stage": "H1",
			"kind": "heart", "g": Vector2(grid.position.x + 6.5, path_y + 5.2), "sprite": 1,
		})
	if String(z["key"]) == "village":
		_spawn(actors, {
			"name": "Daily Quest Board", "mode": "forge", "zone": zone_id, "stage": "R1",
			"kind": "quest", "g": Vector2(grid.position.x + 3.0, path_y - 5.4), "sprite": 0,
		})


static func _spawn(actors: Node2D, spec: Dictionary) -> void:
	var m: Node = MonsterScene.instantiate()
	m.display_name = String(spec["name"])
	m.zone_id = int(spec["zone"])
	m.stage_id = String(spec["stage"])
	m.kind = String(spec["kind"])
	m.boss_stages = spec.get("stages", [])
	m.sprite_index = int(spec["sprite"])
	match String(spec["mode"]):
		"audio":
			m.combat_mode = 1
		"forge":
			m.combat_mode = 2
		_:
			m.combat_mode = 0
	var g: Vector2 = spec["g"]
	m.position = IsoMath.cart_to_iso(g.x, g.y)
	actors.add_child(m)


static func _banner(props: Node2D, z: Dictionary) -> void:
	var grid: Rect2i = z["grid"]
	var pos := IsoMath.cart_to_iso(grid.position.x + 2, grid.position.y + 1)
	var lab := Label.new()
	lab.text = "%d · %s" % [int(z["id"]), String(z["name"])]
	lab.position = pos + Vector2(-110, -86)
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", z["accent"])
	props.add_child(lab)


static func _bridge(ground: Node2D, zone_id: int) -> void:
	var g := ZoneCatalog.grid(zone_id)
	var path_y := ZoneCatalog.path_row()
	var col: Color = ZoneCatalog.data(zone_id)["path"]
	for x in range(g.end.x, g.end.x + ZoneCatalog.GAP):
		for y in range(path_y - 1, path_y + 2):
			var poly := Polygon2D.new()
			poly.polygon = IsoMath.diamond(Vector2.ZERO)
			poly.position = IsoMath.cart_to_iso(x, y)
			poly.color = col.darkened(0.15)
			ground.add_child(poly)


static func _gate(props: Node2D, grid: Rect2i, zone_id: int) -> void:
	var pos := IsoMath.cart_to_iso(grid.end.x + 0.5, ZoneCatalog.path_row())
	var gate := Node2D.new()
	gate.position = pos
	gate.add_to_group("zone_gate")
	gate.set_meta("next_zone", zone_id + 1)
	var arch := Polygon2D.new()
	arch.name = "Arch"
	arch.polygon = PackedVector2Array([Vector2(-22, 10), Vector2(22, 10), Vector2(16, -52), Vector2(-16, -52)])
	arch.color = Color(0.85, 0.78, 0.45, 0.9)
	gate.add_child(arch)
	var bar := Polygon2D.new()
	bar.name = "Seal"
	bar.polygon = PackedVector2Array([Vector2(-14, 8), Vector2(14, 8), Vector2(12, -46), Vector2(-12, -46)])
	bar.color = Color(0.55, 0.25, 0.75, 0.85)
	gate.add_child(bar)
	var lab := Label.new()
	lab.name = "Label"
	lab.position = Vector2(-120, -96)
	lab.size = Vector2(240, 40)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	gate.add_child(lab)
	props.add_child(gate)


# ------------------------------------------------------------------ props

static func _rand_cell(grid: Rect2i, margin: int = 0) -> Vector2:
	var path_y := ZoneCatalog.path_row()
	for _i in 12:
		var gx := grid.position.x + margin + randi() % maxi(1, grid.size.x - margin * 2)
		var gy := grid.position.y + margin + randi() % maxi(1, grid.size.y - margin * 2)
		if absi(gy - path_y) > 1:
			return Vector2(gx, gy)
	return Vector2(grid.position.x, grid.position.y)


static func _village_props(props: Node2D, grid: Rect2i) -> void:
	for g in [Vector2(2, 3), Vector2(8, 2), Vector2(3, 10), Vector2(10, 10)]:
		_iso_block(props, Vector2(grid.position.x, 0) + g, 3, Color(0.86, 0.62, 0.42, 1), Color(0.72, 0.32, 0.28, 1))
	for i in 14:
		_tree(props, _rand_cell(grid), Color(0.34, 0.62, 0.32, 1), Color(0.45, 0.28, 0.16, 1))
	_flowers(props, grid, 20)


static func _woods_props(props: Node2D, grid: Rect2i) -> void:
	for i in 36:
		_tree(props, _rand_cell(grid), Color(0.12, 0.3, 0.22, 1), Color(0.2, 0.12, 0.1, 1), 1.35)


static func _lake_props(ground: Node2D, props: Node2D, grid: Rect2i) -> void:
	for i in 10:
		var c := _rand_cell(grid, 1)
		var poly := Polygon2D.new()
		poly.polygon = IsoMath.diamond(Vector2.ZERO, 120, 60)
		poly.position = IsoMath.cart_to_iso(c.x, c.y)
		poly.color = Color(0.2, 0.42, 0.7, 0.85)
		ground.add_child(poly)
	for i in 16:
		var c := _rand_cell(grid)
		var reed := Polygon2D.new()
		reed.position = IsoMath.cart_to_iso(c.x, c.y)
		reed.polygon = PackedVector2Array([Vector2(-2, 4), Vector2(2, 4), Vector2(1, -26), Vector2(-1, -26)])
		reed.color = Color(0.36, 0.6, 0.3)
		props.add_child(reed)


static func _cave_props(props: Node2D, grid: Rect2i) -> void:
	for i in 14:
		var c := _rand_cell(grid)
		_iso_block(props, c, 1 + randi() % 3, Color(0.3, 0.26, 0.26), Color(0.42, 0.34, 0.3))
	for i in 8:
		var c := _rand_cell(grid)
		var glow := Polygon2D.new()
		glow.position = IsoMath.cart_to_iso(c.x, c.y)
		glow.polygon = PackedVector2Array([Vector2(0, -12), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)])
		glow.color = Color(1.0, 0.55, 0.25, 0.9)
		props.add_child(glow)


static func _mountain_props(props: Node2D, grid: Rect2i) -> void:
	for i in 9:
		var c := _rand_cell(grid)
		var base := IsoMath.cart_to_iso(c.x, c.y)
		var h := 60.0 + randf() * 50.0
		var peak := Polygon2D.new()
		peak.position = base
		peak.polygon = PackedVector2Array([Vector2(-42, 14), Vector2(42, 14), Vector2(0, -h)])
		peak.color = Color(0.5, 0.52, 0.58)
		var snow := Polygon2D.new()
		snow.position = base
		snow.polygon = PackedVector2Array([Vector2(-12, -h + 26), Vector2(12, -h + 26), Vector2(0, -h)])
		snow.color = Color(0.96, 0.97, 1.0)
		props.add_child(peak)
		props.add_child(snow)


static func _citadel_props(props: Node2D, grid: Rect2i) -> void:
	var ox := grid.position.x
	for g in [Vector2(3, 3), Vector2(7, 3), Vector2(11, 3), Vector2(3, 11), Vector2(11, 11)]:
		_iso_block(props, Vector2(ox, 0) + g, 5, Color(0.42, 0.38, 0.52, 1), Color(0.72, 0.58, 0.28, 1))
	for i in 8:
		_tree(props, _rand_cell(grid, 1), Color(0.28, 0.16, 0.4, 1), Color(0.18, 0.12, 0.22, 1), 0.9)


static func _ruin_props(props: Node2D, grid: Rect2i) -> void:
	for i in 12:
		var c := _rand_cell(grid)
		_iso_block(props, c, 1 + randi() % 4, Color(0.72, 0.64, 0.5), Color(0.82, 0.74, 0.58))


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


static func _flowers(props: Node2D, grid: Rect2i, n: int) -> void:
	var colors := [Color(0.96, 0.55, 0.72, 1), Color(0.99, 0.84, 0.32, 1), Color(0.62, 0.78, 0.98, 1)]
	for i in n:
		var c := _rand_cell(grid)
		var f := Polygon2D.new()
		f.position = IsoMath.cart_to_iso(c.x, c.y) + Vector2(randf_range(-10, 10), randf_range(-6, 6))
		f.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
		f.color = colors[i % colors.size()]
		props.add_child(f)
