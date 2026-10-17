class_name HUD
extends CanvasLayer
## Interface en jeu : phase, horloge, minuteur de procédure, objectif, invite
## d'interaction, dialogues à choix, notifications, bandes cinéma, dossier (Tab), pause.

signal _advance
signal _picked(idx: int)

var player: FPSPlayer

var _root: Control
var _overlay: ColorRect
var _overlay_mat: ShaderMaterial
var _grain: ColorRect
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _phase_box: VBoxContainer
var _phase_kicker: Label
var _phase_title: Label
var _phase_loc: Label
var _obj_box: HBoxContainer
var _obj_label: Label
var _clock_panel: PanelContainer
var _clock_date: Label
var _clock_time: Label
var _timer_box: VBoxContainer
var _timer_label: Label
var _timer_value: Label
var _timer_bar: ProgressBar
var _speed_label: Label
var _cross: Control
var _prompt_box: HBoxContainer
var _prompt_label: Label
var _dlg: PanelContainer
var _dlg_name: Label
var _dlg_role: Label
var _dlg_text: RichTextLabel
var _dlg_choices: VBoxContainer
var _dlg_hint: Label
var _toasts: VBoxContainer
var _sub: Label
var _dossier: PanelContainer
var _dossier_body: RichTextLabel
var _pause: Control
var _typing := false
var _waiting_advance := false
var _choosing := false
var _clock_on := true
var _timer_col := Color.TRANSPARENT


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	_build_overlay()
	_build_top()
	_build_center()
	_build_dialogue()
	_build_toasts()
	_build_dossier()
	_build_pause()


# ── Construction ─────────────────────────────────────────────────────────────
func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = load("res://shaders/overlay.gdshader")
	_overlay.material = _overlay_mat
	_root.add_child(_overlay)
	_grain = ColorRect.new()
	_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grain.gdshader")
	_grain.material = gm
	_root.add_child(_grain)
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.anchor_right = 1.0
	_bar_top.offset_bottom = 0.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_top)
	_bar_bot = ColorRect.new()
	_bar_bot.color = Color.BLACK
	_bar_bot.anchor_top = 1.0
	_bar_bot.anchor_right = 1.0
	_bar_bot.anchor_bottom = 1.0
	_bar_bot.offset_top = 0.0
	_bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar_bot)


