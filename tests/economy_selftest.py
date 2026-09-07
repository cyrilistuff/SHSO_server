import economy_config


def check(actual, expected, label):
	if actual != expected:
		raise AssertionError(label + ": expected " + str(expected) + ", got " + str(actual))


check(economy_config.is_agent(1), 1, "paid account is Agent")
check(economy_config.is_agent(0), 0, "free account is not Agent")
check(economy_config.agent_multiplier("mission", 1), 4.0, "Agent mission multiplier")
check(economy_config.agent_multiplier("zone", 1), 1.0, "unconfirmed source not multiplied")
check(economy_config.mission_reward("example", 3, 999999, 0, 0), (10, 30), "provisional Adamantium")
check(economy_config.mission_reward("example", 3, 999999, 1, 0), (40, 30), "Agent Adamantium")
check(economy_config.mission_reward("example", 2, 999999, 0, 0), (0, 0), "unresolved lower medal")
check(economy_config.resolve_catalog_prices("normal", "h", 80, 800, 1.0), (80, 800), "tier restoration disabled")

economy_config.CATALOG_PRICING["restore_standard_shutdown_tiers"] = 1
check(economy_config.resolve_catalog_prices("normal", "h", 80, 800, 1.0), (100, 1000), "standard tier restored")
check(economy_config.resolve_catalog_prices("captain_america", "h", 80, 2400, 1.0), (80, 2400), "exception left unchanged")

print("economy self-test passed")
