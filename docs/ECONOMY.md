# SHSO economy restoration

`economy_config.py` is the single runtime configuration boundary for catalog
pricing, mission rewards, membership benefits, starter content, and other reward
sources. It is kept compatible with the SmartFoxServer Jython runtime.

## Known content boundaries

- `shopping_catalog.json` is the active catalog and remains the canonical input.
- `reference/revival/shopping_catalog.json` is the dated revival test catalog.
  It is retained as reference data and is never served by the game endpoint.
- Values marked `unresolved` remain zero or unchanged until corrected values are
  supplied. Server code must not replace them with researched or guessed values.

## Fresh accounts and starter content

The restoration no longer treats a fresh account as an Agent account and no
longer grants the revival-era 5,000 starting Fractals. New-account defaults are
0 Gold, 0 Fractals, and non-Agent. The zero Fractal value is a conservative
restoration default, not a claim that it is the final historical value.

The selected starter quartet is the original pre-Recharged set:

- Ms. Marvel (`ms_marvel`)
- Thing (`thing`)
- Cyclops (`cyclops`)
- Falcon (`falcon`)

The configured starter mission set is:

- Un-Secret Invasion! (`m_1002_1_SuperSkrull001`)
- Bombs Away! (`m_1009_1_GreenGoblin001`)
- Repellent Bugs (`m_1014_1_Annihilus001`)
- Super-Sized and Magnetized! (`m_1005_1_Magneto001`)
- Whack-a-Mole Man! (`m_1020_1_MoleMan001`)

The hero quartet is an intentional restoration choice. The exact late-2016
starter status of the five training missions is less certain, so the set is kept
explicit in `STARTER_CONTENT` and can be revised without changing progression
code.

`migrations/002_fresh_account_progression.sql` changes only future account
defaults and installs an idempotent starter-content trigger. It does not rewrite
existing balances, membership flags, heroes, or owned missions.

Mission ownership is represented by category `m` rows in `inventory`, matching
the existing purchase path. Mission reward turn-in now checks per-player mission
ownership rather than the revival server's global `is_announced` rotation flag.

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

Purchases honor catalog visibility and Agent-only flags. Mission purchases are
persistent inventory unlocks and duplicate mission purchases are rejected.
Mission turn-in requires the mission to be owned by that player. This keeps
regular missions locked until acquired instead of exposing the entire mission
set through a global announcement flag.

## Database migrations

Apply `migrations/001_restore_economy.sql` to an existing database for the core
economy schema, then apply `migrations/002_fresh_account_progression.sql` for
fresh-account defaults and starter seeding. Existing Fractal, inventory, hero,
and progression rows are not rewritten by either migration.