func _build_top() -> void:
	# Phase (haut gauche)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_TOP_LEFT)
	m.add_theme_constant_override("margin_left", 48)
	m.add_theme_constant_override("margin_top", 40)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(m)
	_phase_box = VBoxContainer.new()
	_phase_box.add_theme_constant_override("separation", 2)
	m.add_child(_phase_box)
	var kr := HBoxContainer.new()
	kr.add_theme_constant_override("separation", 10)
	var dot := ColorRect.new()
	dot.color = UIKit.RED
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kr.add_child(dot)
	var tw := create_tween().set_loops()
	tw.tween_property(dot, "modulate:a", 0.2, 0.9)
	tw.tween_property(dot, "modulate:a", 1.0, 0.9)
	_phase_kicker = UIKit.caps("", 12, UIKit.ACCENT, 4.0)
	kr.add_child(_phase_kicker)
	_phase_box.add_child(kr)
	_phase_title = UIKit.label("", 34, UIKit.TEXT, "serif", 600)
	_phase_box.add_child(_phase_title)
	_phase_loc = UIKit.label("", 15, UIKit.TEXT_DIM, "sans", 420)
	_phase_box.add_child(_phase_loc)
	_phase_box.add_child(UIKit.spacer(14))
	_obj_box = HBoxContainer.new()
	_obj_box.add_theme_constant_override("separation", 10)
	var bar := ColorRect.new()
	bar.color = UIKit.ACCENT
	bar.custom_minimum_size = Vector2(3, 0)
	_obj_box.add_child(bar)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 0)
	ov.add_child(UIKit.caps("Objectif", 11, UIKit.TEXT_MUTED, 3.0))
	_obj_label = UIKit.label("", 18, UIKit.TEXT, "sans", 520)
	ov.add_child(_obj_label)
	_obj_box.add_child(ov)
	_obj_box.visible = false
	_phase_box.add_child(_obj_box)

	# Horloge (haut droite)
	var rm := MarginContainer.new()
	rm.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rm.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rm.add_theme_constant_override("margin_right", 48)
	rm.add_theme_constant_override("margin_top", 40)
	rm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rm)
	_clock_panel = PanelContainer.new()
	var sb := UIKit.box(Color(0.04, 0.05, 0.07, 0.62), 16, UIKit.LINE, 1, 0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	_clock_panel.add_theme_stylebox_override("panel", sb)
	_clock_panel.custom_minimum_size.x = 300
	rm.add_child(_clock_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	_clock_panel.add_child(cv)
	_clock_date = UIKit.caps("", 11, UIKit.TEXT_DIM, 2.5)
	_clock_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cv.add_child(_clock_date)
	_clock_time = UIKit.label("00:00", 46, UIKit.TEXT, "mono", 300)
	_clock_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cv.add_child(_clock_time)
	_timer_box = VBoxContainer.new()
	_timer_box.add_theme_constant_override("separation", 6)
	_timer_box.visible = false
	cv.add_child(_timer_box)
	_timer_box.add_child(UIKit.hsep(0.08))
	var tr := HBoxContainer.new()
	_timer_label = UIKit.caps("", 11, UIKit.ACCENT, 2.5)
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(_timer_label)
	_timer_value = UIKit.label("", 15, UIKit.TEXT, "mono", 500)
	tr.add_child(_timer_value)
	_timer_box.add_child(tr)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 4)
	_timer_bar.max_value = 1.0
	_timer_bar.step = 0.0001
	_timer_box.add_child(_timer_bar)
	_speed_label = UIKit.caps("", 10, UIKit.RED, 2.0)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cv.add_child(_speed_label)


func _build_center() -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cc)
	_cross = Control.new()
	_cross.custom_minimum_size = Vector2(6, 6)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(func(): _cross.draw_circle(Vector2(3, 3), 2.2, Color(1, 1, 1, 0.55)))
	cc.add_child(_cross)
	# Invite d'interaction
	var pm := Control.new()
	pm.set_anchors_preset(Control.PRESET_CENTER)
	pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pm)
	_prompt_box = HBoxContainer.new()
	_prompt_box.add_theme_constant_override("separation", 12)
	_prompt_box.position = Vector2(-200, 46)
	_prompt_box.custom_minimum_size = Vector2(400, 0)
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.add_child(UIKit.key_chip("E"))
	_prompt_label = UIKit.label("", 19, UIKit.TEXT, "sans", 560)
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_prompt_label.add_theme_constant_override("shadow_outline_size", 6)
	_prompt_box.add_child(_prompt_label)
	_prompt_box.modulate.a = 0.0
	pm.add_child(_prompt_box)
	# Sous-titres d'ambiance
	_sub = UIKit.label("", 21, UIKit.TEXT, "sans", 480)
	_sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub.offset_bottom = -330
	_sub.custom_minimum_size = Vector2(1100, 0)
	_sub.offset_left = -550
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_sub.add_theme_constant_override("shadow_outline_size", 8)
	_sub.modulate.a = 0.0
	_root.add_child(_sub)


func _build_dialogue() -> void:
	_dlg = PanelContainer.new()
	_dlg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dlg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dlg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dlg.custom_minimum_size = Vector2(1180, 0)
	_dlg.offset_left = -590
	_dlg.offset_right = 590
	_dlg.offset_bottom = -54
	var sb := UIKit.box(Color(0.035, 0.042, 0.06, 0.88), 18, Color(1, 1, 1, 0.09), 1, 0)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 30
	_dlg.add_theme_stylebox_override("panel", sb)
	_dlg.visible = false
	_root.add_child(_dlg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_dlg.add_child(v)
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 14)
	_dlg_name = UIKit.label("", 26, UIKit.ACCENT, "serif", 600)
	nr.add_child(_dlg_name)
	_dlg_role = UIKit.caps("", 11, UIKit.TEXT_MUTED, 3.0)
	_dlg_role.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nr.add_child(_dlg_role)
	v.add_child(nr)
	_dlg_text = RichTextLabel.new()
	_dlg_text.bbcode_enabled = true
	_dlg_text.fit_content = true
	_dlg_text.scroll_active = false
	_dlg_text.add_theme_font_size_override("normal_font_size", 23)
	_dlg_text.add_theme_font_size_override("bold_font_size", 23)
	_dlg_text.add_theme_font_size_override("italics_font_size", 24)
	_dlg_text.add_theme_constant_override("line_separation", 6)
	_dlg_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_dlg_text)
	_dlg_choices = VBoxContainer.new()
	_dlg_choices.add_theme_constant_override("separation", 8)
	v.add_child(_dlg_choices)
	_dlg_hint = UIKit.caps("Espace  ▸", 11, UIKit.TEXT_MUTED, 3.0)
	_dlg_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_dlg_hint)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = 48
	_toasts.custom_minimum_size = Vector2(520, 0)
	_toasts.offset_left = -260
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)


