extends Control

signal note_pressed(index: int)

const NOTE_NAMES := ["Dó", "Dó♯", "Ré", "Ré♯", "Mi", "Fá", "Fá♯", "Sol", "Sol♯", "Lá", "Lá♯", "Si"]
const GOLD := Color("f1cf78")
const VIOLET := Color("a452ea")
const CYAN := Color("46c7f4")
const IVORY := Color("eadab7")

var active_notes: Array = [0, 2, 4, 5, 7, 9, 11]
var wheel_title := "DÓ MAIOR"
var intervals := "T  •  T  •  S  •  T  •  T  •  T  •  S"
var note_buttons: Array[Button] = []
var note_centers: Array[Vector2] = []
var center_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(600, 470)
	mouse_filter = Control.MOUSE_FILTER_PASS
	for index in range(12):
		var button := Button.new()
		button.text = NOTE_NAMES[index]
		button.custom_minimum_size = Vector2(68, 68)
		button.add_theme_font_size_override("font_size", 13 if index % 2 == 0 else 11)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_emit_note.bind(index))
		add_child(button)
		note_buttons.append(button)
	center_label = Label.new()
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.add_theme_font_size_override("font_size", 20)
	center_label.add_theme_color_override("font_color", GOLD)
	center_label.add_theme_constant_override("outline_size", 6)
	center_label.add_theme_color_override("font_outline_color", Color("040a14"))
	center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_label)
	resized.connect(_layout_wheel)
	_layout_wheel()
	_refresh_styles()


func configure_scale(title: String, notes: Array, interval_sequence: String) -> void:
	wheel_title = title.to_upper()
	active_notes = notes.duplicate()
	intervals = interval_sequence
	_refresh_styles()
	queue_redraw()


func _emit_note(index: int) -> void:
	note_pressed.emit(index)
	var button := note_buttons[index]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.16, 1.16), 0.10)
	tween.tween_property(button, "scale", Vector2.ONE, 0.16)


func _layout_wheel() -> void:
	if note_buttons.is_empty() or center_label == null:
		return
	var center := size * Vector2(0.5, 0.51)
	var radius: float = minf(size.x * 0.37, size.y * 0.39)
	note_centers.clear()
	for index in range(12):
		var angle := -PI * 0.5 + TAU * float(index) / 12.0
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		note_centers.append(point)
		var button := note_buttons[index]
		var diameter := 74.0 if active_notes.has(index) else 60.0
		button.size = Vector2(diameter, diameter)
		button.pivot_offset = button.size * 0.5
		button.position = point - button.size * 0.5
	center_label.text = wheel_title + "\n\n" + intervals + "\n\nToque em cada grau para ouvir"
	center_label.position = center - Vector2(205, 72)
	center_label.size = Vector2(410, 144)
	queue_redraw()


func _refresh_styles() -> void:
	if note_buttons.is_empty():
		return
	for index in range(12):
		var active := active_notes.has(index)
		var semitone := index in [1, 3, 6, 8, 10]
		var border := GOLD if active else VIOLET if semitone else Color("41506a")
		var fill := Color("4b351de8") if active else Color("17102bd9") if semitone else Color("091426dc")
		var style := _style(fill, border, 3 if active else 1, 36)
		note_buttons[index].add_theme_stylebox_override("normal", style)
		note_buttons[index].add_theme_stylebox_override("hover", _style(Color(border, 0.30), IVORY, 2, 36))
		note_buttons[index].add_theme_stylebox_override("pressed", _style(Color(border, 0.48), Color.WHITE, 3, 36))
		note_buttons[index].add_theme_color_override("font_color", GOLD if active else Color("c58cf0") if semitone else CYAN)


func _draw() -> void:
	if note_centers.size() != 12:
		return
	var center := size * Vector2(0.5, 0.51)
	var radius: float = minf(size.x * 0.37, size.y * 0.39)
	draw_circle(center, radius * 0.61, Color("07101fb5"))
	draw_arc(center, radius * 0.64, 0, TAU, 96, Color("b68a456f"), 2.0, true)
	draw_arc(center, radius, 0, TAU, 96, Color("a452ea69"), 2.0, true)
	for index in range(active_notes.size()):
		var from_index: int = active_notes[index]
		var to_index: int = active_notes[(index + 1) % active_notes.size()]
		draw_line(note_centers[from_index], note_centers[to_index], Color("f1cf786b"), 2.0, true)
	for point in note_centers:
		draw_line(center, point, Color("486a9b24"), 1.0, true)


func _style(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
