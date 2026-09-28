class_name Hud
extends CanvasLayer
## In-game overlay: company badge + level, cash pill, objective banner,
## floating joystick, side buttons, upgrade/settings panels, toasts, popups.

var joy := Vector2.ZERO

var root: Control
var _money_label: Label
var _money_pill: PanelContainer
var _money_shown := 0.0
var _obj_panel: PanelContainer
var _obj_label: Label
var _obj_icon: TextureRect
var _obj_step: Label
var _obj_text := ""
var _company: Label
var _level_label: Label
var _level_bar: ProgressBar
var _toasts: VBoxContainer
var _joy_area: Control
var _joy_base_pos := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _joy_active := false
var _btn_upgrades: Button
var _btn_settings: Button
var _modal: Control = null
var _upg_rows := {}
var _edge_arrow: TextureRect
var _hand: Control
var _hand_t := 0.0
var _big_card: Control = null
var _t := 0.0

const JOY_R := 70.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)
	_build_joystick()
	_build_top()
	_build_side()
	_build_objective()
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_left = -240
	_toasts.offset_right = 240
	_toasts.offset_top = 96
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 8)
	root.add_child(_toasts)
	_edge_arrow = UiKit.tex("fx_ground_arrow", 64)
	_edge_arrow.modulate = Color(1.0, 0.88, 0.2)
	_edge_arrow.pivot_offset = Vector2(32, 32)
	_edge_arrow.visible = false
	root.add_child(_edge_arrow)
	_build_hand()
	Game.money_changed.connect(_on_money)
	Game.upgrades_changed.connect(_refresh_upgrades)
	Game.zone_unlocked.connect(func(_id: String) -> void: _refresh_level())
	Game.company_changed.connect(func(n: String) -> void: _company.text = n)
	_money_shown = Game.money
	_refresh_level()


# ------------------------------------------------------------ building --
func _build_joystick() -> void:
	_joy_area = Control.new()
	_joy_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_joy_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_joy_area.gui_input.connect(_on_joy_input)
	_joy_area.draw.connect(_draw_joy)
	root.add_child(_joy_area)


func _on_joy_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_joy_active = true
			_joy_base_pos = mb.position
			_joy_knob = mb.position
		else:
			_joy_active = false
			joy = Vector2.ZERO
		_joy_area.queue_redraw()
	elif ev is InputEventMouseMotion and _joy_active:
		var mm := ev as InputEventMouseMotion
		var d := mm.position - _joy_base_pos
		if d.length() > JOY_R * 1.6:
			_joy_base_pos = mm.position - d.normalized() * JOY_R * 1.6   # drag the base along
			d = mm.position - _joy_base_pos
		_joy_knob = _joy_base_pos + d.limit_length(JOY_R)
		joy = (d / JOY_R).limit_length(1.0)
		if joy.length() < 0.12:
			joy = Vector2.ZERO
		_joy_area.queue_redraw()


func _draw_joy() -> void:
	if not _joy_active:
		return
	_joy_area.draw_circle(_joy_base_pos, JOY_R + 6, Color(0.1, 0.05, 0.2, 0.18))
	_joy_area.draw_circle(_joy_base_pos, JOY_R, Color(1, 1, 1, 0.3))
	_joy_area.draw_arc(_joy_base_pos, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.8), 4.0, true)
	_joy_area.draw_circle(_joy_knob, 34, Color(1, 1, 1, 0.92))
	_joy_area.draw_arc(_joy_knob, 34, 0, TAU, 32, Color(0.2, 0.16, 0.28, 0.3), 3.0, true)


