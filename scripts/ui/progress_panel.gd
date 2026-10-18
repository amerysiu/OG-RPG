extends Control

## Learning Map + Teacher panel (opened with the "Map" button or the M key).
##
## Shows every OG stage, zone by zone, with its status (Locked / Learning /
## Mastered), recent accuracy, days at mastery and difficulty tier. The
## teacher section can force a difficulty, change how many days mastery
## needs, place the child at a zone, or reset progress.
##
## On first launch it opens as a welcome screen.

signal closed
signal placed(zone_id: int)

var _list: VBoxContainer
var _tier_pick: OptionButton
var _days_pick: OptionButton
var _zone_pick: OptionButton
var _reset_button: Button
var _welcome: Label
var _reset_armed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.08, 0.86)
	add_child(dim)
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 40
	frame.offset_top = 26
	frame.offset_right = -40
	frame.offset_bottom = -26
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.2, 0.98)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", sb)
	add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	frame.add_child(root)

	var title := Label.new()
	title.text = "Learning Map"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	root.add_child(title)
	_welcome = Label.new()
	_welcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_welcome.add_theme_font_size_override("font_size", 17)
	_welcome.add_theme_color_override("font_color", Color(0.85, 0.92, 1))
	root.add_child(_welcome)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 2.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	var teacher := VBoxContainer.new()
	teacher.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teacher.add_theme_constant_override("separation", 8)
	split.add_child(teacher)
	_section(teacher, "Teacher / parent")
	_tier_pick = _option(teacher, "Difficulty", ["Auto (adaptive)", "Easy", "Normal", "Hard"])
	_tier_pick.item_selected.connect(_on_tier)
	_days_pick = _option(teacher, "Days at ≥80% to master a stage", ["1 day", "2 days (OG default)", "3 days"])
	_days_pick.item_selected.connect(_on_days)
	var zones: Array = []
	for z in OGCurriculum.zone_count():
		zones.append("%d · %s" % [z, String(OGCurriculum.zone(z)["name"])])
	_zone_pick = _option(teacher, "Start the child at", zones)
	var place := Button.new()
	place.text = "Place child here"
	place.pressed.connect(_on_place)
	teacher.add_child(place)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	note.text = "Placing marks every earlier zone as mastered. Use it after a placement check, e.g. a child who already knows letter sounds can start at zone 2."
	teacher.add_child(note)
	_reset_button = Button.new()
	_reset_button.text = "Reset all progress"
	_reset_button.pressed.connect(_on_reset)
	teacher.add_child(_reset_button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	teacher.add_child(spacer)
	var start := Button.new()
	start.text = "Play ▶"
	start.custom_minimum_size = Vector2(0, 52)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_on_close)
	teacher.add_child(start)
	hide()


func _section(parent: Control, text: String) -> void:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 20)
	lab.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	parent.add_child(lab)


func _option(parent: Control, label: String, items: Array) -> OptionButton:
	var lab := Label.new()
	lab.text = label
	lab.add_theme_font_size_override("font_size", 14)
	parent.add_child(lab)
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(String(it))
	parent.add_child(ob)
	return ob


func open(welcome := false) -> void:
	_reset_armed = false
	_reset_button.text = "Reset all progress"
	if welcome:
		_welcome.text = "Welcome! Every monster is beaten by reading and spelling. Start in Echo Meadow (listening only, no letters), or let a teacher place the child further on. Press Play when ready."
	else:
		_welcome.text = "Now learning: %s   ·   Level %d   ·   %d stages mastered" % [OGCurriculum.label(Learner.current_stage()), Learner.level, Learner.mastered_stages().size()]
	var forced := String(Learner.settings.get("tier_override", "auto"))
	_tier_pick.select(maxi(0, ["auto", "easy", "normal", "hard"].find(forced)))
	_days_pick.select(clampi(int(Learner.settings.get("mastery_days", 2)) - 1, 0, 2))
	_zone_pick.select(Learner.highest_unlocked_zone())
	_refresh_list()
	show()


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for z in OGCurriculum.zone_count():
		var zd := OGCurriculum.zone(z)
		var head := Label.new()
		var lock := "" if Learner.is_zone_unlocked(z) else "  (sealed)"
		var boss := "  · boss beaten ✓" if Learner.is_boss_defeated(z) else ""
		head.text = "%d · %s%s%s" % [z, String(zd["name"]), lock, boss]
		head.add_theme_font_size_override("font_size", 18)
		head.add_theme_color_override("font_color", Color(1, 0.85, 0.45) if Learner.is_zone_unlocked(z) else Color(0.55, 0.55, 0.65))
		_list.add_child(head)
		for sid in zd["stages"]:
			_list.add_child(_stage_row(String(sid)))
	var extra := Label.new()
	extra.text = "Across all zones"
	extra.add_theme_font_size_override("font_size", 18)
	extra.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	_list.add_child(extra)
	_list.add_child(_stage_row("H1"))
	_list.add_child(_stage_row("R1"))


func _stage_row(sid: String) -> Control:
	var row := HBoxContainer.new()
	var st := OGCurriculum.stage(sid)
	var name_lab := Label.new()
	name_lab.text = "   %s  %s" % [sid, String(st.get("name", ""))]
	name_lab.custom_minimum_size = Vector2(330, 0)
	name_lab.add_theme_font_size_override("font_size", 15)
	var status := Label.new()
	var text := Learner.status_text(sid)
	if sid == "H1" or sid == "R1":
		text = "Practice · %d items" % int(Learner._st(sid)["total"])
	status.text = text
	status.custom_minimum_size = Vector2(220, 0)
	status.add_theme_font_size_override("font_size", 15)
	var col := Color(0.6, 0.6, 0.7)
	if Learner.is_mastered(sid):
		col = Color(0.55, 0.92, 0.62)
	elif Learner.is_stage_unlocked(sid):
		col = Color(1, 0.9, 0.5)
	status.add_theme_color_override("font_color", col)
	name_lab.add_theme_color_override("font_color", col.lightened(0.2))
	var tier := Label.new()
	tier.text = Learner.tier_for(sid).capitalize() if Learner.is_stage_unlocked(sid) else ""
	tier.add_theme_font_size_override("font_size", 14)
	tier.add_theme_color_override("font_color", Color(0.62, 0.8, 1.0))
	row.add_child(name_lab)
	row.add_child(status)
	row.add_child(tier)
	return row


func _on_tier(i: int) -> void:
	Learner.set_setting("tier_override", ["auto", "easy", "normal", "hard"][i])
	_refresh_list()


func _on_days(i: int) -> void:
	Learner.set_setting("mastery_days", i + 1)


func _on_place() -> void:
	var z := _zone_pick.selected
	Learner.place_at_zone(z)
	placed.emit(z)
	_refresh_list()
	_welcome.text = "Placed at %s. Press Play." % String(OGCurriculum.zone(z)["name"])


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Press again to erase everything"
		return
	_reset_armed = false
	_reset_button.text = "Reset all progress"
	Learner.reset_progress()
	_refresh_list()


func _on_close() -> void:
	Learner.set_setting("started", true)
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
