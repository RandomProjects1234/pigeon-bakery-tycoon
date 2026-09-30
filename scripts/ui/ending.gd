class_name Ending
extends CanvasLayer
## The end of the game: "GOING GLOBAL". The company logo pops up in cities
## all over a cartoon world map, then the CEO card with your investor, then
## THE END and the credits.

signal finished

const CONTINENTS := [
	[[0.05, 0.18], [0.16, 0.1], [0.3, 0.12], [0.34, 0.2], [0.29, 0.29], [0.25, 0.38], [0.21, 0.46], [0.17, 0.42], [0.11, 0.34], [0.06, 0.29]],
	[[0.26, 0.5], [0.33, 0.52], [0.38, 0.6], [0.35, 0.72], [0.31, 0.86], [0.28, 0.8], [0.27, 0.66], [0.24, 0.56]],
	[[0.46, 0.17], [0.53, 0.13], [0.59, 0.16], [0.57, 0.28], [0.5, 0.31], [0.46, 0.27]],
	[[0.45, 0.35], [0.56, 0.33], [0.63, 0.44], [0.6, 0.58], [0.55, 0.73], [0.51, 0.7], [0.49, 0.56], [0.44, 0.46]],
	[[0.58, 0.13], [0.75, 0.09], [0.91, 0.15], [0.93, 0.26], [0.86, 0.36], [0.79, 0.43], [0.73, 0.49], [0.66, 0.41], [0.6, 0.34], [0.57, 0.25]],
	[[0.8, 0.64], [0.88, 0.61], [0.93, 0.69], [0.88, 0.77], [0.81, 0.74]],
	[[0.47, 0.19], [0.485, 0.17], [0.495, 0.2], [0.48, 0.225]],
	[[0.88, 0.25], [0.9, 0.26], [0.895, 0.31], [0.88, 0.3]],
]

var _root: Control
var _map: Control
var _pins: Array[Dictionary] = []    # {"pos": Vector2 (0..1), "t": float, "name": String}
var _badge: Texture2D
var _count: Label
var _t := 0.0
var _stage := 0
var mode := "global"     # "global" (the CEO ending) or "war" (Crow Clan defeated)


func _ready() -> void:
	layer = 20
	_badge = load("res://assets/logo/logo_badge.png")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiKit.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.28)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.draw.connect(_draw_map)
	_root.add_child(_map)
	var title := UiKit.label("GOING GLOBAL!", 60, Color(1, 0.8, 0.25), 14)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 14
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(title)
	_count = UiKit.label("", 30, Color(1, 1, 1), 10)
	_count.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_count.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_count.offset_bottom = -24
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_count)
	var skip := UiKit.button("Skip", UiKit.GREY, Vector2(110, 50), 20)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -130
	skip.offset_top = 16
	skip.pressed.connect(_skip)
	_root.add_child(skip)
	if mode == "war":
		title.text = "VICTORY!"
		_count.text = "The Crow Clan is destroyed"
	for i in Investors.CITIES.size():
		var c: Array = Investors.CITIES[i]
		_pins.append({"pos": Vector2(float(c[1]), float(c[2])), "t": 1.2 + i * 0.45, "name": str(c[0])})
	Sfx.play("fanfare", -2.0)


func _process(delta: float) -> void:
	_t += delta
	if _stage == 0 and mode == "war":
		_map.queue_redraw()
		if _t > 1.5:
			_show_war_card()
		return
	if _stage == 0:
		var shown := 0
		for p in _pins:
			var before: bool = _t - delta < float(p["t"])
			if _t >= float(p["t"]):
				shown += 1
				if before:
					Sfx.play("pop", -4.0, 0.9 + shown * 0.03)
		var restaurants := 1 + shown * 25
		var fed := shown * 612000
		_count.text = "Restaurants: %d     Pigeons fed: %s a day" % [restaurants, Game.fmt(fed)]
		_map.queue_redraw()
		if _t > float(_pins[_pins.size() - 1]["t"]) + 2.2:
			_show_ceo()
	elif Game.test_mode() and _t > 3.0 and _stage == 1 and not Game.dev["show_ui"] and mode == "war":
		_finish(false)
	elif Game.test_mode() and _t > 3.0 and _stage == 1:
		if bool(Game.dev["show_ui"]) or OS.get_cmdline_user_args().has("--credits"):
			_show_credits()
		else:
			_finish(false)


