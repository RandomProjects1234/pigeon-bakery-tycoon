class_name UiKit
extends RefCounted
## Mobile-game style widgets: chunky rounded panels and bouncy buttons.

const INK := Color(0.2, 0.16, 0.28)
const GREEN := Color(0.33, 0.8, 0.36)
const PURPLE := Color(0.55, 0.42, 0.9)
const ORANGE := Color(1.0, 0.62, 0.18)
const RED := Color(0.93, 0.33, 0.35)
const GREY := Color(0.72, 0.72, 0.78)
const BLUE := Color(0.3, 0.6, 1.0)

static var _theme: Theme


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = Fx.font()
	t.default_font_size = 22
	t.set_color("font_color", "Label", Color(1, 1, 1))
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 8)
	t.set_color("font_outline_color", "Button", INK)
	t.set_constant("outline_size", "Button", 8)
	t.set_color("font_color", "Button", Color(1, 1, 1))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.95, 0.95, 0.95))
	t.set_color("font_color", "LineEdit", INK)
	t.set_font_size("font_size", "LineEdit", 26)
	var le := panel_style(Color(1, 1, 1), 16, 3, Color(0.85, 0.8, 0.9))
	le.content_margin_left = 16
	le.content_margin_right = 16
	le.content_margin_top = 8
	le.content_margin_bottom = 8
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", panel_style(Color(1, 1, 1), 16, 3, ORANGE))
	t.set_stylebox("panel", "PanelContainer", panel_style(Color(1, 1, 1, 0.96), 24))
	var pb_bg := panel_style(Color(0.2, 0.16, 0.28, 0.5), 10)
	pb_bg.content_margin_left = 0
	pb_bg.content_margin_right = 0
	pb_bg.content_margin_top = 0
	pb_bg.content_margin_bottom = 0
	var pb_fill := panel_style(GREEN, 10)
	pb_fill.content_margin_left = 0
	pb_fill.content_margin_right = 0
	pb_fill.content_margin_top = 0
	pb_fill.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	_theme = t
	return t


static func panel_style(bg: Color, radius := 24, border := 0, border_col := Color(0, 0, 0), shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_col
	if shadow:
		s.shadow_color = Color(0.1, 0.05, 0.2, 0.28)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing = true
	return s


static func button(text: String, color: Color, min_size := Vector2(160, 64), font_size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, color)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = min_size * 0.5
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.92, 0.92), 0.06))
	b.button_up.connect(func() -> void:
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.pressed.connect(func() -> void: Sfx.play("click", -4.0))
	return b


static func style_button(b: Button, color: Color) -> void:
	var n := panel_style(color, 20, 0, Color(0, 0, 0), true)
	n.border_width_bottom = 6
	n.border_color = color.darkened(0.3)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = color.lightened(0.08)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = color.darkened(0.08)
	p.border_width_bottom = 2
	p.content_margin_top = 14
	var d := n.duplicate() as StyleBoxFlat
	d.bg_color = GREY
	d.border_color = GREY.darkened(0.3)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func icon_button(icon: String, color: Color, size := 68.0) -> Button:
	var b := button("", color, Vector2(size, size), 20)
	b.icon = Items.icon(icon)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(size * 0.62))
	return b


static func label(text: String, size := 22, color := Color(1, 1, 1), outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	return l


static func dark_label(text: String, size := 22) -> Label:
	return label(text, size, INK, 0)


static func tex(icon: String, size := 48.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Items.icon(icon)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func pop(c: Control, from := 0.6) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * from
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
