class_name CrowsNest
extends Node3D
## "Crow's Nest": the TV show where rich pigeons invest in businesses (a
## Shark Tank parody). Built as a studio set far from the bakery; the show
## takes over the camera and runs as one long coroutine: intros, your pitch,
## each investor's verdict, then haggling until there's a deal or no deal.

signal clicked
signal chosen(value: Variant)

const STUDIO := Vector3(0, 0, 150)
const SEAT_X := [-4.8, -1.6, 1.6, 4.8]
const COOLDOWN := 150.0

var world: Node
var cooldown := 0.0
var running := false
var cam: Camera3D
var rigs := {}                 # investor id -> PigeonRig
var host: PigeonRig
var you: HumanRig
var offers := {}               # investor id -> {"amount", "equity", "final"}
var fair := 0
var ask_amount := 0
var ask_equity := 10

var _ui: CanvasLayer
var _root: Control
var _dlg: PanelContainer
var _dlg_pic: TextureRect
var _dlg_name: Label
var _dlg_text: Label
var _panel: Control = null
var _t := 0.0


func _init(w: Node) -> void:
	world = w


func _ready() -> void:
	position = STUDIO
	_build_set()
	visible = false


# ------------------------------------------------------------------ set --
func _build_set() -> void:
	MeshBuilder.node(Models.cached("studio", func() -> ArrayMesh:
		var b := MeshBuilder.new()
		b.cyl(10.0, 10.0, 0.12, Vector3(0, 0.06, -1), Color(0.22, 0.16, 0.14), Vector3.ZERO, 32)
		b.cyl(9.2, 9.2, 0.02, Vector3(0, 0.125, -1), Color(0.34, 0.24, 0.18), Vector3.ZERO, 32)
		b.cyl(1.2, 1.2, 0.02, Vector3(0, 0.14, 2.2), Models.C_GOLD, Vector3.ZERO, 5)
		# backdrop wall + giant nest
		b.box(Vector3(20, 7, 0.4), Vector3(0, 3.5, -7.5), Color(0.12, 0.14, 0.3))
		b.box(Vector3(20, 0.3, 0.5), Vector3(0, 0.15, -7.3), Models.C_GOLD)
		b.torus(2.0, 0.55, Vector3(0, 5.3, -7.0), Color(0.5, 0.33, 0.18), Vector3(70, 0, 0))
		for k in 10:
			var a := k * TAU / 10.0
			b.box(Vector3(1.6, 0.08, 0.08), Vector3(cos(a) * 2.1, 5.3 + sin(a) * 0.7, -6.6), Color(0.42, 0.27, 0.14), Vector3(0, 0, rad_to_deg(a) + 60))
		for k in 3:
			b.sphere(0.35, Vector3(-0.6 + k * 0.6, 5.35, -6.6), Models.C_GOLD, Vector3(0.8, 1.0, 0.8))
		# investor chairs + little tables with cash
		for x in SEAT_X:
			b.box(Vector3(1.3, 0.55, 1.1), Vector3(x, 0.4, -4.2), Color(0.55, 0.12, 0.14))
			b.box(Vector3(1.3, 1.4, 0.25), Vector3(x, 1.1, -4.7), Color(0.5, 0.1, 0.12))
			b.box(Vector3(0.2, 0.9, 1.1), Vector3(x - 0.65, 0.6, -4.2), Color(0.45, 0.09, 0.11))
			b.box(Vector3(0.2, 0.9, 1.1), Vector3(x + 0.65, 0.6, -4.2), Color(0.45, 0.09, 0.11))
		for x in [-3.2, 0.0, 3.2]:
			b.cyl(0.45, 0.45, 0.06, Vector3(x, 0.8, -3.9), Color(0.95, 0.95, 0.97), Vector3.ZERO, 16)
			b.cyl(0.08, 0.12, 0.8, Vector3(x, 0.4, -3.9), Models.C_GOLD, Vector3.ZERO, 8)
			for k in 4:
				b.box(Vector3(0.34, 0.06, 0.18), Vector3(x, 0.86 + k * 0.065, -3.9), Color(0.46, 0.82, 0.36), Vector3(0, k * 17.0, 0))
		# host podium
		b.box(Vector3(1.1, 1.1, 0.7), Vector3(6.2, 0.55, 0.6), Color(0.12, 0.14, 0.3))
		b.box(Vector3(1.2, 0.1, 0.8), Vector3(6.2, 1.12, 0.6), Models.C_GOLD)
		return b.build()), self)
	var title := Fx.label3d("CROW'S NEST", 320, Color(1, 0.8, 0.25), 40)
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	title.position = Vector3(0, 2.6, -7.25)
	add_child(title)
	var sub := Fx.label3d("where rich pigeons make dreams take flight", 90, Color(1, 1, 1), 14)
	sub.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sub.position = Vector3(0, 1.4, -7.25)
	add_child(sub)
	for i in Investors.LIST.size():
		var inv: Dictionary = Investors.LIST[i]
		var r := PigeonRig.new(str(inv["variant"]))
		r.scale = Vector3.ONE * 1.25
		r.position = Vector3(SEAT_X[i], 0.68, -4.1)
		r.rotation.y = PI   # face the stage
		add_child(r)
		rigs[str(inv["id"])] = r
		var tag := Fx.label3d(str(inv["name"]), 34, Color(1, 1, 1), 10)
		tag.position = Vector3(SEAT_X[i], 2.3, -4.1)
		add_child(tag)
	host = PigeonRig.new("host")
	host.scale = Vector3.ONE * 1.3
	host.position = Vector3(6.2, 0, 1.4)
	host.rotation.y = PI * 0.75
	add_child(host)
	you = HumanRig.new("owner")
	you.position = Vector3(0, 0.14, 2.2)
	add_child(you)
	for x in [-6.0, 0.0, 6.0]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(x, 8.5, 2.0)
		sl.rotation_degrees = Vector3(-70, 0, 0)
		sl.spot_range = 16.0
		sl.spot_angle = 38.0
		sl.light_energy = 2.2
		sl.light_color = Color(1.0, 0.92, 0.75)
		add_child(sl)
	cam = Camera3D.new()
	cam.fov = 45.0
	add_child(cam)


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if not visible:
		return
	_t += delta
	var i := 0
	for id in rigs:
		(rigs[id] as PigeonRig).animate(delta, 0.0, "idle" if int(_t * 0.4 + i) % 3 != 0 else "peck")
		i += 1
	host.animate(delta, 0.0, "idle")
	you.animate(delta, 0.0)