func _map_rect() -> Rect2:
	var vs := _root.get_viewport_rect().size
	var w := minf(vs.x * 0.92, (vs.y - 170) * 2.0)
	var h := w * 0.5
	return Rect2((vs.x - w) * 0.5, 90 + (vs.y - 170 - h) * 0.5, w, h)


func _draw_map() -> void:
	var r := _map_rect()
	_map.draw_rect(r.grow(6), Color(1, 1, 1, 0.9))
	_map.draw_rect(r, Color(0.35, 0.62, 0.9))
	for poly in CONTINENTS:
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(r.position + Vector2(float(p[0]), float(p[1])) * r.size)
		_map.draw_colored_polygon(pts, Color(0.55, 0.82, 0.4))
		pts.append(pts[0])
		_map.draw_polyline(pts, Color(0.3, 0.55, 0.25), 3.0, true)
	var f := Fx.font()
	for p in _pins:
		var age := _t - float(p["t"])
		if age < 0.0:
			continue
		var pos: Vector2 = r.position + (p["pos"] as Vector2) * r.size
		var pop := minf(1.0, age * 5.0)
		var s := (1.0 + 0.4 * sin(minf(age, 0.3) / 0.3 * PI)) * pop * 34.0
		_map.draw_circle(pos + Vector2(0, 3), s * 0.55, Color(0, 0, 0, 0.25))
		_map.draw_texture_rect(_badge, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		if age > 0.2:
			_map.draw_string_outline(f, pos + Vector2(-60, s * 0.5 + 18), str(p["name"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 6, Color(0.1, 0.1, 0.2))
			_map.draw_string(f, pos + Vector2(-60, s * 0.5 + 18), str(p["name"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 1, 1))


func _show_ceo() -> void:
	_stage = 1
	_t = 0.0
	Sfx.play("unlock", -2.0)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.12, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(760, 0)
	p.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 0.98, 0.94), 32, 6, UiKit.ORANGE))
	c.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	var t := UiKit.label("CONGRATULATIONS, CEO!", 44, UiKit.ORANGE, 12)
	t.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	vb.add_child(row)
	var inv := Investors.by_id(str(Game.ceo["investor"]))
	row.add_child(_person(_badge, "You", "CEO of " + Game.company))
	row.add_child(UiKit.label("+", 60, UiKit.ORANGE, 0))
	row.add_child(_person(Items.icon(str(inv.get("portrait", "portrait_host"))), str(inv.get("name", "Investor")),
		"%d%% partner" % int(Game.ceo["equity"])))
	var msg := UiKit.dark_label("%s now runs pigeon bakeries in %d cities around the world.\nFrom one wheat field to a global empire. Every pigeon on Earth eats your bread." % [Game.company, Investors.CITIES.size()], 22)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.custom_minimum_size = Vector2(700, 0)
	vb.add_child(msg)
	var nxt := UiKit.button("Continue", UiKit.GREEN, Vector2(220, 64), 26)
	nxt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nxt.pressed.connect(func() -> void:
		dim.queue_free()
		c.queue_free()
		_show_credits())
	vb.add_child(nxt)
	UiKit.pop(p, 0.6)
	for i in 4:
		var tt := get_tree().create_timer(0.3 * i, false)
		tt.timeout.connect(func() -> void: Sfx.play("coin", -6.0, 1.0 + i * 0.1))


func _show_war_card() -> void:
	_stage = 1
	_t = 0.0
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(c)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(760, 0)
	p.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 0.98, 0.94), 32, 6, Color(0.42, 0.5, 0.3)))
	c.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	var t := UiKit.label("THE CROW CLAN IS DEFEATED!", 40, Color(0.42, 0.5, 0.3), 10)
	t.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	vb.add_child(row)
	row.add_child(_person(_badge, "You", "CEO & war hero"))
	row.add_child(_person(Items.icon("portrait_general"), "General Coo", "Pigeon Army"))
	row.add_child(_person(Items.icon("portrait_crow"), "The Crow King", "defeated"))
	var msg := UiKit.dark_label("After %d waves, the skies are clear. %s feeds the whole world, and no crow will ever poop on a pigeon restaurant again." % [int(Game.war["wave"]), Game.company], 22)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.custom_minimum_size = Vector2(700, 0)
	vb.add_child(msg)
	var nxt := UiKit.button("Continue", UiKit.GREEN, Vector2(220, 64), 26)
	nxt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	nxt.pressed.connect(func() -> void:
		c.queue_free()
		_show_credits())
	vb.add_child(nxt)
	UiKit.pop(p, 0.6)


