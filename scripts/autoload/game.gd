extends Node
## Global state for Pigeon Bakery Tycoon: money, unlocked zones, upgrades,
## tutorial step, settings, and the JSON save. Registered as the "Game" autoload.

signal money_changed(value: int, delta: int)
signal zone_unlocked(id: String)
signal upgrades_changed
signal flag_set(flag: String)
signal company_changed(name: String)

const SAVE_PATH := "user://save.json"
const START_MONEY := 30
const DEFAULT_COMPANY := "Coo & Crumb Co."

const UPGRADES := {
	"speed": {"name": "Running Shoes", "desc": "Walk faster", "icon": "ui_speed", "max": 10, "base": 60, "growth": 1.75},
	"capacity": {"name": "Bigger Arms", "desc": "Carry 2 more items", "icon": "ui_capacity", "max": 12, "base": 70, "growth": 1.6},
	"profit": {"name": "Secret Recipe", "desc": "Pigeons pay 15% more", "icon": "ui_profit", "max": 10, "base": 150, "growth": 1.85},
	"machine": {"name": "Hotter Ovens", "desc": "Machines work 15% faster", "icon": "ui_machine", "max": 10, "base": 200, "growth": 1.75},
	"staff_speed": {"name": "Staff Sneakers", "desc": "Staff walk faster", "icon": "ui_staff_speed", "max": 8, "base": 400, "growth": 1.8},
	"staff_cap": {"name": "Staff Trays", "desc": "Staff carry 1 more", "icon": "ui_staff_cap", "max": 8, "base": 400, "growth": 1.8},
}
const UPGRADE_ORDER: Array[String] = ["speed", "capacity", "profit", "machine", "staff_speed", "staff_cap"]

var money := START_MONEY
var unlocked := {}        # zone id -> true
var paid := {}            # zone id -> money already poured into its buy zone
var flags := {}           # misc one-shot flags ("first_cash", "won", ...)
var upg := {}
var company := DEFAULT_COMPANY
var tut := 0              # tutorial step (see world/objectives.gd)
var stats := {"served": 0, "earned": 0, "baked": 0, "shooed": 0, "playtime": 0.0,
	"raids": 0, "crows_beaten": 0, "stolen": 0}
var settings := {"music": true, "sfx": true, "shadows": true}
var branch := 1           # "open a new branch" prestige count
var station_state := {}   # station id -> saved piles etc.
## Military contracts: finished/failed counts, reputation with the General,
## and the order in progress (so a reload doesn't lose it).
var military := {"done": 0, "failed": 0, "rep": 0, "order": {}}
var player_pos := Vector2.INF
var saved_at := 0
var loaded_from_save := false

var world: Node = null
var hud: Node = null
var playing := false      # false while the title menu is up

## Dev flags, parsed from the command line after `--`.
var dev := {
	"autoshot": [], "auto": false, "timescale": 1.0, "fresh": false, "money": -1,
	"unlock": "", "bake_icons": false, "log": false, "play": false, "shotdir": "res://shots/",
	"quit_after": -1.0, "cam": "", "pose": "", "menu": false, "allow_save": false, "raid_in": -1.0, "offer_in": -1.0, "show_ui": false,
}

var _save_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in UPGRADE_ORDER:
		upg[k] = 0
	_parse_args()
	if not dev["fresh"] and (not test_mode() or dev["allow_save"]):
		load_game()
	if int(dev["money"]) >= 0:
		money = int(dev["money"])
	Engine.time_scale = float(dev["timescale"])
	get_tree().set_auto_accept_quit(false)


func _process(delta: float) -> void:
	if not playing:
		return
	stats["playtime"] = float(stats["playtime"]) + delta / maxf(Engine.time_scale, 0.001)
	_save_timer += delta
	if _save_timer > 10.0:
		_save_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		save_game()


func test_mode() -> bool:
	var shots: Array = dev["autoshot"]
	return shots.size() > 0 or bool(dev["auto"]) or bool(dev["bake_icons"]) or float(dev["quit_after"]) > 0.0