# ----------------------------------------------------------------- show --
func start() -> void:
	if running or cooldown > 0.0:
		return
	running = true
	visible = true
	world.get("player").set("locked", true)
	if Game.hud != null:
		Game.hud.visible = false
	cam.current = true
	_shot_now("wide")
	_build_ui()
	Sfx.play("fanfare", -2.0)
	_run()


func _run() -> void:
	fair = Investors.fair_value()
	offers.clear()
	Game.log_line("[nest] show starts, fair value $%d" % fair)
	await _say("host", "Chip Chirpley", "Welcome to CROW'S NEST! Where rich pigeons decide if your dream takes flight... or gets plucked!")
	await _say("host", "Chip Chirpley", "Tonight's entrepreneur runs %s, the hottest bakery in pigeon history!" % Game.company)
	for inv in Investors.LIST:
		await _shot(str(inv["id"]))
		await _say(str(inv["id"]), str(inv["name"]), str(inv["intro"]))
	await _shot("player")
	var pitch: Array = await _pitch_panel()
	ask_amount = int(pitch[0])
	ask_equity = int(pitch[1])
	await _say("player", Game.company, "Investors, I'm asking for $%s for %d%% of my company. Let's take pigeon bread GLOBAL!" % [Game.fmt(ask_amount), ask_equity])
	# verdicts
	for inv in Investors.LIST:
		var id := str(inv["id"])
		var verdict := _decide(inv)
		await _shot(id)
		Game.log_line("[nest] %s -> %s" % [id, str(verdict)])
		match str(verdict["kind"]):
			"offer":
				offers[id] = {"amount": ask_amount, "equity": ask_equity, "final": false}
				await _say(id, str(inv["name"]), str(inv["offer"]))
			"counter":
				offers[id] = {"amount": ask_amount, "equity": int(verdict["equity"]), "final": false}
				await _say(id, str(inv["name"]), "%s\n$%s for %d%%." % [str(inv["counter"]), Game.fmt(ask_amount), int(verdict["equity"])])
			_:
				await _say(id, str(inv["name"]), str(inv["out"]))
	# haggling
	while true:
		if offers.is_empty():
			await _shot("wide")
			await _say("host", "Chip Chirpley", "Ouch! Every investor is out. No deal tonight... but come back next season with bigger numbers!")
			_end(false)
			return
		await _shot("wide")
		var choice: Dictionary = await _offers_panel()
		var action := str(choice["action"])
		if action == "walk":
			await _say("player", Game.company, "Thank you, but I believe in my bakery more than that. I'm walking away!")
			await _say("host", "Chip Chirpley", "Bold move! No deal tonight. The Crow's Nest will be waiting next season!")
			_end(false)
			return
		var id := str(choice["id"])
		var inv := Investors.by_id(id)
		var o: Dictionary = offers[id]
		if action == "accept":
			await _deal(inv, o)
			return
		# counter
		var want := int(choice["want"])
		await _say("player", Game.company, "%s, would you do it for %d%%?" % [str(inv["name"]).split(" ")[0], want])
		await _shot(id)
		var chance := clampf((1.0 - float(inv["stubborn"])) * 1.1 - float(int(o["equity"]) - want) / 100.0, 0.1, 0.85)
		if randf() < chance:
			o["equity"] = want
			await _say(id, str(inv["name"]), str(inv["yes"]))
		elif randf() < 0.5:
			o["final"] = true
			await _say(id, str(inv["name"]), str(inv["no"]))
		else:
			offers.erase(id)
			await _say(id, str(inv["name"]), str(inv["leave"]))