func _person(tex: Texture2D, name_: String, role: String) -> Control:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var pic := TextureRect.new()
	pic.texture = tex
	pic.custom_minimum_size = Vector2(150, 150)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(pic)
	var n := UiKit.dark_label(name_, 22)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(n)
	var r := UiKit.label(role, 18, Color(0.45, 0.42, 0.55), 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(r)
	return vb


func _show_credits() -> void:
	_stage = 2
	for c in _root.get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER_TOP)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	_root.add_child(vb)
	var lines: Array = [
		["THE REAL END" if mode == "war" else "THE END", 90, Color(1, 0.8, 0.25)],
		["", 20, Color.WHITE],
		["PIGEON BAKERY TYCOON", 40, Color(1, 1, 1)],
		["", 10, Color.WHITE],
		["Starring", 22, Color(0.7, 0.7, 0.85)],
		["The Pigeon from the photo, as the company logo", 26, Color(1, 1, 1)],
		["General Coo and the Pigeon Army", 26, Color(1, 1, 1)],
		["The Crow Clans (and their Boss)", 26, Color(1, 1, 1)],
		["The Crow King (retired)" if mode == "war" else "", 26, Color(1, 1, 1)],
		["Chip Chirpley and the investors of Crow's Nest", 26, Color(1, 1, 1)],
		["Thousands of hungry pigeon customers", 26, Color(1, 1, 1)],
		["", 10, Color.WHITE],
		["Company", 22, Color(0.7, 0.7, 0.85)],
		[Game.company, 30, Color(1, 0.8, 0.25)],
		["", 10, Color.WHITE],
		["Made with Godot 4.4  -  Font: Nunito (SIL OFL)", 20, Color(0.8, 0.8, 0.9)],
		["", 30, Color.WHITE],
		["Thanks for playing!", 40, Color(1, 1, 1)],
	]
	for l in lines:
		var lab := UiKit.label(str(l[0]), int(l[1]), l[2] as Color, 6)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(lab)
	var vs := _root.get_viewport_rect().size
	vb.offset_top = vs.y
	var tw := vb.create_tween()
	tw.tween_property(vb, "offset_top", 60.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_bottom = -30
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_root.add_child(row)
	var keep := UiKit.button("Keep playing as CEO", UiKit.GREEN, Vector2(300, 66), 24)
	keep.pressed.connect(func() -> void: _finish(false))
	row.add_child(keep)
	var nb := UiKit.button("New branch", UiKit.ORANGE, Vector2(200, 66), 24)
	nb.pressed.connect(func() -> void: _finish(true))
	row.add_child(nb)
	Sfx.play("fanfare", -4.0)


func _skip() -> void:
	if _stage == 0:
		_show_ceo()


func _finish(new_branch: bool) -> void:
	Game.ceo["seen_end"] = true
	Game.log_line("[end] ending finished, global income $%d/s" % int(Game.world.call("global_income")) if Game.world != null else "[end] done")
	Game.save_game()
	finished.emit()
	if new_branch:
		Game.wipe_progress(true, true)
		get_tree().reload_current_scene()
		return
	queue_free()
	if mode == "war":
		if Game.hud != null:
			Game.hud.call("big_card", "Peace at last!", "The Crow Clan is gone", "Your empire is safe. Keep playing as long as you like.", "ui_crown")
		return
	if Game.test_mode() and OS.get_cmdline_user_args().has("--open-hq") and Game.hud != null:
		Game.hud.call("open_global")
		return
	if Game.hud != null:
		Game.hud.call("big_card", "You're the CEO!", "Global HQ unlocked", "Run all your restaurants from the globe button.", "globe")
