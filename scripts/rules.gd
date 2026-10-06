class_name CombatRules
extends RefCounted

const WEAPONS = [
{"name":"R-19 / AUTOCANNON", "short":"R-19", "damage":19.0, "interval":0.105, "mag":36, "reserve":288, "reload":1.75, "pellets":1, "spread":0.017, "kick":0.014, "charge":0.0, "color":Color(1.0,0.76,0.38)},
{"name":"K-6 / BREACHER", "short":"K-6", "damage":16.0, "interval":0.88, "mag":8, "reserve":64, "reload":2.15, "pellets":9, "spread":0.09, "kick":0.068, "charge":0.0, "color":Color(1.0,0.42,0.17)},
{"name":"V-3 / COIL LANCE", "short":"V-3", "damage":145.0, "interval":1.3, "mag":5, "reserve":35, "reload":2.4, "pellets":1, "spread":0.002, "kick":0.042, "charge":0.65, "color":Color(0.35,0.9,1.0)}
]

static func damage(base: float, zone: String, kind: String, weapon: int) -> float:
	var multiplier = {"sensor":1.8, "core":1.3, "arm":0.7, "leg":0.8}.get(zone, 1.0)
	var armor = 0.48 if kind in ["heavy", "boss"] and zone != "core" else 1.0
	if weapon == 2: armor = 1.0
	return maxf(0, base * multiplier * armor)

static func reload_transfer(ammo: int, reserve: int, capacity: int) -> Vector2i:
	var moved = mini(maxi(capacity - ammo, 0), maxi(reserve, 0))
	return Vector2i(ammo + moved, reserve - moved)

static func valid_stage(stage: int, interact_distance: float, enemies_alive: int) -> bool:
	return stage >= 0 and stage < 4 and interact_distance < 4.5 and (stage < 3 or enemies_alive == 0)

static func ai_state(visible: bool, distance: float, memory: float, stagger: float, dead: bool) -> String:
	if dead: return "dead"
	if stagger > 0: return "stagger"
	if visible: return "engage" if distance < 24 else "pursue"
	return "search" if memory > 0 else "patrol"
