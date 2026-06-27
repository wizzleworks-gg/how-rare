# How Rare?

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

- `HowRare/` — the addon itself (this folder name is the WoW AddOn id
  and the SavedVariables key; the displayed title is set by `## Title:` in the TOC).
  - `Data/Meta.lua`, `Data/Rarity.lua` — **generated**, do not hand-edit (baked
    gratz.gg snapshot).
  - `Core.lua` — namespace: region resolution, rarity lookup/colour/format, the
    snapshot-date helpers, draggable-frame persistence.
  - `Tooltip.lua` / `Chat.lua` / `AchievementUI.lua` — the rarity surfaces
    (achievement tooltips, incoming chat announcements, panel-row paint + hover).
  - `Toast.lua` — the earned toast (replaces Blizzard's alert while on) + the
    share/showcase paths.
  - `Options.lua` — SavedVariables defaults, the Settings panel, the `/howrare`
    (`/hw`) slash, the addon-compartment entry.
  - `Bindings.xml` — the "Share rarest achievement" keybind. Auto-loaded from the
    addon root by the client; **must not** be listed in the TOC.
- `scripts/export-addon-data.py` — regenerates `Data/` from the gratz.gg DB
  (dev/CI only — never shipped in the zip).
- `scripts/release.sh` — builds the CurseForge upload zip from the TOC version.

## Conventions

- SavedVariables table: `HowRareDB`. Global debug handle:
  `HowRare` (e.g. `/dump HowRare.RarityCounts`).
- Slash: `/howrare` and `/hw` (`status`, `toast [n|pin]`, `share`, `debug`; bare
  opens options).
- **Naming: brand headline "How Rare?", descriptive subtitle for discovery,
  gratz.gg as data attribution.** The CurseForge/TOC title is **"How Rare? —
  Achievement Rarity"**: "How Rare?" is the brand (and doubles as the tooltip
  question — "How Rare? 3%" — since the name *is* the question a player asks on
  hover), and "Achievement Rarity" rides along as the searchable phrase (CurseForge
  indexes the Name/Summary, not the folder/repo). gratz.gg is the **data** source,
  credited only where it reaches a non-user or answers "where's this number from?"
  — the toast (screenshotted → travels) and the options page — not on the purely
  functional addon-user-only surfaces (the inline % under the icon, the incoming
  chat tag). The internal identity is `HowRare` (folder, `HowRareDB`, globals);
  the slash stays the functional `/howrare` (brand isn't forced onto it). See §11 of
  the architecture doc.
- Interface colours: rarity tiers reuse `ITEM_QUALITY_COLORS` (loot-quality
  bands); the one brand gold is `ffd100` (`G.GOLD`), used for attribution and the
  off-snapshot fallback tint.

## Live WoW client (local testing)

- Install: `/Applications/World of Warcraft/_retail_`.
- Symlink `HowRare/` into `Interface/AddOns/HowRare` so edits
  are live on the next `/reload`. Blizzard ships no default-UI Lua/XML on disk —
  read it from the `Gethe/wow-ui-source` mirror, not the install.
- Lua errors are hidden unless `/console scriptErrors 1` (or BugSack) is on.

## Releasing

Refresh `Data/` from PROD, add a `## <version>` section to `CHANGELOG.md`, bump
`## Version:` in the TOC, then tag `vX.Y.Z` and push the tag — CI builds the zip
and (once `CF_API_KEY` + `CF_PROJECT_ID` are set on the repo) uploads to
CurseForge. Doc/workflow details in `README.md`.
