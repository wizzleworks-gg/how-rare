# How Rare?

A World of Warcraft in-game addon that surfaces corpus-derived achievement
**rarity** (the share of accounts that have each achievement) on tooltips, chat
announcements, Blizzard achievement-panel rows, and an earned toast. Lua, packaged
for CurseForge. The rarity numbers come from the **AchievementRarity** library by
the Wizzleworks, which this addon embeds and is the **reference consumer** of.

## Origin

Carved out of the `gratz-addon` monolith (2026-06-27) as the first of a planned
three-addon split — rarity is the horizontal data layer. The board (curated
"Midnight" race, rankings, inspect engine) and an instance-tooltips addon are the
other two; the architecture and the rationale for the split live in
`gratz-addon/docs/addon-architecture.md`. This repo is **rarity only** — no HUD
bar, no curated browser, no scanner/inspect/ranking code.

The rarity **data** was then extracted into its own embeddable LibStub library,
**AchievementRarity** (sibling `achievement-rarity` repo, MIT), with How Rare? as its
reference consumer — the decision + plan are in
`gratz-addon/docs/rarity-data-library.md`. The numbers are produced in the sibling
`gratz` repo (`public.achievement_rarity` + `public.rarity_meta`) and exported into
the library by gratz's `scripts/export-rarity-library.py`; How Rare? embeds a copy of
that library under `HowRare/Libs/` and delegates every rarity lookup to it.

## Layout

- `HowRare/` — the addon itself (this folder name is the WoW AddOn id
  and the SavedVariables key; the displayed title is set by `## Title:` in the TOC).
  - `Libs/` — the embedded **AchievementRarity** library it delegates to: `LibStub/`
    plus `AchievementRarity-1.0/` (the **generated** data snapshot + the read API).
    Do not hand-edit; refresh by re-copying from the `achievement-rarity` repo. These
    load first in the TOC, before `Core.lua`.
  - `Core.lua` — namespace: holds the library handle (`G.AR`) and the `G.*` rarity
    helpers every surface calls, all delegating to the library (the snapshot-date
    helpers, the off-snapshot brand-gold fallback, draggable-frame persistence).
  - `Api.lua` — `HowRareAPI`, a thin back-compat shim forwarding to the library; new
    integrators should use `LibStub("AchievementRarity-1.0")` directly.
  - `Tooltip.lua` / `Chat.lua` / `AchievementUI.lua` — the rarity surfaces
    (achievement tooltips, incoming chat announcements, panel-row paint + hover).
  - `Toast.lua` — the earned toast (replaces Blizzard's alert while on) + the
    share/showcase paths.
  - `Options.lua` — SavedVariables defaults, the Settings panel, the `/howrare`
    (`/hr`) slash, the addon-compartment entry.
  - `Bindings.xml` — the "Share rarest achievement" keybind. Auto-loaded from the
    addon root by the client; **must not** be listed in the TOC.
- `scripts/release.sh` — builds the CurseForge upload zip from the TOC version
  (zips all of `HowRare/`, so the embedded library ships in it).

## Conventions

- SavedVariables table: `HowRareDB`. Global debug handle: `HowRare` (e.g.
  `/dump HowRare.AR:GetMeta()`, or `/dump LibStub("AchievementRarity-1.0"):GetMeta()`).
- Slash: `/howrare` and `/hr` (`status`, `toast [n|pin]`, `share`, `debug`; bare
  opens options).
- **Naming: brand headline "How Rare?", descriptive subtitle for discovery,
  the Wizzleworks as data attribution.** The CurseForge/TOC title is **"How Rare? —
  Achievement Rarity"**: "How Rare?" is the brand (and the question a player asks on
  hover), and "Achievement Rarity" rides along as the searchable phrase (CurseForge
  indexes the Name/Summary, not the folder/repo). The runtime surfaces themselves
  stay **functional and brand-silent**: the tooltip reads `Rarity: 3%`, the panel a
  bare `%`, the chat tag `(rarity 3%)`, and the toast carries no brand — none of them
  advertise. **the Wizzleworks** is the data owner (the umbrella brand; gratz.gg is a
  separate website product, *not* the data owner — see
  `gratz-addon/docs/rarity-data-library.md`), credited only where someone asks
  "where's this from?": the options page (the fuller attribution there is pending —
  the §4 options-copy pass). The internal identity is `HowRare` (folder, `HowRareDB`,
  globals); the slash stays the functional `/howrare`. See §11 of the architecture
  doc.
- Interface colours: rarity tiers (defined in the embedded library) reuse
  `ITEM_QUALITY_COLORS` (loot-quality bands); the one brand gold is `ffd100`
  (`G.GOLD`) — How Rare?'s own, used for attribution and the off-snapshot fallback
  tint (the library returns nil off-snapshot; the gold fallback lives here).

## Live WoW client (local testing)

- Install: `/Applications/World of Warcraft/_retail_`.
- Symlink `HowRare/` into `Interface/AddOns/HowRare` so edits
  are live on the next `/reload`. Blizzard ships no default-UI Lua/XML on disk —
  read it from the `Gethe/wow-ui-source` mirror, not the install.
- Lua errors are hidden unless `/console scriptErrors 1` (or BugSack) is on.
- Library smoke-test: `/dump LibStub("AchievementRarity-1.0"):GetMeta()`.

## Releasing

Update the embedded library (`HowRare/Libs/`, see README "Updating the embedded
library"), add a `## <version>` section to `CHANGELOG.md`, bump `## Version:` in the
TOC, then tag `vX.Y.Z` and push the tag — CI builds the zip and (once `CF_API_KEY` +
`CF_PROJECT_ID` are set on the repo) uploads to CurseForge. Doc/workflow details in
`README.md`.
