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
var _dialog: Control = null
var _order_panel: PanelContainer
var _order_title: Label
var _order_rows: VBoxContainer
var _order_sig := ""
var _raid_panel: PanelContainer
var _raid_label: Label
var _btn_global: Button
var _global_pill: PanelContainer
var _global_label: Label

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
	_build_military_panels()
	_build_global_pill()
	_build_war_panel()
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
	_btn_global = UiKit.icon_button("globe", UiKit.BLUE, 66)
	_btn_global.pressed.connect(open_global)
	vb.add_child(_btn_global)
	_btn_global.visible = false


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
	var ceo_on := bool(Game.ceo["deal"]) and bool(Game.ceo["seen_end"])
	_btn_global.visible = ceo_on
	if _global_pill != null:
		_global_pill.visible = ceo_on and Game.playing
		if ceo_on and Game.world != null:
			_global_label.text = "Global +$%s/s" % Game.fmt(int(Game.world.call("global_income")))
	_adapt_layout()
	_update_edge_arrow()
	_update_hand(delta)
	_update_military_panels()
	_update_war_panel()


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


## True while something is covering the screen (so offers/intros wait).
func is_busy() -> bool:
	return _modal != null or _dialog != null or not Game.playing


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
	var l := UiKit.dark_label("%s is the most famous bakery in pigeon history.\nThe Founder's Statue now watches over the flock.\n...but keep playing. Someone from the army is on the way." % Game.company, 21)
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


# ------------------------------------------------ military + security --
func _build_global_pill() -> void:
	_global_pill = PanelContainer.new()
	_global_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_global_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_global_pill.offset_right = -16
	_global_pill.offset_left = -16
	_global_pill.offset_top = 88
	_global_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_global_pill.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.2, 0.35, 0.7, 0.92), 20))
	root.add_child(_global_pill)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	_global_pill.add_child(hb)
	hb.add_child(UiKit.tex("globe", 30))
	_global_label = UiKit.label("", 20, Color(1, 1, 1), 6)
	hb.add_child(_global_label)
	_global_pill.visible = false


## CEO dashboard: every city's restaurant, upgrade them to grow global income.
func open_global() -> void:
	var vb := _open_modal("Global", "GLOBAL HQ", 760)
	var inv := Investors.by_id(str(Game.ceo["investor"]))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	head.add_child(UiKit.tex(str(inv.get("portrait", "portrait_host")), 70))
	var info := UiKit.dark_label("", 20)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(560, 0)
	head.add_child(info)
	if Game.has_flag("war_started") and not bool(Game.war["won"]):
		var go := UiKit.button("Go to HQ Tower" if str(Game.world.get("location")) != "hq" else "Back to the bakery", UiKit.RED, Vector2(280, 56), 22)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.pressed.connect(func() -> void:
			close_modal()
			Game.world.call("travel", "hq" if str(Game.world.get("location")) != "hq" else "bakery"))
		vb.add_child(go)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var rows: Array[Dictionary] = []
	var cities: Dictionary = Game.ceo["cities"]
	var refresh := func() -> void:
		var total: float = Game.world.call("global_income")
		info.text = "Co-CEO: %s (%d%% partner)\nYour share of worldwide income: $%s per second" % [
			str(inv.get("name", "")), int(Game.ceo["equity"]), Game.fmt(int(total))]
		for r in rows:
			var i: int = r["i"]
			var lvl := int(cities.get(str(Investors.CITIES[i][0]), 1))
			var bombed := (Game.war["bombed"] as Dictionary).has(str(Investors.CITIES[i][0]))
			(r["lvl"] as Label).text = "Lv %d  -  $%s/s%s" % [lvl, Game.fmt(int(Investors.city_income(i, lvl) * (0.3 if bombed else 1.0))), "  POOP-BOMBED!" if bombed else ""]
			(r["lvl"] as Label).add_theme_color_override("font_color", Color(0.85, 0.3, 0.25) if bombed else Color(0.35, 0.4, 0.6))
			var cb: Button = r["clean"]
			cb.visible = bombed
			if bombed:
				var cc := CrowWar.clean_cost(i)
				cb.text = "Clean $" + Game.fmt(cc)
				UiKit.style_button(cb, UiKit.ORANGE if Game.money >= cc else UiKit.GREY)
			var b: Button = r["btn"]
			if lvl >= 10:
				b.text = "MAX"
				b.disabled = true
			else:
				var cost := Investors.upgrade_cost(i, lvl)
				b.text = "$" + Game.fmt(cost)
				UiKit.style_button(b, UiKit.GREEN if Game.money >= cost else UiKit.GREY)
	for i in Investors.CITIES.size():
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.93, 0.95, 1.0), 16, 0, Color.BLACK, false))
		list.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		hb.add_child(UiKit.tex("globe", 40))
		var name_l := UiKit.dark_label(str(Investors.CITIES[i][0]), 22)
		name_l.custom_minimum_size = Vector2(200, 0)
		hb.add_child(name_l)
		var lvl_l := UiKit.label("", 20, Color(0.35, 0.4, 0.6), 0)
		lvl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lvl_l)
		var clean := UiKit.button("", UiKit.ORANGE, Vector2(130, 50), 18)
		var cidx := i
		clean.pressed.connect(func() -> void:
			var cname := str(Investors.CITIES[cidx][0])
			if Game.spend(CrowWar.clean_cost(cidx)):
				(Game.war["bombed"] as Dictionary).erase(cname)
				Sfx.play("sparkle", -4.0)
				refresh.call()
			else:
				Sfx.play("nope", -6.0))
		hb.add_child(clean)
		var btn := UiKit.button("", UiKit.GREEN, Vector2(150, 50), 20)
		var idx := i
		btn.pressed.connect(func() -> void:
			var city := str(Investors.CITIES[idx][0])
			var lvl := int(cities.get(city, 1))
			var cost := Investors.upgrade_cost(idx, lvl)
			if lvl < 10 and Game.spend(cost):
				cities[city] = lvl + 1
				Sfx.play("unlock", -6.0, 1.1)
				refresh.call()
			else:
				Sfx.play("nope", -6.0))
		hb.add_child(btn)
		rows.append({"i": i, "lvl": lvl_l, "btn": btn, "clean": clean})
	refresh.call()