func _decide(inv: Dictionary) -> Dictionary:
	var id := str(inv["id"])
	var implied := float(ask_amount) / (float(ask_equity) / 100.0)
	var bonus := 1.0
	if id == "duchess":
		bonus += minf(0.3, 0.03 * int(Game.military["done"]))
	if id == "goldie" and ask_amount >= fair * 0.2:
		bonus += 0.15
	var value := float(fair) * randf_range(0.9, 1.1) * bonus
	var ratio := implied / value
	if randf() < 0.07:
		return {"kind": "out"}
	var tol := float(inv["tolerance"])
	if ratio > float(inv["counter_limit"]):
		return {"kind": "out"}
	if ratio <= tol and id != "grim":
		return {"kind": "offer"}
	var eq := int(ceil(float(ask_amount) / (value * tol) * 100.0))
	if id == "grim":
		eq = maxi(eq, int(ceil(ask_equity * 1.25)))
	eq = clampi(maxi(eq, ask_equity + 1), 1, 60)
	return {"kind": "counter", "equity": eq}


func _deal(inv: Dictionary, o: Dictionary) -> void:
	var id := str(inv["id"])
	Game.ceo["deal"] = true
	Game.ceo["investor"] = id
	Game.ceo["amount"] = int(o["amount"])
	Game.ceo["equity"] = int(o["equity"])
	Game.set_flag("ceo")
	Game.log_line("[nest] DEAL with %s: $%d for %d%%" % [id, int(o["amount"]), int(o["equity"])])
	Game.add_money(int(o["amount"]))
	Sfx.play("fanfare", 0.0)
	Sfx.play("kaching", -3.0)
	for k in 5:
		Fx.confetti(global_position + Vector3(randf_range(-5, 5), 3.0, randf_range(-4, 2)), 60, 70.0)
	await _say("player", Game.company, "%s, you've got a DEAL! $%s for %d%%!" % [str(inv["name"]), Game.fmt(int(o["amount"])), int(o["equity"])])
	await _shot(id)
	await _say(id, str(inv["name"]), str(inv["deal"]))
	await _shot("wide")
	await _say("host", "Chip Chirpley", "WE HAVE A DEAL! %s is going GLOBAL!" % Game.company)
	Game.save_game()
	_end(true)