func _build_dossier() -> void:
	_dossier = PanelContainer.new()
	_dossier.set_anchors_preset(Control.PRESET_CENTER)
	_dossier.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dossier.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dossier.custom_minimum_size = Vector2(760, 720)
	_dossier.offset_left = -380
	_dossier.offset_top = -360
	var sb := UIKit.box(Color("efe9dc"), 6, Color(0, 0, 0, 0.2), 1, 0)
	sb.content_margin_left = 54
	sb.content_margin_right = 54
	sb.content_margin_top = 44
	sb.content_margin_bottom = 44
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 40
	_dossier.add_theme_stylebox_override("panel", sb)
	_dossier.visible = false
	_dossier.rotation = -0.012
	_root.add_child(_dossier)
	_dossier_body = RichTextLabel.new()
	_dossier_body.bbcode_enabled = true
	_dossier_body.scroll_active = true
	_dossier_body.add_theme_color_override("default_color", Color("1d1b17"))
	_dossier_body.add_theme_font_override("normal_font", UIKit.font("mono", 420))
	_dossier_body.add_theme_font_override("bold_font", UIKit.font("mono", 700))
	_dossier_body.add_theme_font_override("italics_font", UIKit.font("serif", 500, true))
	_dossier_body.add_theme_font_size_override("normal_font_size", 15)
	_dossier_body.add_theme_font_size_override("bold_font_size", 15)
	_dossier_body.add_theme_font_size_override("italics_font_size", 26)
	_dossier.add_child(_dossier_body)


func _build_pause() -> void:
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0.02, 0.025, 0.035, 0.82)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_root.add_child(_pause)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(c)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(380, 0)
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	var t := UIKit.label("Pause", 54, UIKit.TEXT, "serif", 500)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UIKit.caps("Justice Life", 11, UIKit.ACCENT, 6.0)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(UIKit.spacer(24))
	var b1 := UIKit.button("Reprendre", true)
	b1.pressed.connect(toggle_pause)
	v.add_child(b1)
	var sens := HBoxContainer.new()
	sens.add_child(UIKit.label("Sensibilité souris", 15, UIKit.TEXT_DIM))
	var sl := HSlider.new()
	sl.min_value = 0.0008
	sl.max_value = 0.005
	sl.step = 0.0001
	sl.value = 0.0022
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(val): if player: player.mouse_sens = val)
	sens.add_child(sl)
	v.add_child(sens)
	var b2 := UIKit.button("Plein écran")
	b2.pressed.connect(func():
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN))
	v.add_child(b2)
	var b3 := UIKit.button("Abandonner et revenir au menu")
	b3.pressed.connect(func():
		get_tree().paused = false
		Transition.goto("res://scenes/main_menu.tscn"))
	v.add_child(b3)


# ── API publique ─────────────────────────────────────────────────────────────
func set_phase(kicker: String, title: String, location: String) -> void:
	_phase_kicker.text = kicker.to_upper()
	_phase_title.text = title
	_phase_loc.text = location
	_phase_box.modulate.a = 0.0
	create_tween().tween_property(_phase_box, "modulate:a", 1.0, 0.8)


func set_objective(text: String) -> void:
	if text == "":
		_obj_box.visible = false
		return
	_obj_label.text = text
	_obj_box.visible = true
	_obj_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_obj_box, "modulate:a", 1.0, 0.5)


func show_clock(on: bool) -> void:
	_clock_on = on
	_clock_panel.visible = on


func set_timer(label: String, value: String, ratio: float, col: Color = UIKit.ACCENT) -> void:
	_timer_box.visible = true
	_timer_label.text = label.to_upper()
	_timer_label.add_theme_color_override("font_color", col)
	_timer_value.text = value
	_timer_bar.value = clamp(ratio, 0.0, 1.0)
	if col != _timer_col:
		_timer_col = col
		_timer_bar.add_theme_stylebox_override("fill", UIKit.box(col, 3, Color(0, 0, 0, 0), 0))


func hide_timer() -> void:
	_timer_box.visible = false


