# HANDOVER — How Rare? polish + reframe

**In-flight theme:** the visual/copy polish pass for How Rare? **and** the how-rare
side of the **gratz.gg → The Wizzleworks** brand reframe. This doc is ephemeral —
**delete it when this pass ships.**

The reframe's full decision record lives in `../gratz-addon/docs/rarity-data-library.md`
(brand model, the embeddable-library plan) and `../gratz-addon/docs/addon-architecture.md`
(the three-product split). The brand: **The Wizzleworks** is the umbrella (org, publisher,
copyright, data owner); gratz.gg is one product under it (the website), **not** the data
owner; the rarity data is credited to **The Wizzleworks**.

> **Status:** everything below is in the working tree but **uncommitted** — pending your
> sign-off + an in-game eyeball. Nothing is committed yet.

## Done (in the working tree)

- **Toast count-form** reads "One of only ~N people" below the **legendary cutoff**
  (`G.TIERS[1].max`, derived so the count-form and the tier can't drift), else "Held by
  X%". "players" → "people".
- **Panel titles colour by rarity tier — ON by default** (`HowRareDB.titleColor`).
  SetVertexColor on `button.Label`; restores Blizzard's white/grey when off.
- **Tooltip rarity line → `Rarity: 3%`** — "Rarity:" white, the % in its tier colour, with
  **a blank line above it** so it sits off from the achievement's own text and always lands
  last. No "?", no brand. `Core.RarityLine(rarity, achievementId)` now builds the coloured
  string itself.
- **Panel % on the header line, left of the points shield** (`AnchorRarity`,
  `RARITY_DX/DY`): one uniform spot for every row — clear of the track control (under icon)
  and the completion date (under shield), stable collapsed or drilled-in. Earned-vs-unearned
  is no basis (earned achievements can be tracked too). The old drill-in float +
  Expand/Collapse hooks were dropped. Offsets are first-cut — tune in-game.
- **Chat enrichment** "(rarity X%)" — label now white, % tier-coloured.
- **Panel-row hover tooltip removed** — this **killed the former "private-frame tooltip"
  item** (it only existed to make that hover taint-safe). The row's rarity affordance is now
  the painted % + (next) the modifier-click toast.
- **gratz.gg stripped from every runtime surface** (tooltip, chat, panel, toast watermark,
  login line) and **swept across the repo**: attribution → **The Wizzleworks** in the TOC
  (Notes + `## Author:`), LICENSE, README, CHANGELOG, CLAUDE.md, the API `source` field, the
  export-script header + the two generated `Data/*.lua` headers. **`## X-Website` removed**
  (funnel destination is an open reframe question). **LICENSE stays ARR** — the app is
  proprietary; only the future extracted library goes permissive. Code comments / DB
  connection strings that name the `gratz` *repo/DB* are kept (structural, not brand).

### Eyeball-pending (gated on your eyes, not throughput)

- Tooltip `Rarity: 3%` colours + the blank-line spacing.
- Panel % on the header line by the shield (`RARITY_DX/DY`): the vertical alignment with the
  header, the gap to the shield, and that it doesn't clash with a long achievement name.
- Toast: the bottom-right is now empty where the watermark was — check the card isn't
  lopsided (the "Earned… · Rarity as of…" stamp is bottom-left); recentre the stamp if so.
- Titles-on-by-default look across a busy category.

## Next — Batch B: modifier-click an achievement → toast preview (agreed, not built)

- **Modifier**, user-settable: a new option **"Preview toast on: Alt-click / Ctrl-click /
  Off"**, default **Alt-click** (Shift is taken by Blizzard's link-into-chat).
- **Where:** **panel rows first**, then **achievement chat links** (standard `SetItemRef`
  hook). Tooltips can't be clicked, so "everywhere" means those two.
- **Behaviour:** preview-only (suppress the row's expand) — **verify taint-safe first**;
  fallback is expand-and-preview.
- **Screenshot:** if the screenshot option is on, the preview captures too
  (`ShowToast(id, HowRareDB.screenshot)`).
- **Discoverability:** explained on the options page (the hover is gone).

## Paused

- **§4 — options explanatory copy + corpus link.** A short rarity explanation + a "How the
  numbers work" copy-popup (addons can't open a browser) + the fuller **"by The Wizzleworks"**
  attribution on the options page (the one surface that still carries the brand). Deferred by
  request.

## Longer-horizon backlog (NOT this pass)

- **Rarity-at-earn** — SV stamp (forward-only) now / server historical curve later. Arch doc
  §6. `Core.AchievementEarnedShort` already extracts the earn date.
- **Sort-by-rarity** — via the API or a panel; the API is the enabler.
- **Flex** — `/howrare flex`, manual + opt-in; lowest priority.
- **Publish** — new CurseForge project; needs its own logo. Release workflow inert until
  `CF_API_KEY` + `CF_PROJECT_ID` are set.
- **Rarity data → embeddable LibStub library** (a Wizzleworks asset; How Rare? the reference
  consumer). The big new direction — see `../gratz-addon/docs/rarity-data-library.md`.
  **"Not now"**: the addon bakes its data inline today.

## In-game testing

- Symlinked: `Interface/AddOns/HowRare` → this repo's `HowRare/`. Editing an already-loaded
  file is fine on `/reload`; a *renamed* addon needs a relog to character-select.
- Slash `/howrare` (`/hr`): `status`, `toast [n|pin]`, `share`, `debug`; bare opens options.
- Lua errors hidden unless `/console scriptErrors 1` (or BugSack).
- API smoke-test: `/dump HowRareAPI:GetMeta()`.