func _end(deal: bool) -> void:
	if _ui != null:
		_ui.queue_free()
		_ui = null
	visible = false
	running = false
	var wcam: Camera3D = world.get("cam")
	wcam.current = true
	world.get("player").set("locked", false)
	if Game.hud != null:
		Game.hud.visible = true
	if deal:
		world.call("start_ending")
	else:
		cooldown = COOLDOWN
		Game.log_line("[nest] no deal")


# --------------------------------------------------------------- camera --
func _shot_xf(name_: String) -> Array:
	match name_:
		"wide":
			return [Vector3(0, 6.0, 11.0), Vector3(0, 1.3, -2.5)]
		"player":
			return [Vector3(1.4, 2.4, 6.8), Vector3(0, 1.3, 1.6)]
		"host":
			return [Vector3(3.2, 2.2, 4.6), Vector3(6.2, 1.2, 1.2)]
	var i := 0
	for inv in Investors.LIST:
		if str(inv["id"]) == name_:
			break
		i += 1
	var p := Vector3(SEAT_X[mini(i, 3)], 0, -4.1)
	return [p + Vector3(0.6, 2.2, 4.4), p + Vector3(0, 1.35, 0)]


func _shot_now(name_: String) -> void:
	var xf := _shot_xf(name_)
	cam.position = xf[0]
	cam.look_at(to_global(xf[1]), Vector3.UP)


func _shot(name_: String) -> void:
	var xf := _shot_xf(name_)
	var from_pos := cam.position
	var from_basis := cam.global_basis
	var tmp := Transform3D(Basis.IDENTITY, to_global(xf[0])).looking_at(to_global(xf[1]), Vector3.UP)
	var tw := create_tween()
	var move := func(t: float) -> void:
		var e := t * t * (3.0 - 2.0 * t)
		cam.position = from_pos.lerp(xf[0], e)
		cam.global_basis = Basis(from_basis.get_rotation_quaternion().slerp(tmp.basis.get_rotation_quaternion(), e))
	tw.tween_method(move, 0.0, 1.0, 0.1 if Game.test_mode() else 0.6)
	await tw.finished


# ------------------------------------------------------------------- UI --
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 9
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiKit.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_click)
	_ui.add_child(_root)
	var logo := UiKit.label("CROW'S NEST", 44, Color(1, 0.8, 0.25), 12)
	logo.position = Vector2(20, 12)
	_root.add_child(logo)
	var live := PanelContainer.new()
	live.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	live.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	live.offset_right = -20
	live.offset_left = -20
	live.offset_top = 18
	live.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.85, 0.1, 0.15), 12))
	live.add_child(UiKit.label("LIVE", 22, Color(1, 1, 1), 0))
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(live)
	_dlg = PanelContainer.new()
	_dlg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dlg.offset_left = 24
	_dlg.offset_right = -24
	_dlg.offset_top = -200
	_dlg.offset_bottom = -18
	_dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dlg.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 0.98, 0.94), 28, 6, Color(0.12, 0.14, 0.3)))
	_root.add_child(_dlg)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_dlg.add_child(hb)
	_dlg_pic = UiKit.tex("portrait_host", 140)
	hb.add_child(_dlg_pic)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	_dlg_name = UiKit.label("", 26, Color(0.2, 0.25, 0.55), 0)
	vb.add_child(_dlg_name)
	_dlg_text = UiKit.dark_label("", 24)
	_dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dlg_text.custom_minimum_size = Vector2(300, 0)
	vb.add_child(_dlg_text)
	_dlg.visible = false


