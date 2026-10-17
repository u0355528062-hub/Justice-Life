extends CanvasLayer
## Fondus au noir, cartes de chapitre et ellipses temporelles.

var _black: ColorRect
var _box: VBoxContainer
var _num: Label
var _title: Label
var _sub: Label
var _line: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	add_child(_black)

	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.add_theme_constant_override("separation", 14)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	add_child(_box)
	_num = UIKit.caps("", 15, UIKit.ACCENT, 8.0)
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_num)
	_title = UIKit.label("", 74, UIKit.TEXT, "serif", 500)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_title)
	var lc := CenterContainer.new()
	_line = ColorRect.new()
	_line.color = Color(UIKit.ACCENT, 0.7)
	_line.custom_minimum_size = Vector2(0, 1)
	lc.add_child(_line)
	_box.add_child(lc)
	_sub = UIKit.label("", 20, UIKit.TEXT_DIM, "sans", 380)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_sub)


func is_black() -> bool:
	return _black.modulate.a > 0.99


func fade_out(t: float = 0.9) -> void:
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", 1.0, t)
	await tw.finished


func fade_in(t: float = 1.2) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "modulate:a", 0.0, t).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_black() -> void:
	_black.modulate.a = 1.0
	_black.mouse_filter = Control.MOUSE_FILTER_STOP


func goto(path: String, t: float = 0.9) -> void:
	if not is_black():
		await fade_out(t)
	Sfx.stop_all_loops(0.6)
	get_tree().change_scene_to_file(path)


func chapter(num: String, title: String, subtitle: String, hold: float = 2.8) -> void:
	if not is_black():
		await fade_out(0.8)
	_num.text = num.to_upper()
	_title.text = title
	_sub.text = subtitle
	_line.custom_minimum_size.x = 0
	Sfx.play("boom", -4.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_box, "modulate:a", 1.0, 1.1)
	tw.tween_property(_line, "custom_minimum_size:x", 220.0, 1.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(hold).timeout
	var tw2 := create_tween()
	tw2.tween_property(_box, "modulate:a", 0.0, 0.9)
	await tw2.finished


## Ellipse : texte sur fond noir (ex. « 14 mois plus tard »).
func card(title: String, subtitle: String = "", hold: float = 2.6) -> void:
	await chapter("", title, subtitle, hold)