func _build_military_panels() -> void:
	_order_panel = PanelContainer.new()
	_order_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_order_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_order_panel.offset_right = -16
	_order_panel.offset_left = -16
	_order_panel.offset_top = 92
	_order_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.26, 0.33, 0.2, 0.93), 20, 3, Color(0.95, 0.82, 0.35)))
	root.add_child(_order_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_order_panel.add_child(vb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	vb.add_child(hb)
	hb.add_child(UiKit.tex("military", 34))
	_order_title = UiKit.label("", 20, Color(1, 0.95, 0.7), 6)
	hb.add_child(_order_title)
	_order_rows = VBoxContainer.new()
	_order_rows.add_theme_constant_override("separation", 0)
	vb.add_child(_order_rows)
	_order_panel.visible = false
	_raid_panel = PanelContainer.new()
	_raid_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_raid_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_raid_panel.offset_top = 88
	_raid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.75, 0.12, 0.15, 0.92), 20, 3, Color(1, 1, 1)))
	root.add_child(_raid_panel)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 8)
	_raid_panel.add_child(rh)
	rh.add_child(UiKit.tex("portrait_crow", 40))
	_raid_label = UiKit.label("", 24, Color(1, 1, 1), 8)
	rh.add_child(_raid_label)
	_raid_panel.visible = false


func _update_military_panels() -> void:
	if Game.world == null:
		return
	var mil: Military = Game.world.get("military")
	var sec: Security = Game.world.get("security")
	var show_order := mil != null and mil.state == "active" and Game.playing and _modal == null
	_order_panel.visible = show_order
	if show_order:
		var secs := maxi(0, int(ceil(float(mil.order["time"]))))
		_order_title.text = "ORDER  %d:%02d" % [secs / 60, secs % 60]
		_order_title.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if secs <= 20 else Color(1, 0.95, 0.7))
		var sig := str(mil.order["got"])
		if sig != _order_sig:
			_order_sig = sig
			for c in _order_rows.get_children():
				c.queue_free()
			for t in mil.order["need"]:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				row.add_child(UiKit.tex(str(t), 30))
				var got := int(mil.order["got"][t])
				var need := int(mil.order["need"][t])
				var done := got >= need
				row.add_child(UiKit.label("%d / %d" % [mini(got, need), need], 20, Color(0.6, 1, 0.5) if done else Color(1, 1, 1), 6))
				_order_rows.add_child(row)
			_order_panel.offset_left = -16
			_order_panel.reset_size()
	var raid_text := ""
	if sec != null and Game.playing:
		if sec.raid_active:
			raid_text = "CROW RAID!  %d left" % sec.alive_count()
		elif sec.warn_t > 0.0:
			raid_text = "Crow Clan raid in %d..." % int(ceil(sec.warn_t))
	_raid_panel.visible = not raid_text.is_empty() and _modal == null
	if _raid_panel.visible and _raid_label.text != raid_text:
		_raid_label.text = raid_text
		_raid_panel.offset_left = 0
		_raid_panel.offset_right = 0
		_raid_panel.reset_size()
		var w := _raid_panel.get_combined_minimum_size().x
		_raid_panel.offset_left = -w * 0.5
		_raid_panel.offset_right = w * 0.5
	_raid_panel.offset_top = 200 if _portrait else 88


