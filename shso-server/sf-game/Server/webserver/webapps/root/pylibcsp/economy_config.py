"""Central configuration for the restored SHSO economy.

This module must remain compatible with the Python 2.2/Jython runtime bundled
with SmartFoxServer. Values marked ``unresolved`` are intentionally easy to
replace when corrected historical values are supplied.
"""

CONFIG_VERSION = 1

CONTENT_POLICY = {
	"respect_catalog_visibility": 1,
	"respect_agent_restrictions": 1,
	"respect_mission_availability": 1,
	"canonical_catalog": "shopping_catalog.json",
	"revival_reference_catalog": "reference/revival/shopping_catalog.json",
}

CURRENCY = {
	"new_account_gold": 0,
	"new_account_fractals": 5000,
}

CATALOG_PRICING = {
	# Enable only when we want these explicit tier mappings reflected in both
	# the database and the client catalog. Runtime purchasing honors the flag.
	"restore_standard_shutdown_tiers": 0,
	"standard_hero_tiers": {
		(80, 800): (100, 1000),
		(240, 2400): (300, 3000),
		(400, 4000): (500, 5000),
		(480, 4800): (600, 6000),
	},
	"hero_overrides": {},
	"allow_zero_price_purchases": 0,
}

# These entries are deliberately excluded from standard tier conversion.
# Their current pairs are structurally exceptional and remain configurable one
# by one through CATALOG_PRICING["hero_overrides"].
EXCEPTIONAL_HEROES = {
	"ant_man": "unresolved",
	"archangel_x_force": "unresolved",
	"blade": "unresolved",
	"captain_america": "unresolved",
	"carnage_playable": "unresolved",
	"cyclops_first": "unresolved",
	"daredevil_shadowland": "unresolved",
	"invisible_woman_future": "unresolved",
	"iron_monger": "unresolved",
	"iron_patriot": "unresolved",
	"jean_grey_phoenix": "unresolved",
	"loki_avengers_playable": "unresolved",
	"mr_fantastic_future": "unresolved",
	"punisher_thunderbolts": "unresolved",
	"ronan": "unresolved",
	"spider_man_assassin": "unresolved",
	"spider_man_bigtime": "unresolved",
	"spider_woman": "unresolved",
	"thing_future": "unresolved",
}

MISSION_REWARDS = {
	# Only the supplied provisional Adamantium value is active. Lower medal
	# values remain zero until the user supplies them.
	"fractals_by_medal": {0: 0, 1: 0, 2: 0, 3: 10},
	"unconfigured_medal_fractals": 0,
	"mission_overrides": {},
	"daily_multiplier": 1.0,
	"score_multiplier": 0.0,
	"xp_per_fractal": 3.0,
	"xp_by_medal": {},
	"survival_score_divisor": 0,
	"fractals_cap": 4000,
	"status": "provisional",
}

MEMBERSHIP = {
	"paid_column_means_agent": 1,
	"agent_fractal_multiplier": 4.0,
	"agent_sources": {
		"mission": 1,
		"zone": 0,
		"achievement": 0,
		"daily": 0,
		"challenge": 0,
		"card_game": 0,
		"mayhem": 0,
	},
}

# Unknown amounts use zero rather than a revival-inflated guess. Each source
# can be enabled by filling its values here without editing endpoint logic.
SOURCE_REWARDS = {
	"zone": {"normal": 0, "golden": 0, "status": "unresolved"},
	"achievement": {"overrides": {}, "status": "existing_data_unverified"},
	"daily": {"overrides": {}, "status": "existing_data_unverified"},
	"challenge": {"overrides": {}, "status": "backup_data_unverified"},
	"card_game": {"overrides": {}, "status": "unresolved"},
	"mayhem": {"overrides": {}, "status": "unresolved"},
}


def is_agent(paid_value):
	if not MEMBERSHIP["paid_column_means_agent"]:
		return 0
	try:
		return int(paid_value) > 0
	except:
		return 0


def agent_multiplier(source_name, paid_value):
	if is_agent(paid_value) and MEMBERSHIP["agent_sources"].get(source_name, 0):
		return float(MEMBERSHIP["agent_fractal_multiplier"])
	return 1.0


def resolve_catalog_prices(hero_name, category, gold_price, fractal_price, price_multiplier):
	gold = int(round(float(gold_price) * float(price_multiplier)))
	fractals = int(round(float(fractal_price) * float(price_multiplier)))
	override = CATALOG_PRICING["hero_overrides"].get(str(hero_name))
	if override is not None:
		return int(override[0]), int(override[1])
	if category == "h" and CATALOG_PRICING["restore_standard_shutdown_tiers"]:
		if str(hero_name) not in EXCEPTIONAL_HEROES:
			restored = CATALOG_PRICING["standard_hero_tiers"].get((gold, fractals))
			if restored is not None:
				return int(restored[0]), int(restored[1])
	return gold, fractals


def mission_reward(mission_id, medal, score, paid_value, is_daily):
	medal_number = int(medal)
	base = MISSION_REWARDS["fractals_by_medal"].get(
		medal_number, MISSION_REWARDS["unconfigured_medal_fractals"])
	override = MISSION_REWARDS["mission_overrides"].get(str(mission_id))
	if override is not None:
		base = override.get("fractals_by_medal", {}).get(medal_number, base)
		if "fractals" in override:
			base = override["fractals"]
	if MISSION_REWARDS["score_multiplier"]:
		base = float(base) + (float(score) * float(MISSION_REWARDS["score_multiplier"]))
	if is_daily:
		base = float(base) * float(MISSION_REWARDS["daily_multiplier"])
	fractals = int(round(float(base) * agent_multiplier("mission", paid_value)))
	cap = int(MISSION_REWARDS["fractals_cap"])
	if cap > 0 and fractals > cap:
		fractals = cap
	xp = MISSION_REWARDS["xp_by_medal"].get(medal_number)
	if xp is None:
		xp = int(round(float(base) * float(MISSION_REWARDS["xp_per_fractal"])))
	return fractals, int(xp)


def source_reward(source_name, reward_key, paid_value):
	source = SOURCE_REWARDS.get(source_name, {})
	amount = source.get(reward_key, 0)
	return int(round(float(amount) * agent_multiplier(source_name, paid_value)))