func _build_top() -> void:
	# company badge + level (top-left)
	var tl := HBoxContainer.new()
	tl.position = Vector2(16, 12)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_theme_constant_override("separation", 10)
	root.add_child(tl)
	var badge := TextureRect.new()
	badge.texture = load("res://assets/logo/logo_badge.png")
	badge.custom_minimum_size = Vector2(92, 92)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(badge)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	tl.add_child(vb)
	_company = UiKit.label(Game.company, 24)
	vb.add_child(_company)
	var lvl := HBoxContainer.new()
	lvl.add_theme_constant_override("separation", 8)
	lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lvl)
	_level_label = UiKit.label("Lv 1", 20, Color(1.0, 0.9, 0.4))
	lvl.add_child(_level_label)
	_level_bar = ProgressBar.new()
	_level_bar.custom_minimum_size = Vector2(150, 18)
	_level_bar.show_percentage = false
	_level_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl.add_child(_level_bar)
	# money pill (top-right)
	_money_pill = PanelContainer.new()
	_money_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_money_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_money_pill.offset_right = -16
	_money_pill.offset_left = -16
	_money_pill.offset_top = 16
	_money_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_pill.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 1, 1, 0.95), 30))
	root.add_child(_money_pill)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	_money_pill.add_child(hb)
	hb.add_child(UiKit.tex("cash", 46))
	_money_label = UiKit.label(Game.fmt(Game.money), 34, Color(0.22, 0.6, 0.22), 0)
	_money_label.custom_minimum_size = Vector2(96, 0)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(_money_label)


func _build_side() -> void:
	var vb := VBoxContainer.new()
	vb.position = Vector2(18, 124)
	vb.add_theme_constant_override("separation", 12)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vb)
	_btn_settings = UiKit.icon_button("ui_gear", UiKit.PURPLE, 66)
	_btn_settings.pressed.connect(open_settings)
	vb.add_child(_btn_settings)
	_btn_upgrades = UiKit.icon_button("ui_up", UiKit.GREEN, 66)
	_btn_upgrades.pressed.connect(open_upgrades)
	vb.add_child(_btn_upgrades)


func _build_objective() -> void:
	_obj_panel = PanelContainer.new()
	_obj_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_obj_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_obj_panel.offset_left = 0
	_obj_panel.offset_right = 0
	_obj_panel.offset_top = 18
	_obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 1, 1, 0.95), 26))
	root.add_child(_obj_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	_obj_panel.add_child(hb)
	_obj_icon = UiKit.tex("ui_star", 44)
	hb.add_child(_obj_icon)
	_obj_label = UiKit.dark_label("", 24)
	hb.add_child(_obj_label)
	_obj_step = UiKit.label("", 18, Color(0.6, 0.56, 0.7), 0)
	hb.add_child(_obj_step)


func _build_hand() -> void:
	_hand = Control.new()
	_hand.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hand.offset_left = 0
	_hand.offset_right = 0
	_hand.offset_top = -170
	_hand.offset_bottom = -170
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hand)
	var trail := UiKit.label("DRAG TO MOVE", 30, Color(1, 1, 1), 10)
	trail.position = Vector2(-110, 70)
	_hand.add_child(trail)
	var icon := UiKit.tex("ui_hand", 110)
	icon.name = "Icon"
	icon.position = Vector2(-55, -40)
	_hand.add_child(icon)
	_hand.visible = false


# ---------------------------------------------------------------- tick --
func _process(delta: float) -> void:
	_t += delta
	# rolling money counter
	var target := float(Game.money)
	if absf(_money_shown - target) > 0.5:
		_money_shown = lerpf(_money_shown, target, clampf(delta * 10.0, 0.0, 1.0))
		if absf(_money_shown - target) < 1.0:
			_money_shown = target
		_money_label.text = Game.fmt(int(round(_money_shown)))
	_btn_upgrades.visible = Game.is_unlocked("office")
	_adapt_layout()
	_update_edge_arrow()
	_update_hand(delta)


var _portrait := false


## Phones held upright: shrink the base canvas and move the objective banner
## under the badge / cash row so nothing overlaps.
func _adapt_layout() -> void:
	var ws := get_window().size
	var portrait := ws.y > ws.x
	if portrait == _portrait:
		return
	_portrait = portrait
	get_window().content_scale_size = Vector2i(720, 720) if portrait else Vector2i(1280, 720)
	_obj_panel.offset_top = 124 if portrait else 18
	_toasts.offset_top = 200 if portrait else 96
	_center_objective()


func _update_hand(delta: float) -> void:
	var show := Game.playing and Game.tut == 0 and _modal == null and Game.world != null \
		and (Game.world.get("player") as Player).velocity.length() < 0.1 and not _joy_active
	if Game.world != null and (Game.world.get("player") as Player).velocity.length() > 0.5:
		_hand_t = -999.0
	_hand_t += delta
	_hand.visible = show and _hand_t > 1.0
	if _hand.visible:
		var ic: Control = _hand.get_node("Icon")
		ic.position = Vector2(-55 + sin(_t * 2.5) * 90.0, -40 + absf(cos(_t * 2.5)) * 10.0)


