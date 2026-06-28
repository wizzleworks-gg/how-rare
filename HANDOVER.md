# HANDOVER — rarity data → embeddable library (BUILT, pending in-game verify + commit)

**This theme:** extract the baked rarity **data** out of How Rare? into a standalone,
**embeddable LibStub library** (a Wizzleworks asset). How Rare? becomes its **reference
consumer** — it embeds the library and still works standalone.

**Status: built locally, NOT committed and NOT in-game verified.** Code/lint pass
(syntax-checked + a Lua delegation-faithfulness harness, 91 assertions green), but only
the author can confirm the in-game surfaces. Nothing is committed in either repo yet.

**Decision record:** `../gratz-addon/docs/rarity-data-library.md` (the *why*). Open
decisions there are now ratified — see below.

## Ratified this session

- **Name:** LibStub `AchievementRarity-1.0`; GitHub repo `achievement-rarity` (sibling of
  `how-rare`/`gratz`). No "Lib" prefix (mirrors MountsRarity).
- **Brand:** **"the Wizzleworks"** — lowercase article, the name is "Wizzleworks". Swept
  through the library + How Rare? (gratz site/docs still say "The Wizzleworks" — the
  deferred ecosystem sweep the decision doc §6 flagged).
- **Licence:** library **MIT** (holder "the Wizzleworks"); How Rare? stays ARR with an
  explicit carve-out for `HowRare/Libs/` (LibStub public-domain, AchievementRarity MIT).
- **Minor-version scheme:** `MINOR = days since 2020-01-01` of the snapshot date
  (freshest-wins keys on it; idempotent on re-export). 2026-06-28 → **2370**.
- **Methodology home:** the library README's "How the numbers work" (adapted from gratz's
  `/about/numbers` page) — decoupled from gratz, as wanted.
- **Scope this build:** extract + embed only. Standalone CurseForge publish and the
  crawler→export→push automation are explicitly **deferred** (separate work).

## What's built (uncommitted)

**`achievement-rarity` repo** (git-initialised, no commits): MIT LICENSE, README (with
methodology), CHANGELOG, `Libs/LibStub/LibStub.lua`, `AchievementRarity-1.0/` (static
`AchievementRarity-1.0.lua` code + generated `AchievementRarity-Data-1.0.lua`), standalone
`AchievementRarity.toc`. Data = **prod snapshot 2026-06-28** (8353 achievements).

**`gratz` repo:** new `scripts/export-rarity-library.py` (retargeted from the old
how-rare exporter; same SQL; emits the library's version-stamped data file; default
`--out` points at the sibling library repo). The old `how-rare/scripts/export-addon-data.py`
+ `requirements.txt` are **deleted** (How Rare? no longer generates data).

**`how-rare` repo (How Rare? = reference consumer):**
- Embeds `HowRare/Libs/LibStub` + `HowRare/Libs/AchievementRarity-1.0` (listed first in the
  TOC, before Core). Inline `HowRare/Data/` **deleted**.
- `Core.lua` holds the stable lib handle `G.AR` and delegates every rarity helper to it
  **live** (a fresher standalone copy can supersede the embedded one at runtime, so we hold
  the handle and call methods live, never caching `GetData()`/`GetMeta()` results). The
  off-snapshot **brand-gold fallback stays in How Rare?**; the library returns nil.
- `Toast.lua` / `Options.lua` repointed off the old `G.RarityCounts`/`G.Meta`/`G.TIERS`
  tables onto live `G.AR:GetData()` / `:GetCount()` / `:GetMeta()` / `:GetTiers()`.
  `Tooltip/Chat/AchievementUI` were helper-only — untouched.
- `Api.lua` (`HowRareAPI`) kept as a thin back-compat shim forwarding to Core/the lib.
- Docs (README, LICENSE, CLAUDE.md, release.sh/yml comments) reframed to the consumer model.

## Next steps

1. **In-game verify** (only the author can): `/reload`, hover a tooltip, open the panel,
   `/howrare` options, `/howrare toast`, `/howrare share`. Confirm numbers/tiers/toast read
   as before and `/dump LibStub("AchievementRarity-1.0"):GetMeta()` works. (Note: numbers
   shifted slightly vs the old baked 06-24 snapshot — this build also refreshed to prod 06-28.)
2. **Commit** both repos once verified (library repo's first commit; how-rare's "adopt the
   AchievementRarity library" commit; gratz's exporter). Nothing pushed yet.
3. **Deferred (own work):** crawler→export→push automation; standalone CurseForge publish;
   the options-page "How the numbers work" link (now points at the library repo — wire once
   the repo is public); the gratz-side "The Wizzleworks → the Wizzleworks" consistency sweep.

## In-game testing (unchanged)

- Symlinked: `Interface/AddOns/HowRare` → this repo's `HowRare/`. `/reload` for edits.
- An embedded lib is just more files under `HowRare/Libs/` — same `/reload`.
- Lua errors hidden unless `/console scriptErrors 1` (or BugSack).

## Delete me

Delete when the library ships (committed + in-game verified + the standalone published).