func log_line(s: String) -> void:
	if bool(dev["log"]):
		print(s)


# ------------------------------------------------------------ economy ----
func add_money(v: int) -> void:
	if v == 0:
		return
	money += v
	if v > 0:
		stats["earned"] = int(stats["earned"]) + v
	money_changed.emit(money, v)


func can_afford(v: int) -> bool:
	return money >= v


func spend(v: int) -> bool:
	if money < v:
		return false
	money -= v
	money_changed.emit(money, -v)
	return true


func set_flag(f: String) -> void:
	if flags.has(f):
		return
	flags[f] = true
	flag_set.emit(f)


func has_flag(f: String) -> bool:
	return flags.has(f)


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = true
	paid.erase(id)
	zone_unlocked.emit(id)
	save_game()


func reqs_met(z: Dictionary) -> bool:
	var req: Array = z["req"]
	for r in req:
		var s := str(r)
		if s.begins_with("flag:"):
			if not flags.has(s.substr(5)):
				return false
		elif not unlocked.has(s):
			return false
	return true


func zone_visible(z: Dictionary) -> bool:
	return not unlocked.has(str(z["id"])) and reqs_met(z)


func zone_cost(z: Dictionary) -> int:
	return int(z["cost"])


func zone_paid(id: String) -> int:
	return int(paid.get(id, 0))


# ----------------------------------------------------------- upgrades ----
func upgrade_level(k: String) -> int:
	return int(upg.get(k, 0))


func upgrade_max(k: String) -> int:
	var d: Dictionary = UPGRADES[k]
	return int(d["max"])


func upgrade_cost(k: String) -> int:
	var d: Dictionary = UPGRADES[k]
	var raw := float(d["base"]) * pow(float(d["growth"]), upgrade_level(k))
	return nice_number(raw)


func buy_upgrade(k: String) -> bool:
	if upgrade_level(k) >= upgrade_max(k):
		return false
	var c := upgrade_cost(k)
	if not spend(c):
		return false
	upg[k] = upgrade_level(k) + 1
	upgrades_changed.emit()
	save_game()
	return true


static func nice_number(v: float) -> int:
	if v < 100.0:
		return int(round(v / 5.0) * 5.0)
	if v < 1000.0:
		return int(round(v / 10.0) * 10.0)
	if v < 10000.0:
		return int(round(v / 50.0) * 50.0)
	return int(round(v / 500.0) * 500.0)


func player_speed() -> float:
	return 4.8 + 0.4 * upgrade_level("speed")


func player_capacity() -> int:
	return 6 + 2 * upgrade_level("capacity")


func branch_mult() -> float:
	return 1.0 + 0.5 * float(branch - 1)


func profit_mult() -> float:
	return (1.0 + 0.15 * upgrade_level("profit")) * branch_mult()


func machine_speed() -> float:
	return 1.0 + 0.15 * upgrade_level("machine")


func staff_speed() -> float:
	return 3.0 + 0.3 * upgrade_level("staff_speed")


func staff_capacity() -> int:
	return 5 + upgrade_level("staff_cap")


## Rounds prices for display: 1250 -> "1.25K".
static func fmt(v: int) -> String:
	var a := absi(v)
	var s := ""
	if a < 10000:
		s = str(a)
	elif a < 1000000:
		s = ("%.1fK" % (a / 1000.0)).replace(".0K", "K")
	else:
		s = ("%.2fM" % (a / 1000000.0)).replace(".00M", "M")
	return ("-" if v < 0 else "") + s


func set_company(n: String) -> void:
	n = n.strip_edges()
	if n.is_empty():
		n = DEFAULT_COMPANY
	company = n.left(24)
	company_changed.emit(company)
	save_game()