func _update_edge_arrow() -> void:
	_edge_arrow.visible = false
	if Game.world == null or not Game.playing or _modal != null:
		return
	var obj: Objectives = Game.world.get("objectives")
	if obj == null or obj.target == Vector3.INF:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs := root.get_viewport_rect().size
	var p := cam.unproject_position(obj.target)
	var behind := cam.is_position_behind(obj.target)
	var margin := 70.0
	var inside := p.x > margin and p.x < vs.x - margin and p.y > margin + 60 and p.y < vs.y - margin
	if inside and not behind:
		return
	var c := vs * 0.5
	var dir := (p - c).normalized()
	if behind:
		dir = -dir
	var hw := vs.x * 0.5 - margin
	var hh := vs.y * 0.5 - margin
	var k := minf(hw / maxf(absf(dir.x), 0.001), hh / maxf(absf(dir.y), 0.001))
	var pos := c + dir * k
	_edge_arrow.visible = true
	_edge_arrow.position = pos - Vector2(32, 32) + dir * sin(_t * 6.0) * 6.0
	_edge_arrow.rotation = dir.angle() + PI * 0.5


func _on_money(_value: int, d: int) -> void:
	if d > 0:
		_money_pill.pivot_offset = _money_pill.size * 0.5
		var tw := _money_pill.create_tween()
		_money_pill.scale = Vector2(1.12, 1.12)
		tw.tween_property(_money_pill, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _modal != null and _modal.name == "Upgrades":
		_refresh_upgrades()


func _refresh_level() -> void:
	var total := Layout.ZONES.size()
	var n := 0
	for z in Layout.ZONES:
		if Game.is_unlocked(str(z["id"])):
			n += 1
	var per := 4
	_level_label.text = "Lv %d" % (1 + n / per)
	_level_bar.max_value = per
	_level_bar.value = n % per
	if n >= total:
		_level_label.text = "MAX"
		_level_bar.value = per


func set_objective(text: String, icon: String, step: String) -> void:
	_obj_panel.visible = Game.playing and not text.is_empty()
	if text == _obj_text:
		return
	_obj_text = text
	_obj_label.text = text
	_obj_icon.texture = Items.icon(icon) if not icon.is_empty() else null
	_obj_step.text = step
	_center_objective()
	_pop_later(_obj_panel, 0.85)


func _center_objective() -> void:
	_obj_panel.offset_left = 0
	_obj_panel.offset_right = 0
	_obj_panel.reset_size()
	var w := _obj_panel.get_combined_minimum_size().x
	_obj_panel.offset_left = -w * 0.5
	_obj_panel.offset_right = w * 0.5


func _pop_later(c: Control, from: float) -> void:
	c.scale = Vector2.ONE * from
	await get_tree().process_frame
	if is_instance_valid(c):
		UiKit.pop(c, from)


# -------------------------------------------------------------- toasts --
func toast(text: String, icon := "ui_star") -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.16, 0.28, 0.9), 22))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)
	hb.add_child(UiKit.tex(icon, 38))
	var l := UiKit.label(text, 22, Color(1, 1, 1), 0)
	hb.add_child(l)
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	Sfx.play("whoosh", -12.0, 1.3)


## Big celebratory card in the middle of the screen (new product, more land).
func big_card(title: String, line1: String, line2: String, icon: String) -> void:
	if _big_card != null and is_instance_valid(_big_card):
		_big_card.queue_free()
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.offset_left = 0
	p.offset_right = 0
	p.offset_top = -40
	p.offset_bottom = -40
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 1, 1, 0.97), 32, 6, UiKit.ORANGE))
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	var t := UiKit.label(title, 40, UiKit.ORANGE, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	vb.add_child(t)
	var ic := UiKit.tex(icon, 130)
	vb.add_child(ic)
	var l1 := UiKit.dark_label(line1, 32)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l1)
	var l2 := UiKit.label(line2, 20, Color(0.45, 0.42, 0.55), 0)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l2)
	root.add_child(p)
	_big_card = p
	_pop_later(p, 0.3)
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)


