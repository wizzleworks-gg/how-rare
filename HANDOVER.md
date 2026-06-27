# HANDOVER — "How Rare?" visual/copy pass

**In-flight theme:** the visual/copy polish pass for the How Rare? addon. Everything
below is **already decided** — build and tune it in-game, don't re-litigate the calls.
This doc is ephemeral: **delete it when the visual/copy pass ships.**

Design rationale for the settled decisions lives in [`CLAUDE.md`](CLAUDE.md) and
`../gratz-addon/docs/addon-architecture.md` (§11 naming, §12 publishing).

## Where things stand (built, committed, pushed — `main` @ how-rare)

- Rarity carved out of the gratz-addon monolith: tooltip / chat / panel-row paint /
  earned toast surfaces, over baked gratz.gg data.
- **Public API** `HowRareAPI` (+ `HowRareApi` casing alias) — read-only, versioned.
- **Scope toggle** region (default) / global. Realm deliberately absent — rarity has no
  per-realm data (region/global only), and per-realm counts can't be baked (size).
- **6-tier scale:** legendary `<0.1%`, epic `<5%`, rare `<15%`, uncommon `<40%`,
  common `<70%`, junk (grey) `≥70%`.
- **Brand:** "How Rare?" — folder `HowRare`, `HowRareDB`, globals `HowRare`/`HowRareAPI`,
  slash `/howrare` (`/hr`). Tooltip text already reads `How Rare? 3% · gratz.gg`.

## The queued pass — 6 items, all decided

### Iteration-gated (build → load in-game → tune; gated on your eyes, not throughput)

1. **Tooltip colour separation.** Text is done (`Core.RarityLine`), but renders
   single-colour. Target: "How Rare?" muted grey · the **%** in its tier colour · "·
   gratz.gg" dim. Needs `RarityLine` to build the multi-colour string (likely take the
   achievementId/hex), and the callers (`Tooltip.lua`, `AchievementUI.lua` `OnRowEnter`)
   to `AddLine` with a neutral base instead of the tier colour. Eyeball the
   "?"-next-to-number spacing — options floated: colour-break alone (try first), em-dash
   `How Rare? — 3%`, or arrow `→`; sentence-case "how rare?" reads more like a question,
   title-case holds the brand.

2. **Panel drill-in: float the % to the bottom.** `AchievementUI.lua` `PaintRarity`
   anchors the % under the icon; in the *expanded/drill-in* state it collides with the
   track control. Decision: **keep** the % (do not delete), but on drill-in move it to the
   bottom of the row, clear of the track control; collapsed list rows keep the under-icon
   %. Pixel anchors need in-game eyeballing.

3. **Private-frame tooltip (toggleable).** The panel-row hover hand-rolls a
   `GameTooltip:SetOwner`. Rework to the Overachiever/Krowi pattern — a private,
   taint-safe tooltip frame anchored *beside* the row so it never covers it — and gate it
   behind an option so it never wars with other addons. Reference:
   `Interface/AddOns/Overachiever2/Tooltips.lua` (private `OA2Tooltip` sidecar). Note: we
   **can't** inject our line into Overachiever/Krowi tooltips (they build lines manually,
   bypassing the data pipeline — that's what the public API is for). IAT appends our line
   automatically *only* because it uses `GameTooltip:SetHyperlink`, the standard data path
   our `TooltipDataProcessor` post-call hooks.

4. **Options explanatory copy + corpus link.** Add to the Settings panel: a short
   explanation of rarity + a "How the numbers work" button that pops a copyable
   `gratz.gg/about/numbers` URL (addons can't open a browser → copy-popup). Settings API
   is text-constrained (short header lines + buttons). Draft (mirror the site's wording):
   "Rarity is the share of active accounts that have earned an achievement. Measured
   across the characters gratz.gg tracks. Each update is a fresh snapshot. Based on N
   active [scope] accounts · as of [date]." The denominator text should follow the scope
   toggle.

### Mechanical (no iteration — safe to do blind)

5. **Toast count-form at `<0.1%` + "people".** `Toast.lua`: `COUNT_BELOW_PCT` is `5`; tie
   the "One of only ~N players" form to `<0.1%` (the legendary cutoff) and change
   "players" → "people". At/above it, "Held by X%". Why: at <5% the count was unimpressive
   (~19k); at <0.1% it's genuinely tiny (<~480), so the brag lands.

6. **Title-colour option (default OFF).** An opt-in Settings toggle to colour the
   achievement *title* text in the panel by rarity tier (`G.RarityColor`). Default off —
   at median 18.5% rarity, colouring every title is a rainbow.

## Longer-horizon backlog (NOT this pass)

- **Rarity-at-earn** — SV stamp (forward-only, cheap) now / server historical curve (true,
  retroactive) later. Architecture doc §6. `Core.AchievementEarnedShort` already extracts
  the earn date.
- **Sort-by-rarity** — via the API (offer it to the AlmostCompletedAchievements author) or
  build a panel; the API is the enabler.
- **Flex** — `/howrare flex`, manual + opt-in chat post; lowest priority. Competitive flex
  belongs to the board, not here.
- **Publish** — new CurseForge project; needs its own logo (not the Gratz one). The release
  workflow is inert until `CF_API_KEY` + `CF_PROJECT_ID` are set on the repo.

## In-game testing

- Symlinked: `Interface/AddOns/HowRare` → this repo's `HowRare/`. A *renamed* addon needs a
  relog to character-select (not just `/reload`); editing an already-loaded file is fine on
  `/reload`.
- Slash `/howrare` (`/hr`): `status`, `toast [n|pin]`, `share`, `debug`; bare opens options.
- Lua errors hidden unless `/console scriptErrors 1` (or BugSack).
- API smoke-test: `/dump HowRareAPI:GetMeta()`.
