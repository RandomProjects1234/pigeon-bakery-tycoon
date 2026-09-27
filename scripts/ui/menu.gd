class_name Menu
extends CanvasLayer
## Title screen over the live bakery: the company logo (the pigeon photo),
## the game title, a name field for your bakery and a big PLAY button.

signal play_pressed

var _root: Control
var _logo: TextureRect
var _play: Button
var _name: LineEdit
var _t := 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiKit.theme()
	add_child(_root)
	var shade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(0.12, 0.06, 0.24, 0.55), Color(0.12, 0.06, 0.24, 0.15), Color(0.12, 0.06, 0.24, 0.7)])
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	center.add_child(vb)
	_logo = TextureRect.new()
	_logo.texture = load("res://assets/logo/logo_badge.png")
	_logo.custom_minimum_size = Vector2(250, 250)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_logo)
	var t1 := UiKit.label("PIGEON BAKERY", 76, Color(1.0, 0.66, 0.16), 18)
	t1.add_theme_color_override("font_outline_color", Color(1, 1, 1))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t1)
	var ribbon := PanelContainer.new()
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.RED, 14, 4, Color(1, 1, 1)))
	vb.add_child(ribbon)
	var t2 := UiKit.label("  TYCOON  ", 44, Color(1, 1, 1), 10)
	ribbon.add_child(t2)
	var sub := UiKit.label("Bake bread. Feed the flock. Get rich.", 24, Color(1, 1, 1), 8)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vb.add_child(spacer)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	hb.add_child(UiKit.label("Your bakery:", 24))
	_name = LineEdit.new()
	_name.text = Game.company
	_name.max_length = 24
	_name.custom_minimum_size = Vector2(320, 54)
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.placeholder_text = "Name your company"
	hb.add_child(_name)
	var dice := UiKit.button("?", UiKit.PURPLE, Vector2(54, 54), 30)
	dice.tooltip_text = "Random name"
	dice.pressed.connect(func() -> void: _name.text = random_name())
	hb.add_child(dice)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vb.add_child(spacer2)
	_play = UiKit.button("PLAY", UiKit.GREEN, Vector2(320, 96), 52)
	_play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play.pressed.connect(_on_play)
	vb.add_child(_play)
	var info := UiKit.label("Drag anywhere to move  -  WASD / arrow keys work too", 18, Color(1, 1, 1, 0.85), 6)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	if Game.branch > 1:
		var br := UiKit.label("Branch #%d  (+%d%% prices)" % [Game.branch, int((Game.branch_mult() - 1.0) * 100)], 20, Color(1.0, 0.9, 0.4), 6)
		br.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(br)


const NAME_A := ["Coo", "Crumb", "Feather", "Pecky", "Wing", "Birdseed", "Rooftop", "Plaza", "Breadcrumb", "Flock"]
const NAME_B := ["& Crumb Co.", "Bakery", "Loaf Lab", "Bread Barn", "Crumbs Inc.", "Bakehouse", "& Sons", "Deli", "Dough Co.", "Oven Works"]


static func random_name() -> String:
	return "%s %s" % [NAME_A.pick_random(), NAME_B.pick_random()]


func _process(delta: float) -> void:
	_t += delta
	_logo.pivot_offset = _logo.size * 0.5
	_logo.rotation = sin(_t * 1.3) * 0.05
	_logo.scale = Vector2.ONE * (1.0 + sin(_t * 2.1) * 0.02)
	_play.pivot_offset = _play.size * 0.5
	if not _play.is_pressed():
		_play.scale = Vector2.ONE * (1.0 + absf(sin(_t * 3.0)) * 0.05)


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if not _name.has_focus():
			_on_play()


func _on_play() -> void:
	if _name.text.strip_edges() != Game.company:
		Game.set_company(_name.text)
	Sfx.play("unlock", -4.0)
	play_pressed.emit()
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
