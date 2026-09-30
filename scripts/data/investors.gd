class_name Investors
extends RefCounted
## The rich pigeons of Crow's Nest. `tolerance` = how much above the fair value
## they'll accept as-is; `counter_limit` = beyond that they walk; `stubborn` =
## how hard they are to haggle with.

const LIST: Array[Dictionary] = [
	{"id": "reginald", "name": "Sir Reginald Featherstone", "variant": "rich_hat", "portrait": "portrait_reginald",
		"tolerance": 1.3, "counter_limit": 2.3, "stubborn": 0.45,
		"intro": "Old money, old manners. I have invested in every great bakery since 1873. Well, my grandfather did.",
		"offer": "A fine business, young baker. I shall accept your terms. Jolly good!",
		"counter": "Promising, but your valuation is rather... ambitious. I'll do it for more of the company.",
		"out": "Dreadfully overpriced, I'm afraid. For that reason, I'm out.",
		"yes": "Oh, very well. You drive a hard bargain, old chap.",
		"no": "I think not. That is my final offer.",
		"leave": "Such cheek! I withdraw my offer. I'm out.",
		"deal": "Splendid! Let us take this bakery to every city on Earth!"},
	{"id": "goldie", "name": "Goldie McBeak", "variant": "rich_gold", "portrait": "portrait_goldie",
		"tolerance": 1.55, "counter_limit": 2.8, "stubborn": 0.55,
		"intro": "Goldie McBeak. Twelve restaurants, three yachts, one gold chain. I like BIG ideas, baby.",
		"offer": "I love it! Bread for pigeons? That's a money printer. You got a deal on the table!",
		"counter": "I'm feeling it, but I need a bigger slice of this pie. Here's my number.",
		"out": "Nah. Too rich even for MY blood. I'm out.",
		"yes": "Heh. You got guts. Fine!",
		"no": "No way. Take it or leave it, baby.",
		"leave": "Now you're just wasting my time. I'm out!",
		"deal": "LET'S GOOO! Pigeon bread, GLOBAL!"},
	{"id": "duchess", "name": "Duchess Dovington", "variant": "dove", "portrait": "portrait_duchess",
		"tolerance": 1.45, "counter_limit": 2.4, "stubborn": 0.3,
		"intro": "Charmed, darling. I only invest in businesses with heart. And yours feeds soldiers AND pigeons.",
		"offer": "Your little bakery warms my heart. I accept your offer, darling.",
		"counter": "I adore you, darling, but the numbers must make sense. A little more equity, perhaps?",
		"out": "Oh dear. I simply cannot justify that price. I'm out, darling. Good luck.",
		"yes": "For you? Of course, darling.",
		"no": "I'm afraid I can't go lower, darling.",
		"leave": "Oh, darling, now you're being greedy. I'm out.",
		"deal": "Wonderful! Every pigeon in the world deserves your bread."},
	{"id": "grim", "name": "Mr. Grim Quill", "variant": "rich_grim", "portrait": "portrait_grim",
		"tolerance": 1.0, "counter_limit": 1.7, "stubborn": 0.75,
		"intro": "Grim Quill. I don't do feelings. I do numbers. Impress me.",
		"offer": "Hm. The numbers work. For once. You have a deal.",
		"counter": "Your valuation is a fairy tale. Here's what it's really worth. My offer.",
		"out": "You're dreaming. And I don't invest in dreams. I'm out.",
		"yes": "...Fine. But I'll be watching you.",
		"no": "No. And don't ask again.",
		"leave": "Waste of my time. I'm out.",
		"deal": "Good. Now let's crush the competition. Globally."},
]


static func by_id(id: String) -> Dictionary:
	for i in LIST:
		if str(i["id"]) == id:
			return i
	return {}


## Rough company value the investors use as "fair".
static func fair_value() -> int:
	var earned := float(Game.stats["earned"])
	var v := earned * 2.5 + float(Game.stats["served"]) * 25.0 + float(Game.military["done"]) * 15000.0 \
		+ float(Game.upgrade_level("profit")) * 20000.0 + 250000.0
	return Game.nice_number(v)


const CITIES: Array[Array] = [
	["New York", 0.285, 0.305], ["Toronto", 0.27, 0.27], ["Los Angeles", 0.155, 0.34], ["Mexico City", 0.2, 0.42],
	["Rio de Janeiro", 0.355, 0.67], ["Buenos Aires", 0.315, 0.78], ["London", 0.49, 0.215], ["Paris", 0.5, 0.245],
	["Rome", 0.53, 0.285], ["Istanbul", 0.565, 0.275], ["Moscow", 0.585, 0.18], ["Cairo", 0.565, 0.37],
	["Lagos", 0.5, 0.5], ["Cape Town", 0.54, 0.73], ["Dubai", 0.645, 0.395], ["Mumbai", 0.69, 0.43],
	["Singapore", 0.78, 0.525], ["Beijing", 0.81, 0.275], ["Tokyo", 0.885, 0.295], ["Sydney", 0.895, 0.745],
]


static func city_base(i: int) -> float:
	return 30.0 + 6.0 * i


static func city_income(i: int, level: int) -> float:
	return city_base(i) * level


static func upgrade_cost(i: int, level: int) -> int:
	return Game.nice_number(city_base(i) * 90.0 * pow(float(level), 1.7))