# -------------------------------------------------------------- modals --
func _open_modal(name_: String, title: String, width := 640.0) -> VBoxContainer:
	close_modal()
	var m := Control.new()
	m.name = name_
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(m)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.04, 0.16, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close_modal())
	m.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 0.98, 0.95), 32, 6, UiKit.ORANGE))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := UiKit.label(title, 38, UiKit.ORANGE, 10)
	t.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UiKit.icon_button("ui_close", UiKit.RED, 54)
	x.pressed.connect(close_modal)
	head.add_child(x)
	_modal = m
	joy = Vector2.ZERO
	_joy_active = false
	UiKit.pop(panel, 0.7)
	return vb


func close_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	_upg_rows.clear()


func close_upgrades() -> void:
	if _modal != null and _modal.name == "Upgrades":
		close_modal()


func open_upgrades() -> void:
	if not Game.is_unlocked("office"):
		toast("Build the Manager's Office to unlock upgrades", "office")
		return
	if _modal != null and _modal.name == "Upgrades":
		return
	var vb := _open_modal("Upgrades", "Upgrades", 700)
	for k in Game.UPGRADE_ORDER:
		var d: Dictionary = Game.UPGRADES[k]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.95, 0.92, 0.98), 20, 0, Color.BLACK, false))
		vb.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		hb.add_child(UiKit.tex(str(d["icon"]), 58))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		hb.add_child(info)
		info.add_child(UiKit.dark_label(str(d["name"]), 24))
		var desc := UiKit.label(str(d["desc"]), 17, Color(0.45, 0.42, 0.55), 0)
		info.add_child(desc)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 3)
		info.add_child(pips)
		var btn := UiKit.button("", UiKit.GREEN, Vector2(150, 58), 24)
		var key: String = k
		btn.pressed.connect(func() -> void: _buy_upgrade(key))
		hb.add_child(btn)
		_upg_rows[k] = {"pips": pips, "btn": btn}
	_refresh_upgrades()


func _buy_upgrade(k: String) -> void:
	if Game.buy_upgrade(k):
		Sfx.play("unlock", -6.0, 1.2)
		var row: Dictionary = _upg_rows.get(k, {})
		if row.has("btn"):
			var b: Button = row["btn"]
			b.pivot_offset = b.size * 0.5
			b.scale = Vector2(1.15, 1.15)
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	else:
		Sfx.play("nope", -6.0)


func _refresh_upgrades() -> void:
	for k in _upg_rows:
		var row: Dictionary = _upg_rows[k]
		var pips: HBoxContainer = row["pips"]
		var btn: Button = row["btn"]
		for c in pips.get_children():
			c.queue_free()
		var lvl := Game.upgrade_level(k)
		var mx := Game.upgrade_max(k)
		for i in mx:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(18, 10)
			pip.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.GREEN if i < lvl else Color(0.8, 0.78, 0.86), 4, 0, Color.BLACK, false))
			pips.add_child(pip)
		if lvl >= mx:
			btn.text = "MAX"
			btn.disabled = true
		else:
			var c := Game.upgrade_cost(k)
			btn.text = "$" + Game.fmt(c)
			btn.disabled = false
			UiKit.style_button(btn, UiKit.GREEN if Game.money >= c else UiKit.GREY)