func set_prompt(text: String) -> void:
	if text != "":
		_prompt_label.text = text
	var tw := create_tween()
	tw.tween_property(_prompt_box, "modulate:a", 1.0 if text != "" else 0.0, 0.15)


func set_stress(v: float) -> void:
	_overlay_mat.set_shader_parameter("stress", v)


func flash() -> void:
	_overlay_mat.set_shader_parameter("flash", 0.9)
	var tw := create_tween()
	tw.tween_method(func(x): _overlay_mat.set_shader_parameter("flash", x), 0.9, 0.0, 1.2)


func letterbox(on: bool, t: float = 0.8) -> void:
	var h := 96.0 if on else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", h, t).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_bar_bot, "offset_top", -h, t).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_phase_box, "modulate:a", 0.0 if on else 1.0, t * 0.5)
	_cross.visible = not on


func toast(text: String, kicker: String = "Procès-verbal", col: Color = UIKit.ACCENT) -> void:
	var p := PanelContainer.new()
	var sb := UIKit.box(Color(0.04, 0.05, 0.07, 0.9), 12, Color(col, 0.5), 1, 0)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(UIKit.caps(kicker, 10, col, 3.0))
	var l := UIKit.label(text, 17, UIKit.TEXT, "sans", 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 480
	v.add_child(l)
	p.add_child(v)
	p.modulate.a = 0.0
	_toasts.add_child(p)
	Sfx.play("ui", -10.0, 0.8)
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	tw.tween_interval(4.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func subtitle(text: String, dur: float = 3.5) -> void:
	_sub.text = text
	var tw := create_tween()
	tw.tween_property(_sub, "modulate:a", 1.0, 0.3)
	tw.tween_interval(dur)
	tw.tween_property(_sub, "modulate:a", 0.0, 0.5)


## Réplique d'un personnage. Attend que le joueur continue.
func say(speaker: String, role: String, text: String, npc: Human = null) -> void:
	await _show_line(speaker, role, text, npc)
	_dlg_hint.visible = true
	_waiting_advance = true
	if Devtools.autoplay:
		await get_tree().create_timer(0.35).timeout
		_waiting_advance = false
	else:
		await _advance
	_hide_dialogue()


## Pensée intérieure du joueur (italique, sans nom).
func narrate(text: String) -> void:
	await say("", "", "[i]%s[/i]" % text)


## Question avec choix ; renvoie l'index choisi.
func ask(speaker: String, role: String, text: String, choices: Array, npc: Human = null) -> int:
	await _show_line(speaker, role, text, npc)
	_dlg_hint.visible = false
	for c in _dlg_choices.get_children():
		c.queue_free()
	for i in choices.size():
		_dlg_choices.add_child(_choice_button(i, choices[i]))
	_choosing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.can_look = false
	var idx: int
	if Devtools.autoplay:
		await get_tree().create_timer(0.4).timeout
		idx = Devtools.choose(choices.size())
	else:
		idx = await _picked
	_choosing = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player:
		player.can_look = true
	Sfx.play("ui", -4.0)
	for c in _dlg_choices.get_children():
		c.queue_free()
	_hide_dialogue()
	return idx


func _choice_button(i: int, text: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "   %s" % text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_font_override("font", UIKit.font("sans", 500))
	var n := UIKit.box(Color(1, 1, 1, 0.03), 10, Color(1, 1, 1, 0.07), 1, 0)
	n.content_margin_left = 56
	n.content_margin_top = 12
	n.content_margin_bottom = 12
	n.content_margin_right = 20
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = UIKit.ACCENT_DIM
	h.border_color = Color(UIKit.ACCENT, 0.7)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var num := UIKit.label(str(i + 1), 14, UIKit.ACCENT, "mono", 700)
	num.position = Vector2(20, 13)
	b.add_child(num)
	b.mouse_entered.connect(func(): Sfx.play("hover", -14.0))
	b.pressed.connect(func(): _picked.emit(i))
	b.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.06 * i)
	tw.tween_property(b, "modulate:a", 1.0, 0.25)
	return b


func _show_line(speaker: String, role: String, text: String, npc: Human) -> void:
	if Devtools.autoplay:
		print("[%s] %s" % [speaker, text.left(110)])
	_dlg.visible = true
	_dlg_name.text = speaker
	_dlg_name.visible = speaker != ""
	_dlg_role.text = role.to_upper()
	_dlg_hint.visible = false
	for c in _dlg_choices.get_children():
		c.queue_free()
	_dlg_text.text = text
	_dlg_text.visible_characters = 0
	_dlg.modulate.a = 0.0
	create_tween().tween_property(_dlg, "modulate:a", 1.0, 0.18)
	if npc:
		npc.say_anim(true)
	_typing = true
	var total := _dlg_text.get_total_character_count()
	var shown := 0.0
	var speed := 62.0 if not Devtools.autoplay else 2000.0
	var tick_acc := 0
	while _typing and shown < total:
		shown += get_process_delta_time() * speed
		_dlg_text.visible_characters = int(shown)
		if int(shown) / 3 != tick_acc:
			tick_acc = int(shown) / 3
			Sfx.play("tick", -22.0, randf_range(0.9, 1.2))
		await get_tree().process_frame
	_typing = false
	_dlg_text.visible_characters = -1
	if npc:
		get_tree().create_timer(0.4).timeout.connect(func(): if is_instance_valid(npc): npc.say_anim(false))


func _hide_dialogue() -> void:
	_dlg.visible = false


func dialogue_open() -> bool:
	return _dlg.visible


func toggle_dossier() -> void:
	_dossier.visible = not _dossier.visible
	if _dossier.visible:
		_dossier_body.text = _dossier_text()
		Sfx.play("ui", -6.0, 0.7)


func _dossier_text() -> String:
	var gs := GameState
	var t := "[i]Procès-verbal[/i]\n[b]RÉPUBLIQUE FRANÇAISE — POLICE NATIONALE[/b]\n"
	t += "──────────────────────────────────────────────\n"
	t += "IDENTITÉ      %s\n" % gs.full_name()
	t += "NÉ(E) LE      %s à %s\n" % [gs.birth_date, gs.birth_place]
	t += "CASIER        %s\n" % {"vierge": "néant", "antecedents": "mentions antérieures", "recidive": "récidive légale"}[gs.record]
	t += "──────────────────────────────────────────────\n[b]CHEFS DE POURSUITE[/b]\n"
	for d in gs.infractions():
		t += "• %s\n   %s — %s / %s\n" % [d.name, d.article, InfractionDB.prison_label(d.prison), InfractionDB.fine_label(d.fine)]
	t += "──────────────────────────────────────────────\n"
	t += "JURIDICTION   %s\n" % gs.jurisdiction().name
	t += "PEINE MAX     %s\n" % InfractionDB.prison_label(gs.max_prison_months())
	if gs.gav_possible():
		t += "GARDE À VUE   %d h maximum\n" % gs.gav_max_hours
	t += "AVOCAT        %s\n" % {"none": "aucun", "commis": "commis d'office", "choisi": gs.lawyer_name}[gs.lawyer]
	t += "MÉDECIN       %s\n" % ("demandé" if gs.asked_doctor else "non")
	t += "PROCHE AVISÉ  %s\n" % ("oui" if gs.asked_family else "non")
	t += "──────────────────────────────────────────────\n[b]DÉCLARATIONS[/b]\n"
	t += "Aveux : %d   Dénégations : %d   Silence : %d   Minimisations : %d\n" % [gs.admissions, gs.denials, gs.silences, gs.minimizations]
	if gs.situation != "":
		t += "Situation déclarée : %s\n" % {"cdi": "salarié (CDI)", "interim": "intérimaire", "etudiant": "étudiant", "chomage": "sans emploi"}.get(gs.situation, gs.situation)
	t += "\n[i]Tab pour fermer[/i]"
	return t


func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p or _choosing else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _dossier.visible:
			toggle_dossier()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("dossier"):
		toggle_dossier()
		get_viewport().set_input_as_handled()
		return
	if _choosing:
		for i in 4:
			if event.is_action_pressed("choice_%d" % (i + 1)) and i < _dlg_choices.get_child_count():
				_picked.emit(i)
				get_viewport().set_input_as_handled()
				return
		return
	if event.is_action_pressed("advance") and _dlg.visible:
		if _typing:
			_typing = false
		elif _waiting_advance:
			_waiting_advance = false
			_advance.emit()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _clock_on:
		_clock_time.text = GameState.clock_hm()
		_clock_date.text = GameState.date_label().to_upper()
	_speed_label.text = "Temps ×%d (F9)" % int(Devtools.time_mult) if Devtools.time_mult > 1.0 else ""
