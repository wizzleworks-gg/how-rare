# HANDOVER — rarity data → embeddable library (next theme)

**This theme:** extract the baked rarity **data** out of How Rare? into a standalone,
**embeddable LibStub library** (a Wizzleworks asset). How Rare? becomes its **reference
consumer** — it embeds the library and still works standalone. The library is also
publishable on its own (a side channel for freshness + third-party discovery).

**Read first:** `../gratz-addon/docs/rarity-data-library.md` — the full decision record
(why a library; embed + optional standalone with freshest-wins; the supply-vs-opinionate
API split; permissive licensing; the Wizzleworks brand model). It also amends
`../gratz-addon/docs/addon-architecture.md` §5/§10. **That doc is the *why*; this is the
*how*.** Direction there is the source of truth; the code is the source of truth for what
exists today (the addon bakes its data inline — nothing is extracted yet).

## Previous theme — shipped

The How Rare? polish/copy pass + the gratz.gg → The Wizzleworks reframe + a
review/simplification pass are **committed** on `main` (`075956d`, `3f16689`, `3fa76d5`,
`89ba403`) but **not pushed**. Two loose ends fold into this theme (see "Carried over").

## The seam — what moves, what stays (already roughly built)

The doc's supply-vs-opinionate split maps cleanly onto today's `Core.lua` / `Api.lua`:

- **Raw — the hard contract → library.** `RarityValue` / `RarityCounts` (the `{us,eu,global}`
  count triples) / `Meta.accounts` denominators / `Meta.asOf` / region + scope resolution
  (`region`, `Scope`, `ScopeRegion`, `ScopeIndex`). A consumer must be able to get the **%**
  without ever touching our bands.
- **Opinion — optional helper → library (overridable).** `TIERS` (cut-points + names + the
  loot-quality colours, incl. the junk-grey override) → `RarityTier` / `RarityColor` /
  `RarityHex` / `RarityTextAndColor`, and `FormatPct`. Expose the band table so a consumer
  can re-band from the raw number (the MJE path).
- **Stays in How Rare? (product, not data).** `RarityLine` ("Rarity: 3%"), the toast / panel
  paint / chat / options surfaces, `G.Print`. These are the product's look, not the corpus.
- **Template for the library's public surface:** today's `HowRareAPI` (`Api.lua`) already has
  the right shape — `GetRarity` / `GetCount` / `GetTier` / `GetColor` / `Format` / `GetMeta` /
  `GetTiers` + a `source` field. The library exposes essentially this; How Rare? then wraps or
  drops its own copy.

## Naming (open — author to ratify)

Floated: github repo **`achievement-rarity`**. Recommendation, mirroring the live precedent
**MountsRarity** (a pure-data rarity lib, in the doc's evidence): LibStub name
**`AchievementRarity`**, versioned **`AchievementRarity-1.0`** (no "Lib" prefix). Keeps
"How Rare?" as the *product* brand and names the *library* descriptively (so it's findable
for "rarity"). **Bump the minor on every data refresh** — freshest-wins arbitration keys on
it.

## Concrete steps (sketch)

1. New repo `achievement-rarity`; a LibStub skeleton (`LibStub:NewLibrary("AchievementRarity-1.0", n)`).
2. Retarget the export: `scripts/export-addon-data.py` emits the **library's** data file (the
   `{us,eu,global}` triples + meta), stamped with the minor version.
3. Library exposes the raw getters + the opinion layer (tiers / colours / format),
   `source = "The Wizzleworks"`.
4. How Rare? **embeds** it (`Libs/AchievementRarity-1.0/`, listed in the TOC before `Core.lua`)
   and rewrites `Core`'s rarity helpers to delegate to `LibStub("AchievementRarity-1.0")`. Drop
   the inline `Data/` once delegated.
5. **License the library permissive (MIT)** — *not* ARR (an ARR lib can't legally be embedded,
   which defeats the model). How Rare? the app stays ARR.
6. **Verify byte-identical numbers** before/after — the library's output must match today's
   baked values (the export already proves out against the DB).
7. Publish the standalone CurseForge page once the **API contract** (name + raw/opinion shape)
   is stable — *not* gated on a second consumer (doc §3/§9).

## Carried over from the polish theme (resolve here)

- **"How the numbers work" link** — the deferred §4 options button + its copyable URL. Blocked
  on the **funnel/hub destination** (also why `## X-Website` is empty): gratz.gg vs a
  Wizzleworks hub (doc §6 open sub-question). Decide alongside the library publish; the link
  likely points at wherever the methodology page lands.
- **Push** — `main` has 4 unpushed commits. Pushing doesn't deploy anything on this repo (its
  release is tag-triggered and inert until `CF_API_KEY` + `CF_PROJECT_ID` are set).

## Open decisions (author to ratify — doc §9 + here)

- Exact library + repo name (lead: `AchievementRarity` / `achievement-rarity`).
- Minor-version scheme.
- Exact permissive licence (MIT or another attribution licence).
- When to publish the standalone CurseForge page.
- Funnel/hub destination (the carried-over link).

## In-game testing (unchanged)

- Symlinked: `Interface/AddOns/HowRare` → this repo's `HowRare/`. `/reload` for edits; a
  *renamed* addon needs a relog. An embedded lib is just more files under `HowRare/` — same
  `/reload`.
- API smoke-test: `/dump HowRareAPI:GetMeta()` (and, once embedded,
  `/dump LibStub("AchievementRarity-1.0"):GetMeta()`).
- Lua errors hidden unless `/console scriptErrors 1` (or BugSack).

## Delete me

The polish/reframe theme is shipped; this file now tracks the library-extraction theme.
Delete it when the library ships and How Rare? consumes it.