func open_settings() -> void:
	var vb := _open_modal("Settings", "Settings", 560)
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 18)
	vb.add_child(grid)
	for k in ["music", "sfx", "shadows"]:
		var key: String = k
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		grid.add_child(col)
		var on := bool(Game.settings.get(key, true))
		var icon := "ui_shadows" if key == "shadows" else ("ui_%s_%s" % [key, "on" if on else "off"])
		var b := UiKit.icon_button(icon, UiKit.BLUE if on else UiKit.GREY, 96)
		col.add_child(b)
		var names := {"music": "Music", "sfx": "Sound", "shadows": "Shadows"}
		var l := UiKit.dark_label(str(names[key]), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		b.pressed.connect(func() -> void:
			Game.settings[key] = not bool(Game.settings.get(key, true))
			_apply_settings()
			Game.save_game()
			open_settings())
	vb.add_child(HSeparator.new())
	vb.add_child(UiKit.dark_label("Bakery name", 22))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	var le := LineEdit.new()
	le.text = Game.company
	le.max_length = 24
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(le)
	var rn := UiKit.button("Rename", UiKit.ORANGE, Vector2(140, 56), 22)
	rn.pressed.connect(func() -> void:
		Game.set_company(le.text)
		toast("Renamed to " + Game.company, "ui_star"))
	hb.add_child(rn)
	vb.add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var reset := UiKit.button("Reset progress", UiKit.RED, Vector2(220, 58), 22)
	reset.pressed.connect(_confirm_reset)
	row.add_child(reset)
	if OS.get_name() != "Web" and OS.get_name() != "Android" and OS.get_name() != "iOS":
		var q := UiKit.button("Save & Quit", UiKit.PURPLE, Vector2(200, 58), 22)
		q.pressed.connect(func() -> void:
			Game.save_game()
			get_tree().quit())
		row.add_child(q)
	var help := UiKit.label("Drag anywhere (or WASD) to move. Stand on things to use them.", 16, Color(0.5, 0.46, 0.6), 0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(help)


func _confirm_reset() -> void:
	var vb := _open_modal("Confirm", "Start over?", 520)
	var l := UiKit.dark_label("This wipes your bakery, money and upgrades. Your pigeons will miss you.", 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(460, 0)
	vb.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var no := UiKit.button("Keep playing", UiKit.GREEN, Vector2(200, 60), 22)
	no.pressed.connect(close_modal)
	row.add_child(no)
	var yes := UiKit.button("Reset", UiKit.RED, Vector2(160, 60), 22)
	yes.pressed.connect(func() -> void:
		Game.wipe_progress(true, false)
		get_tree().reload_current_scene())
	row.add_child(yes)


func _apply_settings() -> void:
	Sfx.refresh_music()
	if Game.world != null:
		var sun: DirectionalLight3D = Game.world.get_node_or_null("Sun")
		if sun != null:
			sun.shadow_enabled = bool(Game.settings.get("shadows", true))


func show_offline(amount: int, secs: int) -> void:
	var vb := _open_modal("Offline", "Welcome back!", 540)
	var mins := maxi(1, secs / 60)
	var t := "Your staff kept the bakery open for %d min." % mins if mins < 120 else "Your staff kept the bakery open while you were away."
	var l := UiKit.dark_label(t, 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(480, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	hb.add_child(UiKit.tex("cash", 70))
	hb.add_child(UiKit.label("+$" + Game.fmt(amount), 54, UiKit.GREEN, 10))
	var b := UiKit.button("Collect", UiKit.GREEN, Vector2(240, 70), 30)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		Game.add_money(amount)
		Sfx.play("kaching", -2.0)
		close_modal())
	vb.add_child(b)


func show_win() -> void:
	var vb := _open_modal("Win", "Pigeon Empire complete!", 640)
	var badge := TextureRect.new()
	badge.texture = load("res://assets/logo/logo_badge.png")
	badge.custom_minimum_size = Vector2(170, 170)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(badge)
	var l := UiKit.dark_label("%s is the most famous bakery in pigeon history.\nThe Founder's Statue now watches over the flock." % Game.company, 21)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(580, 0)
	vb.add_child(l)
	var mins := int(float(Game.stats["playtime"]) / 60.0)
	var s := UiKit.label("Pigeons served: %d    Earned: $%s    Time: %d min" % [int(Game.stats["served"]), Game.fmt(int(Game.stats["earned"])), mins], 19, Color(0.4, 0.36, 0.5), 0)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var keep := UiKit.button("Keep playing", UiKit.BLUE, Vector2(220, 64), 24)
	keep.pressed.connect(close_modal)
	row.add_child(keep)
	var nb := UiKit.button("Open Branch #%d" % (Game.branch + 1), UiKit.ORANGE, Vector2(260, 64), 24)
	nb.pressed.connect(func() -> void:
		Game.wipe_progress(true, true)
		get_tree().reload_current_scene())
	row.add_child(nb)
	var hint := UiKit.label("A new branch starts fresh, but every pigeon pays +50% more there.", 16, Color(0.5, 0.46, 0.6), 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
