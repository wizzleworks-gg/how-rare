# Instance rarity — parked spec

Rarity surfaced where players pick content, not just where they browse
achievements: Encounter Journal instance tiles and boss rows, world-map
entrance pins, Group Finder rows. Parked for its own build session; carried
out of the v1 handover when it was deleted (2026-07-17). All decisions below
are probe-era (2026-06), made during the gratz-addon feasibility probe and
not since revisited — re-validate the client-facing ones before building.

## Feasibility (proven, then reverted)

The hover probe (gratz-addon `Probe.lua`, commits `cd19bb6` / `92a308a`,
reverted by design) proved each target surface yields a `journalInstanceID`
and accepts appended `GameTooltip` lines. The code is gone; the git history
is the reference.

## Decisions

- **Baked, hand-curated map** (instance/boss → achievement ids), not a
  runtime criteria walk. Structural links only — rarity is always read live
  from the embedded AchievementRarity library, so a data refresh can never
  desync the map.
- **Derived in-client, not from the gratz DB**: an in-client Encounter
  Journal walk dumps the seed, a human curates and gap-fills, and the result
  is frozen as a bundled Lua table in this repo. The DB route is closed —
  gratz's criteria derive discards criterion type + asset, and the
  `dungeonEncounterID → journalInstanceID` mapping exists only in the client.

## Remaining work

1. The EJ-walk dump tool.
2. Curation / gap-fill of the dumped map.
3. Expansion scope decision: Midnight-only vs all expansions.
4. Port the three surface hooks (`Instance.lua`): EJ tiles/boss rows, map
   pins, Group Finder rows.

## Risk

Encounter Journal ScrollBox frame paths are client-version-specific, and the
boss-row hook is the one surface the probe never exercised — validate both on
a current client before building anything on them. Stay append-only on
already-shown tooltips (taint-safe).

## References

- `../../gratz-addon/docs/addon-architecture.md` §6 / §7 / §11
- `../../gratz-addon/docs/rarity-data-library.md`
