class_name WarData
extends RefCounted
## The Crow War (post-CEO campaign): pigeon weapons, enemy crows, HQ upgrades.

## target: "ground", "air" or "all". rate = seconds between shots.
const WEAPONS := {
	"slingshot": {"name": "Seed Slingshot MkII", "icon": "turret", "cost": 150000, "target": "all",
		"dmg": 1.5, "rate": 0.8, "range": 13.0, "desc": "Reliable seed flinger. Hits ground and air."},
	"baguette": {"name": "Baguette Cannon", "icon": "w_baguette", "cost": 600000, "target": "ground",
		"dmg": 7.0, "rate": 2.4, "range": 17.0, "splash": 2.5, "desc": "Lobs exploding baguettes at ground crows."},
	"flak": {"name": "Feather Flak", "icon": "w_flak", "cost": 1200000, "target": "air",
		"dmg": 1.2, "rate": 0.18, "range": 19.0, "desc": "Rapid-fire feathers. Shreds poop bombers."},
	"sonic": {"name": "Coo-Coo Sonic Tower", "icon": "w_sonic", "cost": 2500000, "target": "all",
		"dmg": 3.0, "rate": 3.0, "range": 9.0, "aoe": true, "desc": "A mighty COO shockwave: damages and slows everything nearby."},
	"missile": {"name": "Birdseed Missile Silo", "icon": "w_missile", "cost": 5000000, "target": "all",
		"dmg": 18.0, "rate": 4.0, "range": 34.0, "desc": "Homing seed missiles. Loves big targets."},
	"shield": {"name": "Umbrella Shield Dome", "icon": "w_shield", "cost": 8000000, "target": "none",
		"dmg": 0.0, "rate": 3.0, "range": 11.0, "desc": "Giant umbrella dome that blocks poop bombs near the tower."},
	"hangar": {"name": "Pigeon Air Squadron", "icon": "w_hangar", "cost": 12000000, "target": "air",
		"dmg": 2.5, "rate": 0.6, "range": 14.0, "desc": "Three goggled pigeon aces that dogfight crows in the sky."},
	"tank": {"name": "Pigeon Tank Battalion", "icon": "w_tank", "cost": 20000000, "target": "ground",
		"dmg": 5.0, "rate": 1.4, "range": 12.0, "desc": "Two pigeon-driven tanks that hunt ground crows."},
}
const WEAPON_ORDER: Array[String] = ["slingshot", "baguette", "flak", "sonic", "missile", "shield", "hangar", "tank"]
const MAX_LEVEL := 5

const HQ_UPGRADES := {
	"armor": {"name": "HQ Armor Plating", "icon": "w_armor", "base": 400000, "max": 8, "desc": "+600 tower health"},
	"repair": {"name": "Repair Crew", "icon": "w_repair", "base": 700000, "max": 6, "desc": "Tower repairs itself faster"},
	"power": {"name": "Pigeon Power", "icon": "ui_staff_speed", "base": 250000, "max": 8, "desc": "Your bonks hit harder"},
	"radar": {"name": "Crow Radar", "icon": "w_radar", "base": 300000, "max": 4, "desc": "More warning before each wave"},
}
const HQ_UPGRADE_ORDER: Array[String] = ["armor", "repair", "power", "radar"]


static func upgrade_cost(type: String, level: int) -> int:
	var d: Dictionary = WEAPONS[type]
	return Game.nice_number(float(d["cost"]) * 0.6 * level)


static func hq_upgrade_cost(key: String, level: int) -> int:
	var d: Dictionary = HQ_UPGRADES[key]
	return Game.nice_number(float(d["base"]) * pow(1.9, level))


## Damage / fire-rate multiplier for a weapon level (1..5).
static func level_mult(level: int) -> float:
	return 1.0 + 0.4 * (level - 1)