func _on_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and _panel == null:
		if _dlg_text.visible_ratio < 1.0:
			_dlg_text.visible_ratio = 1.0
		else:
			clicked.emit()


func _portrait(who: String) -> Texture2D:
	if who == "player":
		return load("res://assets/logo/logo_badge.png")
	if who == "host":
		return Items.icon("portrait_host")
	var inv := Investors.by_id(who)
	return Items.icon(str(inv.get("portrait", "portrait_host")))


func _say(who: String, speaker: String, text: String) -> void:
	_dlg.visible = true
	_dlg_pic.texture = _portrait(who)
	_dlg_name.text = speaker
	_dlg_text.text = text
	_dlg_text.visible_ratio = 0.0
	var tw := _dlg_text.create_tween()
	tw.tween_property(_dlg_text, "visible_ratio", 1.0, 0.018 * text.length())
	if who == "player":
		you.swing()
		Sfx.play("click", -6.0)
	else:
		Sfx.coo(-6.0)
	if Game.test_mode():
		var wait := 1.5 if bool(Game.dev["show_ui"]) else 0.25
		get_tree().create_timer(wait, false).timeout.connect(func() -> void: clicked.emit())
	await clicked


func _make_panel(title: String) -> VBoxContainer:
	_dlg.visible = false
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	_panel = c
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(760, 0)
	p.add_theme_stylebox_override("panel", UiKit.panel_style(Color(1, 0.98, 0.95), 30, 6, Color(0.12, 0.14, 0.3)))
	c.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	var t := UiKit.label(title, 36, Color(0.2, 0.25, 0.55), 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	UiKit.pop(p, 0.7)
	return vb


func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = null


## Pick how much money to ask for and how much of the company to give.
func _pitch_panel() -> Array:
	var vb := _make_panel("YOUR PITCH")
	var info := UiKit.dark_label("The investors think %s is worth about $%s." % [Game.company, Game.fmt(fair)], 22)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	var amounts: Array[int] = []
	for f in [0.05, 0.1, 0.15, 0.25, 0.4]:
		amounts.append(Game.nice_number(fair * f))
	var equities := [5, 10, 15, 20, 25, 30, 40, 50]
	var sel := {"a": 1, "e": 1}
	vb.add_child(UiKit.dark_label("I'm asking for:", 22))
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_CENTER
	arow.add_theme_constant_override("separation", 8)
	vb.add_child(arow)
	vb.add_child(UiKit.dark_label("In exchange for this much of my company:", 22))
	var erow := HBoxContainer.new()
	erow.alignment = BoxContainer.ALIGNMENT_CENTER
	erow.add_theme_constant_override("separation", 6)
	vb.add_child(erow)
	var verdict := UiKit.label("", 22, UiKit.GREEN, 0)
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(verdict)
	var abtns: Array[Button] = []
	var ebtns: Array[Button] = []
	var refresh := func() -> void:
		for i in abtns.size():
			UiKit.style_button(abtns[i], UiKit.GREEN if i == int(sel["a"]) else UiKit.GREY)
		for i in ebtns.size():
			UiKit.style_button(ebtns[i], UiKit.BLUE if i == int(sel["e"]) else UiKit.GREY)
		var implied := float(amounts[int(sel["a"])]) / (float(equities[int(sel["e"])]) / 100.0)
		var r := implied / float(fair)
		var mood := "fair: good chance of a deal"
		var col := UiKit.GREEN
		if r > 2.2:
			mood = "way too high: they'll probably all walk"
			col = UiKit.RED
		elif r > 1.35:
			mood = "ambitious: expect counter-offers"
			col = UiKit.ORANGE
		elif r < 0.8:
			mood = "a bargain for them: easy deal, but you give away a lot"
			col = UiKit.BLUE
		verdict.text = "That values your company at $%s (%s)" % [Game.fmt(int(implied)), mood]
		verdict.add_theme_color_override("font_color", col)
	for i in amounts.size():
		var b := UiKit.button("$" + Game.fmt(amounts[i]), UiKit.GREY, Vector2(128, 54), 22)
		var idx := i
		b.pressed.connect(func() -> void:
			sel["a"] = idx
			refresh.call())
		arow.add_child(b)
		abtns.append(b)
	for i in equities.size():
		var b := UiKit.button("%d%%" % equities[i], UiKit.GREY, Vector2(78, 54), 22)
		var idx := i
		b.pressed.connect(func() -> void:
			sel["e"] = idx
			refresh.call())
		erow.add_child(b)
		ebtns.append(b)
	refresh.call()
	var go := UiKit.button("PITCH IT!", UiKit.RED, Vector2(260, 70), 30)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(go)
	go.pressed.connect(func() -> void: chosen.emit([amounts[int(sel["a"])], equities[int(sel["e"])]]))
	if Game.test_mode():
		var wait := 4.0 if bool(Game.dev["show_ui"]) else 0.3
		get_tree().create_timer(wait, false).timeout.connect(func() -> void: chosen.emit([amounts[1], 10]))
	var v: Variant = await chosen
	_close_panel()
	return v


## Standing offers: accept one, counter, or walk away.
func _offers_panel() -> Dictionary:
	var vb := _make_panel("THE OFFERS")
	var first_id := ""
	for id in offers:
		if first_id.is_empty():
			first_id = str(id)
		var inv := Investors.by_id(str(id))
		var o: Dictionary = offers[id]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiKit.panel_style(Color(0.93, 0.92, 0.98), 18, 0, Color.BLACK, false))
		vb.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		row.add_child(hb)
		hb.add_child(UiKit.tex(str(inv["portrait"]), 70))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		info.add_child(UiKit.dark_label(str(inv["name"]), 22))
		var terms := "$%s for %d%%" % [Game.fmt(int(o["amount"])), int(o["equity"])]
		if bool(o["final"]):
			terms += "  (final offer)"
		info.add_child(UiKit.label(terms, 24, UiKit.GREEN, 0))
		var acc := UiKit.button("Accept", UiKit.GREEN, Vector2(120, 56), 22)
		var oid := str(id)
		acc.pressed.connect(func() -> void: chosen.emit({"action": "accept", "id": oid}))
		hb.add_child(acc)
		var want := maxi(ask_equity, int(round((int(o["equity"]) + ask_equity) / 2.0)))
		if want >= int(o["equity"]):
			want = int(o["equity"]) - 1
		var can_counter := not bool(o["final"]) and int(o["equity"]) > ask_equity and want >= 1
		var ctr_text := "Counter %d%%" % want
		if int(o["equity"]) <= ask_equity:
			ctr_text = "Your terms!"
		elif bool(o["final"]):
			ctr_text = "Final offer"
		var ctr := UiKit.button(ctr_text, UiKit.ORANGE if can_counter else UiKit.GREY, Vector2(170, 56), 22)
		ctr.disabled = not can_counter
		var w := want
		ctr.pressed.connect(func() -> void: chosen.emit({"action": "counter", "id": oid, "want": w}))
		hb.add_child(ctr)
	var walk := UiKit.button("Walk away", UiKit.RED, Vector2(200, 58), 22)
	walk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	walk.pressed.connect(func() -> void: chosen.emit({"action": "walk"}))
	vb.add_child(walk)
	if Game.test_mode() and not bool(Game.dev["show_ui"]):
		var fid := first_id
		get_tree().create_timer(0.3, false).timeout.connect(func() -> void: chosen.emit({"action": "accept", "id": fid}))
	var v: Variant = await chosen
	_close_panel()
	return v
