# SHSO economy restoration

`economy_config.py` is the single runtime configuration boundary for catalog
pricing, mission rewards, membership benefits, and other reward sources. It is
kept compatible with the SmartFoxServer Jython runtime.

## Known content boundaries

- `shopping_catalog.json` is the active catalog and remains the canonical input.
- `reference/revival/shopping_catalog.json` is the dated revival test catalog.
  It is retained as reference data and is never served by the game endpoint.
- Values marked `unresolved` remain zero or unchanged until corrected values are
  supplied. Server code must not replace them with researched or guessed values.

## Catalog pricing

`restore_standard_shutdown_tiers` is off by default. Turning it on applies only
the four explicit standard mappings in `standard_hero_tiers`. The 19 known
nonstandard dual-currency heroes are excluded and can be configured through
`hero_overrides`. Gold-only, free, hidden, and Agent-only entries are not
converted implicitly.

The active client catalog and database must be updated together before enabling
the switch in production, so displayed and charged prices remain identical.

## Mission rewards

The revival mission-class, team, death, and 3.8x medal formula has been removed.
The supplied provisional Adamantium value is 10 Fractals. Unknown lower medal
values are currently zero and clearly represented in `fractals_by_medal`.
Agent mission earnings use the configured 4x multiplier. The multiplier is not
applied to purchases, refunds, or reward sources whose scope is unresolved.

## Progression and access

Purchases honor catalog visibility and Agent-only flags. Mission turn-in also
requires a currently active, announced mission. This preserves the database's
existing locked-content state instead of exposing the entire content set.

## Database migration

Apply `migrations/001_restore_economy.sql` once to an existing database. New
databases receive the same schema from `shso_db_init.sql`. Existing Fractal,
inventory, hero, and progression rows are not rewritten.
