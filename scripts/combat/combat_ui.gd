extends RefCounted
class_name CombatUI

const COLOR_VOWEL := Color(1.0, 0.42, 0.48, 1)
const COLOR_CONSONANT := Color(0.96, 0.98, 1.0, 1)
const COLOR_CARD := Color(0.1, 0.08, 0.2, 0.94)
const COLOR_PANEL := Color(0.16, 0.13, 0.32, 0.96)


static func grapheme_button(text: String, size := Vector2(84, 84)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = size
	btn.focus_mode = Control.FOCUS_NONE
	if CombatUI.is_vowel(text):
		btn.add_theme_color_override("font_color", COLOR_VOWEL)
		btn.add_theme_color_override("font_hover_color", COLOR_VOWEL)
	else:
		btn.add_theme_color_override("font_color", COLOR_CONSONANT)
		btn.add_theme_color_override("font_hover_color", COLOR_CONSONANT)
	btn.add_theme_font_size_override("font_size", 28)
	return btn


static func is_vowel(grapheme: String) -> bool:
	return grapheme.to_lower() in ["a", "e", "i", "o", "u", "ai", "ie"]


static func dim_overlay() -> ColorRect:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.12, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


static func title_label(text: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 28)
	lab.add_theme_color_override("font_color", Color(0.98, 0.94, 1.0, 1))
	return lab


static func body_label(text: String, color := Color(0.82, 0.86, 0.95, 1)) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(760, 0)
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", color)
	return lab