## Story dialog at the bottom of the screen. Tap to advance.
func dialog(lines: Array, speaker: String, portrait: String, on_done: Callable) -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	joy = Vector2.ZERO
	_joy_active = false
	var m := Control.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(m)
	_dialog = m
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.1, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -210
	panel.offset_bottom = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 0.98, 0.94), 28, 6, Color(0.42, 0.5, 0.3)))
	m.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	panel.add_child(hb)
	hb.add_child(UiKit.tex(portrait, 150))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	vb.add_child(UiKit.label(speaker, 28, Color(0.42, 0.5, 0.3), 0))
	var text := UiKit.dark_label("", 24)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.custom_minimum_size = Vector2(300, 0)
	vb.add_child(text)
	var hint := UiKit.label("tap to continue", 16, Color(0.55, 0.5, 0.62), 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint)
	var state := {"i": 0}
	var show_line := func() -> void:
		text.text = str(lines[int(state["i"])])
		text.visible_ratio = 0.0
		var tw := text.create_tween()
		tw.tween_property(text, "visible_ratio", 1.0, 0.02 * text.text.length())
		Sfx.coo(-8.0)
	show_line.call()
	UiKit.pop(panel, 0.8)
	var finish := func() -> void:
		if is_instance_valid(m):
			m.queue_free()
		_dialog = null
		on_done.call()
	var on_input := func(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed):
			return
		if text.visible_ratio < 1.0:
			text.visible_ratio = 1.0
			return
		state["i"] = int(state["i"]) + 1
		Sfx.play("click", -6.0)
		if int(state["i"]) >= lines.size():
			finish.call()
		else:
			show_line.call()
	m.gui_input.connect(on_input)
	if Game.test_mode() and not bool(Game.dev["show_ui"]):
		# autoplay: skip through the dialog
		get_tree().create_timer(1.0, false).timeout.connect(finish)


## The General's offer, with haggling.
func military_offer(mil: Military) -> void:
	if Game.test_mode() and not bool(Game.dev["show_ui"]):
		mil.accept()
		return
	var vb := _open_modal("Offer", "MILITARY ORDER", 700)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vb.add_child(top)
	top.add_child(UiKit.tex("portrait_general", 120))
	var say := UiKit.dark_label("Baker! My troops need supplies. Here is what the army requires:", 22)
	say.autowrap_mode = TextServer.AUTOWRAP_WORD
	say.custom_minimum_size = Vector2(480, 0)
	say.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(say)
	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 22)
	vb.add_child(items)
	for t in mil.order["need"]:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(UiKit.tex(str(t), 64))
		var ql := UiKit.dark_label("x%d" % int(mil.order["need"][t]), 26)
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ql)
		items.add_child(col)
	var terms := HBoxContainer.new()
	terms.alignment = BoxContainer.ALIGNMENT_CENTER
	terms.add_theme_constant_override("separation", 30)
	vb.add_child(terms)
	var time_l := UiKit.label("", 26, UiKit.BLUE, 0)
	var pay_l := UiKit.label("", 30, UiKit.GREEN, 0)
	terms.add_child(time_l)
	terms.add_child(pay_l)
	var refresh := func() -> void:
		var secs := int(float(mil.order["time"]))
		time_l.text = "Time: %d:%02d" % [secs / 60, secs % 60]
		pay_l.text = "Pay: $" + Game.fmt(int(mil.order["reward"]))
	refresh.call()
	var left := UiKit.label("", 16, Color(0.5, 0.46, 0.6), 0)
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(left)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	var acc := UiKit.button("Accept", UiKit.GREEN, Vector2(150, 62), 24)
	var more_m := UiKit.button("More money", UiKit.ORANGE, Vector2(160, 62), 22)
	var more_t := UiKit.button("More time", UiKit.BLUE, Vector2(150, 62), 22)
	var dec := UiKit.button("Decline", UiKit.RED, Vector2(130, 62), 22)
	row.add_child(acc)
	row.add_child(more_m)
	row.add_child(more_t)
	row.add_child(dec)
	var upd_left := func() -> void:
		var n := Military.MAX_HAGGLES - mil.haggles
		left.text = "Haggles left: %d  (he gets angrier every time you push)" % n
		more_m.disabled = n <= 0
		more_t.disabled = n <= 0
	upd_left.call()
	var do_haggle := func(kind: String) -> void:
		var res: Dictionary = mil.haggle(kind)
		say.text = str(res["line"])
		Sfx.play("unlock" if bool(res["ok"]) else "nope", -5.0)
		if bool(res["left"]):
			close_modal()
			toast("General Coo stormed off! No deal this time.", "ui_close")
			return
		refresh.call()
		upd_left.call()
	var on_money := func() -> void:
		do_haggle.call("money")
	var on_time := func() -> void:
		do_haggle.call("time")
	var on_accept := func() -> void:
		mil.accept()
		close_modal()
	var on_decline := func() -> void:
		mil.decline()
		close_modal()
	var on_closed := func() -> void:
		# closing the window without choosing counts as declining
		if mil.state == "offer":
			mil.decline()
	more_m.pressed.connect(on_money)
	more_t.pressed.connect(on_time)
	acc.pressed.connect(on_accept)
	dec.pressed.connect(on_decline)
	_modal.tree_exiting.connect(on_closed)