# --------------------------------------------------------- save/load -----
func save_game() -> void:
	if (test_mode() and not dev["allow_save"]) or not playing:
		return
	if world != null and world.has_method("collect_state"):
		world.call("collect_state")
	var d := {
		"v": 1, "money": money, "unlocked": unlocked.keys(), "paid": paid, "flags": flags.keys(),
		"upg": upg, "company": company, "tut": tut, "stats": stats, "settings": settings,
		"branch": branch, "stations": station_state, "military": military, "saved_at": int(Time.get_unix_time_from_system()),
	}
	if player_pos != Vector2.INF:
		d["player"] = [player_pos.x, player_pos.y]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	money = int(d.get("money", START_MONEY))
	unlocked.clear()
	for id in d.get("unlocked", []):
		unlocked[str(id)] = true
	paid.clear()
	var p: Dictionary = d.get("paid", {})
	for k in p:
		paid[str(k)] = int(p[k])
	flags.clear()
	for fl in d.get("flags", []):
		flags[str(fl)] = true
	var u: Dictionary = d.get("upg", {})
	for k in UPGRADE_ORDER:
		upg[k] = int(u.get(k, 0))
	company = str(d.get("company", DEFAULT_COMPANY))
	tut = int(d.get("tut", 0))
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = st[k]
	var se: Dictionary = d.get("settings", {})
	for k in se:
		settings[k] = bool(se[k])
	branch = int(d.get("branch", 1))
	station_state = d.get("stations", {})
	var mil: Dictionary = d.get("military", {})
	for k in mil:
		military[k] = mil[k]
	saved_at = int(d.get("saved_at", 0))
	var pl: Array = d.get("player", [])
	if pl.size() == 2:
		player_pos = Vector2(float(pl[0]), float(pl[1]))
	loaded_from_save = true


func wipe_progress(keep_company := true, new_branch := false) -> void:
	var name_keep := company
	var settings_keep := settings.duplicate()
	var branch_keep := branch
	var stats_keep := stats.duplicate()
	money = START_MONEY
	unlocked.clear()
	paid.clear()
	flags.clear()
	for k in UPGRADE_ORDER:
		upg[k] = 0
	tut = 0
	station_state = {}
	military = {"done": 0, "failed": 0, "rep": 0, "order": {}}
	player_pos = Vector2.INF
	settings = settings_keep
	company = name_keep if keep_company else DEFAULT_COMPANY
	if new_branch:
		branch = branch_keep + 1
		stats = stats_keep
		tut = 99   # no tutorial on later branches
		flags["first_cash"] = true
	else:
		branch = 1
		stats = {"served": 0, "earned": 0, "baked": 0, "shooed": 0, "playtime": 0.0,
			"raids": 0, "crows_beaten": 0, "stolen": 0}
	var was_playing := playing
	playing = true
	save_game()
	playing = was_playing


# --------------------------------------------------------------- args ----
func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a: String = args[i]
		var nxt := args[i + 1] if i + 1 < args.size() else ""
		match a:
			"--autoshot":
				var arr: Array = []
				for s in nxt.split(","):
					arr.append(float(s))
				dev["autoshot"] = arr
				i += 1
			"--auto":
				dev["auto"] = true
			"--timescale":
				dev["timescale"] = float(nxt)
				i += 1
			"--fresh":
				dev["fresh"] = true
			"--money":
				dev["money"] = int(nxt)
				i += 1
			"--unlock":
				dev["unlock"] = nxt
				i += 1
			"--bake-icons":
				dev["bake_icons"] = true
			"--log":
				dev["log"] = true
			"--play":
				dev["play"] = true
			"--menu":
				dev["menu"] = true
			"--allow-save":
				dev["allow_save"] = true
			"--show-ui":
				dev["show_ui"] = true
			"--raid-in":
				dev["raid_in"] = float(nxt)
				i += 1
			"--offer-in":
				dev["offer_in"] = float(nxt)
				i += 1
			"--quit-after":
				dev["quit_after"] = float(nxt)
				i += 1
			"--cam":
				dev["cam"] = nxt
				i += 1
			"--pose":
				dev["pose"] = nxt
				i += 1
			"--shotdir":
				dev["shotdir"] = nxt
				i += 1
		i += 1
