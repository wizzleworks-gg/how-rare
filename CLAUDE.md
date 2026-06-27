# Achievement Rarity

A World of Warcraft in-game addon that surfaces gratz.gg's corpus-derived
achievement **rarity** (the share of accounts that have each achievement) on
tooltips, chat announcements, Blizzard achievement-panel rows, and an earned
toast. Lua, packaged for CurseForge. Data ships baked from the gratz.gg DB.

## Origin

Carved out of the `gratz-addon` monolith (2026-06-27) as the first of a planned
three-addon split — rarity is the horizontal data layer. The board (curated
"Midnight" race, rankings, inspect engine) and an instance-tooltips addon are the
other two; the architecture and the rationale for the split live in
`gratz-addon/docs/addon-architecture.md`. This repo is **rarity only** — no HUD
bar, no curated browser, no scanner/inspect/ranking code.

The companion **website** and the **data pipeline** live in the sibling `gratz`
repo. The rarity numbers are produced there (`public.achievement_rarity` +
`public.rarity_meta`) and exported into this addon's `Data/` by
`scripts/export-addon-data.py`.

## Layout

- `AchievementRarity/` — the addon itself (this folder name is the WoW AddOn id
  and the SavedVariables key; the displayed title is set by `## Title:` in the TOC).
  - `Data/Meta.lua`, `Data/Rarity.lua` — **generated**, do not hand-edit (baked
    gratz.gg snapshot).
  - `Core.lua` — namespace: region resolution, rarity lookup/colour/format, the
    snapshot-date helpers, draggable-frame persistence.
  - `Tooltip.lua` / `Chat.lua` / `AchievementUI.lua` — the rarity surfaces
    (achievement tooltips, incoming chat announcements, panel-row paint + hover).
  - `Toast.lua` — the earned toast (replaces Blizzard's alert while on) + the
    share/showcase paths.
  - `Options.lua` — SavedVariables defaults, the Settings panel, the `/rarity`
    (`/ar`) slash, the addon-compartment entry.
  - `Bindings.xml` — the "Share rarest achievement" keybind. Auto-loaded from the
    addon root by the client; **must not** be listed in the TOC.
- `scripts/export-addon-data.py` — regenerates `Data/` from the gratz.gg DB
  (dev/CI only — never shipped in the zip).
- `scripts/release.sh` — builds the CurseForge upload zip from the TOC version.

## Conventions

- SavedVariables table: `AchievementRarityDB`. Global debug handle:
  `AchievementRarity` (e.g. `/dump AchievementRarity.RarityCounts`).
- Slash: `/rarity` and `/ar` (`status`, `toast [n|pin]`, `share`, `debug`; bare
  opens options).
- **Naming: keep the descriptive title; gratz.gg is attribution, not a headline.**
  The addon is titled "Achievement Rarity", not "Gratz". Credit gratz.gg only
  where it reaches a non-user or answers "where's this number from?" — the toast
  (screenshotted → travels) and the options page. Stay silent on the purely
  functional addon-user-only surfaces (inline %, incoming chat tag). See §11 of
  the architecture doc.
- Interface colours: rarity tiers reuse `ITEM_QUALITY_COLORS` (loot-quality
  bands); the one brand gold is `ffd100` (`G.GOLD`), used for attribution and the
  off-snapshot fallback tint.

## Live WoW client (local testing)

- Install: `/Applications/World of Warcraft/_retail_`.
- Symlink `AchievementRarity/` into `Interface/AddOns/AchievementRarity` so edits
  are live on the next `/reload`. Blizzard ships no default-UI Lua/XML on disk —
  read it from the `Gethe/wow-ui-source` mirror, not the install.
- Lua errors are hidden unless `/console scriptErrors 1` (or BugSack) is on.

## Releasing

Refresh `Data/` from PROD, add a `## <version>` section to `CHANGELOG.md`, bump
`## Version:` in the TOC, then tag `vX.Y.Z` and push the tag — CI builds the zip
and (once `CF_API_KEY` + `CF_PROJECT_ID` are set on the repo) uploads to
CurseForge. Doc/workflow details in `README.md`.
