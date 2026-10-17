class_name UIKit
extends RefCounted
## Boîte à outils UI : polices, couleurs, styles et thème global.

const BG := Color("07090d")
const PANEL := Color(0.055, 0.065, 0.09, 0.82)
const PANEL_SOLID := Color("0e1118")
const PANEL_HI := Color(0.09, 0.105, 0.14, 0.92)
const LINE := Color(1, 1, 1, 0.08)
const LINE_HI := Color(1, 1, 1, 0.16)
const TEXT := Color("eceef3")
const TEXT_DIM := Color("9aa0ad")
const TEXT_MUTED := Color("5f6573")
const ACCENT := Color("e2b65f")
const ACCENT_DIM := Color(0.886, 0.714, 0.373, 0.16)
const BLUE := Color("5b8cff")
const RED := Color("ef4b4b")
const GREEN := Color("4cc38a")

static var _fonts := {}
static var _theme: Theme


static func font(kind: String = "sans", weight: int = 400, italic: bool = false) -> FontVariation:
	var key := "%s_%d_%s" % [kind, weight, italic]
	if _fonts.has(key):
		return _fonts[key]
	var path := "res://assets/fonts/Inter.ttf"
	match kind:
		"serif": path = "res://assets/fonts/PlayfairDisplay.ttf"
		"mono": path = "res://assets/fonts/JetBrainsMono.ttf"
	var base := load(path) as FontFile
	var fv := FontVariation.new()
	fv.base_font = base
	var coords := {"wght": weight}
	if kind == "sans":
		coords["opsz"] = 24
	fv.variation_opentype = coords
	if italic:
		fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	_fonts[key] = fv
	return fv


static func box(bg: Color, radius: int = 10, border: Color = LINE, bw: int = 1, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = true
	if pad > 0:
		s.set_content_margin_all(pad)
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("sans", 420)
	t.default_font_size = 18

	t.set_color("font_color", "Label", TEXT)
	# Boutons
	var b_normal := box(Color(1, 1, 1, 0.035), 10, LINE, 1, 14)
	var b_hover := box(Color(1, 1, 1, 0.08), 10, LINE_HI, 1, 14)
	var b_press := box(ACCENT_DIM, 10, ACCENT, 1, 14)
	var b_dis := box(Color(1, 1, 1, 0.015), 10, Color(1, 1, 1, 0.04), 1, 14)
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_press)
	t.set_stylebox("hover_pressed", "Button", b_press)
	t.set_stylebox("disabled", "Button", b_dis)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED)
	t.set_font("font", "Button", font("sans", 520))
	t.set_font_size("font_size", "Button", 17)
	# LineEdit
	t.set_stylebox("normal", "LineEdit", box(Color(1, 1, 1, 0.04), 10, LINE, 1, 12))
	t.set_stylebox("focus", "LineEdit", box(Color(1, 1, 1, 0.06), 10, ACCENT, 1, 12))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_MUTED)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", ACCENT_DIM)
	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 14, LINE, 1, 0))
	t.set_stylebox("panel", "Panel", box(PANEL, 14, LINE, 1, 0))
	# ScrollBar fine
	var grab := box(Color(1, 1, 1, 0.14), 4, Color(0, 0, 0, 0), 0)
	var grab_h := box(Color(1, 1, 1, 0.28), 4, Color(0, 0, 0, 0), 0)
	var track := box(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0)
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, track)
		t.set_stylebox("grabber", sb, grab)
		t.set_stylebox("grabber_highlight", sb, grab_h)
		t.set_stylebox("grabber_pressed", sb, grab_h)
	# Tooltip
	t.set_stylebox("panel", "TooltipPanel", box(PANEL_SOLID, 8, LINE_HI, 1, 10))
	t.set_color("font_color", "TooltipLabel", TEXT)
	# ProgressBar
	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.07), 3, Color(0, 0, 0, 0), 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 3, Color(0, 0, 0, 0), 0))
	# RichTextLabel
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font("sans", 420))
	t.set_font("bold_font", "RichTextLabel", font("sans", 680))
	t.set_font("italics_font", "RichTextLabel", font("serif", 420, true))
	t.set_font("mono_font", "RichTextLabel", font("mono", 450))
	_theme = t
	return t


static func label(text: String, size: int = 18, color: Color = TEXT, kind: String = "sans", weight: int = 420) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func caps(text: String, size: int = 12, color: Color = TEXT_DIM, spacing: float = 3.0) -> Label:
	var l := label(text.to_upper(), size, color, "sans", 620)
	var fv := font("sans", 620).duplicate() as FontVariation
	fv.spacing_glyph = int(spacing)
	l.add_theme_font_override("font", fv)
	return l


static func button(text: String, primary: bool = false, size: int = 17) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", size)
	if primary:
		b.add_theme_stylebox_override("normal", box(ACCENT, 10, ACCENT, 1, 16))
		b.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.12), 10, ACCENT.lightened(0.3), 1, 16))
		b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.15), 10, ACCENT, 1, 16))
		b.add_theme_stylebox_override("disabled", box(Color(ACCENT, 0.18), 10, Color(ACCENT, 0.2), 1, 16))
		b.add_theme_color_override("font_color", Color("15110a"))
		b.add_theme_color_override("font_hover_color", Color("15110a"))
		b.add_theme_color_override("font_pressed_color", Color("15110a"))
		b.add_theme_color_override("font_disabled_color", Color(0, 0, 0, 0.45))
		b.add_theme_font_override("font", font("sans", 680))
	b.mouse_entered.connect(func(): Sfx.play("hover", -14.0))
	b.pressed.connect(func(): Sfx.play("ui", -6.0))
	return b


static func hsep(alpha: float = 0.08) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, alpha)
	r.custom_minimum_size = Vector2(0, 1)
	return r


static func spacer(h: float = 8, w: float = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	return c


static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m


static func chip(text: String, col: Color, size: int = 11) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(col, 0.14), 6, Color(col, 0.45), 1)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := caps(text, size, col.lightened(0.15), 1.5)
	p.add_child(l)
	return p


static func key_chip(key: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(Color(1, 1, 1, 0.92), 6, Color(1, 1, 1, 1), 0)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := label(key, 15, Color("111318"), "sans", 750)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p