# ------------------------------------------------------------ Crow War --
var _fader: ColorRect
var _war_panel: PanelContainer
var _war_hp: ProgressBar
var _war_shield: ProgressBar
var _war_clan: ProgressBar
var _war_status: Label
var _shield_row: Control


func _bar(color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(190, 16)
	pb.show_percentage = false
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := UiKit.panel_style(color, 8, 0, Color.BLACK, false)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	pb.add_theme_stylebox_override("fill", fill)
	return pb


func _build_war_panel() -> void:
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 0)
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fader)
	_war_panel = PanelContainer.new()
	_war_panel.position = Vector2(100, 116)
	_war_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_war_panel.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.12, 0.1, 0.18, 0.88), 18))
	root.add_child(_war_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_war_panel.add_child(vb)
	var rows := [["HQ", Color(0.35, 0.9, 0.35)], ["Shield", Color(0.4, 0.7, 1.0)], ["Crow Clan", Color(0.85, 0.2, 0.25)]]
	for r in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		vb.add_child(hb)
		var l := UiKit.label(str(r[0]), 17, Color(1, 1, 1), 4)
		l.custom_minimum_size = Vector2(88, 0)
		hb.add_child(l)
		var pb := _bar(r[1] as Color)
		hb.add_child(pb)
		match str(r[0]):
			"HQ":
				_war_hp = pb
			"Shield":
				_war_shield = pb
				_shield_row = hb
			_:
				_war_clan = pb
	_war_status = UiKit.label("", 17, Color(1, 0.9, 0.5), 4)
	vb.add_child(_war_status)
	_war_panel.visible = false


func _update_war_panel() -> void:
	if Game.world == null or _war_panel == null:
		return
	var cw: CrowWar = Game.world.get("war")
	var show := cw != null and cw.active() and str(Game.world.get("location")) == "hq" and Game.playing and _modal == null
	_war_panel.visible = show
	if not show:
		return
	_war_hp.max_value = cw.max_hp()
	_war_hp.value = cw.hq_hp
	var smax := cw.shield_max()
	_shield_row.visible = smax > 0.0
	_war_shield.max_value = maxf(1.0, smax)
	_war_shield.value = cw.shield_hp
	_war_clan.max_value = 100.0
	_war_clan.value = float(Game.war["strength"])
	match cw.phase:
		"wave":
			_war_status.text = "WAVE %d  -  %d crows" % [cw.wave_number(), cw.alive()]
		"warn":
			_war_status.text = "Wave %d incoming: %ds" % [cw.wave_number(), int(ceil(cw.warn_t))]
		_:
			_war_status.text = "Next wave in %ds" % int(ceil(cw.next_wave))


## Fade the screen to black (true) or back in (false). Awaitable.
func fade(to_black: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 1.0 if to_black else 0.0, 0.35)
	await tw.finished


func war_pad_menu(cw: CrowWar, slot: int) -> void:
	if cw.weapons.has(slot):
		_war_upgrade_menu(cw, slot)
		return
	var vb := _open_modal("WarBuild", "BUILD A DEFENCE", 780)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for t in WarData.WEAPON_ORDER:
		var d: Dictionary = WarData.WEAPONS[t]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.95, 0.93, 0.99), 16, 0, Color.BLACK, false))
		list.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		hb.add_child(UiKit.tex(str(d["icon"]), 58))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		info.add_child(UiKit.dark_label(str(d["name"]), 22))
		var desc := UiKit.label(str(d["desc"]), 16, Color(0.45, 0.42, 0.55), 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(420, 0)
		info.add_child(desc)
		var cost := int(d["cost"])
		var b := UiKit.button("$" + Game.fmt(cost), UiKit.GREEN if Game.money >= cost else UiKit.GREY, Vector2(150, 56), 22)
		var tt: String = t
		b.pressed.connect(func() -> void:
			if cw.build_weapon(slot, tt):
				close_modal()
				toast("%s built!" % str(WarData.WEAPONS[tt]["name"]), str(WarData.WEAPONS[tt]["icon"]))
			else:
				Sfx.play("nope", -6.0))
		hb.add_child(b)


func _war_upgrade_menu(cw: CrowWar, slot: int) -> void:
	var w: HQWeapon = cw.weapons[slot]
	var d: Dictionary = w.def()
	var vb := _open_modal("WarUpgrade", str(d["name"]).to_upper(), 620)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	hb.add_child(UiKit.tex(str(d["icon"]), 96))
	var info := UiKit.dark_label("", 22)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(440, 0)
	hb.add_child(info)
	var btn := UiKit.button("", UiKit.GREEN, Vector2(260, 64), 24)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(btn)
	var refresh := func() -> void:
		var line := "Level %d / %d\n%s" % [w.level, WarData.MAX_LEVEL, str(d["desc"])]
		if str(d["target"]) != "none":
			line += "\nDamage %.1f  -  range %d m" % [w.damage(), int(w.range_m())]
		info.text = line
		if w.level >= WarData.MAX_LEVEL:
			btn.text = "MAX LEVEL"
			btn.disabled = true
		else:
			var c := WarData.upgrade_cost(w.type, w.level)
			btn.text = "Upgrade  $" + Game.fmt(c)
			UiKit.style_button(btn, UiKit.GREEN if Game.money >= c else UiKit.GREY)
	refresh.call()
	btn.pressed.connect(func() -> void:
		if cw.upgrade_weapon(slot):
			refresh.call()
		else:
			Sfx.play("nope", -6.0))


func war_command_menu(cw: CrowWar) -> void:
	var vb := _open_modal("WarCommand", "COMMAND CENTER", 700)
	var rows: Array[Dictionary] = []
	for k in WarData.HQ_UPGRADE_ORDER:
		var d: Dictionary = WarData.HQ_UPGRADES[k]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.93, 0.95, 1.0), 16, 0, Color.BLACK, false))
		vb.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		hb.add_child(UiKit.tex(str(d["icon"]), 54))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		info.add_child(UiKit.dark_label(str(d["name"]), 22))
		var lvl := UiKit.label("", 16, Color(0.45, 0.42, 0.55), 0)
		info.add_child(lvl)
		var b := UiKit.button("", UiKit.GREEN, Vector2(150, 54), 22)
		hb.add_child(b)
		rows.append({"k": k, "lvl": lvl, "btn": b})
	var refresh := func() -> void:
		for r in rows:
			var k: String = r["k"]
			var d: Dictionary = WarData.HQ_UPGRADES[k]
			var lv := cw.upg(k)
			(r["lvl"] as Label).text = "%s  (level %d / %d)" % [str(d["desc"]), lv, int(d["max"])]
			var b: Button = r["btn"]
			if lv >= int(d["max"]):
				b.text = "MAX"
				b.disabled = true
			else:
				var c := WarData.hq_upgrade_cost(k, lv)
				b.text = "$" + Game.fmt(c)
				UiKit.style_button(b, UiKit.GREEN if Game.money >= c else UiKit.GREY)
	for r in rows:
		var key: String = r["k"]
		(r["btn"] as Button).pressed.connect(func() -> void:
			if cw.buy_hq_upgrade(key):
				refresh.call()
			else:
				Sfx.play("nope", -6.0))
	refresh.call()
