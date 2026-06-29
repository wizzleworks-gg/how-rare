# HANDOVER — How Rare? rarity-surface expansion (design revised 2026-06-29)

**This theme:** grow where How Rare? surfaces rarity. A **rarity-at-earn foundation**
(the *rank metric*, gratz-side) feeds **tooltip / chat / toast** surfaces, plus
**rarity on dungeon/raid content** (Encounter Journal, map pins, Group Finder) as a
separate track. All **in How Rare?** (the rarity layer). Design agreed 2026-06-28,
**revised 2026-06-29** — the foundation changed from a client-side stamp to a
gratz-side rank metric (see below). **Track 1 (the foundation) is BUILT + committed
(2026-06-29); surfaces (Track 2) are next, instance rarity (Track 3) is its own session.**

Builds on the architecture doc (`../gratz-addon/docs/addon-architecture.md`): §6
(rarity-at-earn), §7 (instance→achievement map), §3③ (the dropped instance-tooltips
addon), §11 (naming / the toast as the outbound surface), and the reverted hover probe
(`../gratz-addon/docs/dungeon-raid-hover-probe.md`).

## Previous theme — shipped

The rarity-data-library extraction is **committed and pushed**: `achievement-rarity`
(new public MIT library), How Rare? as its reference consumer (`how-rare@6fe4041`),
brand sweep (`gratz-addon@39d95d9`). Deferred loose ends carried at the bottom.

---

## The foundation — the RANK metric (replaces the stamp)

> **Design change 2026-06-29.** The original plan was a client-side *stamp-at-earn*
> (persist the current rarity snapshot into `HowRareDB` on `ACHIEVEMENT_EARNED`,
> forward-only). **Dropped.** It only captured data for achievements earned *after*
> install (the least brag-worthy slice), was usually a no-op (then ≈ now at a live
> earn), grew SavedVariables, and mislabelled "the snapshot shipping when you earned
> it" as historical truth. **Replaced by a gratz-side rank metric** that is
> retroactive, honest, needs no stamp, and needs no SavedVariables.

**The metric: "you were in the first N% to earn this"** — your rank among an
achievement's holders, by earn date. A genuine flex on rare achievements ("first 2%"),
and *nice-to-know* on common ones ("earlier than 60%"), so we ship it for everything.

**Why no stamp is needed.** The game already hands the addon *your* earn date for any
earned achievement (`GetAchievementInfo`, retroactively). Ship the per-achievement
earn-date distribution in the library, and the addon computes your rank on the spot —
for old and new achievements alike. No write at earn, no saved state.

> A population-fraction-at-date curve ("X% of players had it on the day you earned
> it") was **considered and rejected**: the corpus is only *today's* active accounts,
> so it is survivorship-biased and its denominator-over-time is undefined. The rank
> metric sidesteps both — it asks only about the earn-date distribution of an
> achievement's *current* holders, needs no population-at-date denominator, and the
> "first N%" framing is the better brag anyway.

### Storage structure — store the INVERSE (percentile → date breakpoints)

Per achievement, per scope: a small array of **percentile→date breakpoints** — the
date by which 1 / 2 / 3 / … / 100% of current holders had earned it. The addon
binary-searches *your* earn date against these and **interpolates** to a percentile
(output is continuous — you can say "~3%", not just the breakpoint values).

- **~15–20 breakpoints, dense at the rare end** (1,2,3,4,5,7,10,15,20,30,50,75,100…).
  Whole-percent accuracy where the brag lives; coarse in the middle where nobody cares.
  Self-adapting resolution: breakpoints bunch where the curve is steep (flash
  achievements everyone got in week 1) and spread where it's slow — for free.
- **Dates as day-offsets** from the system-launch floor (≈ 2008-10-14, the earliest
  real earn date in the corpus) → small 1–4 digit numbers.
- **Do NOT store a forward daily curve.** 8,000 × ~6,460 days × 3 scopes is ~10 GB as
  DB rows / impossible to ship in-client. The inverse/breakpoint form is smaller,
  self-adapting, and is the metric pre-shaped.

### Scope, coverage, encoding, size (decided)

- **Scope: region + global** (`us`, `eu`, `global`) — same as the rarity counts, so a
  single scope toggle drives both surfaces consistently. (Do **not** drop global from
  rarity to "save space" — that regresses a live feature.)
- **Coverage: all achievements** (not rare-only). "Nice to know" justifies it and the
  size is fine. The only filter is **data quality**: skip achievements with too few
  total holders (noisy percentiles) — a correctness floor, not a coverage cut.
- **Encoding: SHIPPED nested** (`[id]={{us…},{eu…},{global…}}`, a sub-floor scope as
  `{}`). The generated file measured **~1.6 MB** (ranks ~1.4 MB over the counts' 246 KB) —
  comfortably single-digit-MB resident, well under the naive-nested estimate. A
  packed-string / delta-encoding (the RaiderIO technique) stays the lever if it ever grows;
  not needed now. *(WoW loads addon data by parsing the
  whole Lua file into memory at load — no lazy per-entry disk read — so resident
  memory is the constraint; encoding is the lever. For reference: ATT holds 100+ MB,
  RaiderIO tens of MB. Single-digit MB here is unremarkable.)*
- **Baseline:** today's `AchievementRarity-Data-1.0.lua` is 246 KB (8,353 entries ×
  `{us,eu,global}` counts).

### Bad-date floor (decided)

The game's earn date is unreliable for very old **account-wide** achievements —
back-credited to the system-launch floor (≈ 2008-10-14) in a pile-up, or zero/empty.
**Rule:** if the earn date is at/below the launch floor (a **FIXED constant, 14 Oct 2008
/ patch 3.0.2** — *not* the corpus minimum, which a stray zero/garbage date would drag
too low) or zero, **suppress** the rank line *and* the "~X ago". The dev run confirmed the
observed corpus-min earn date == the fixed floor, validating the constant.

### Building it gratz-side — folds into the existing nightly rarity pass

**Not a new pipeline, and not the billion-row nightly churn it looks like.** The
existing `scripts/rarity-counter.py` already streams the whole active corpus once a
night ("offline cadence, single-core-polite, speed doesn't matter") to build the
current rarity snapshot. The rank metric rides on the **same single pass**:

- The unit of work is **~896K active-account representatives** (deduped by fingerprint,
  one max-achievement alt each, active in 30 days) — *not* the 9.5M character rows.
  (Measured on prod 2026-06-29: 9.5M chars / 62 GB; 3.3M carry a bitmap; ~896K reps;
  ~2,640 earned achievements/account avg; earn dates span 2008-10-14 → today.)
- Each rep's per-achievement earn timestamps already sit **materialized** in
  `blizzard_profile.character.earned_at[]`, aligned to the membership bitmap (gratz
  migrations 024/037). No JSONB churn, no re-derivation.
- Marginal cost over today's job: at each set bit, bucket the earn timestamp instead of
  just `count += 1`. Accumulate a **transient per-achievement weekly histogram in RAM**
  (~tens of MB, the forward histogram is never stored), then collapse each to its
  ~15–20 breakpoints at the end of the pass.
- **Output to ship:** extend `scripts/export-rarity-library.py` (or a sibling export)
  to bake the breakpoints into the `AchievementRarity` library alongside `lib.counts`.
- **Box storage:** the DB only needs the compact breakpoint summary (single-digit MB),
  not a forward curve. The box has ~51 GB free; this is a non-issue.

### Library + addon read path — BUILT (`achievement-rarity@3354034`, `how-rare@2119486`)

- `AchievementRarity-1.0` gained `:RankAtEarn(id, earnTime, scope) → percentile` over the
  shipped breakpoints — interpolation + the bad-date floor inside the library (one source
  of truth, like `FormatPct`). `earnTime` is epoch seconds; the floor is parsed from
  `lib.rankFloor` and the ladder from `lib.rankLadder`, both shipped in the data file.
- `Core.lua` gained `G.RankAtEarn(id, scope)` — reads the user's earn date via
  `GetAchievementInfo` (same extraction as `G.AchievementEarnedShort`), converts to epoch
  via `time{}`, and calls the library. Value only; wording/surfacing is Track 2.

---

## Surfaces that read the rank metric

The rank rides the **focused, single-achievement** surfaces (where there's room and
attention). The **scanning column does not** (see below).

### Tooltip (`Tooltip.lua`) — the natural home

`TooltipDataProcessor` on the Achievement type already fires for the **achievement UI
*and* chat links** (its own comment), so hovering a pasted link is covered here.
Add, beneath the current-rarity line that's already there:

- **Your rank-at-earn when earned** — "you were in the first 5% to earn this".

### Chat broadcast (`Chat.lua`) — your status on someone else's earn

`CHAT_MSG_ACHIEVEMENT` / `_GUILD_ACHIEVEMENT` is the auto "*X has earned [Y]!*"
broadcast. It already appends current rarity. Add:

- **Your completion ✓/✗** (free — `G.SelfCompleted`, account-wide).
- **When you've earned it:** your "~X ago · in the first N%" — the "I did this 6 months
  ago, earlier than them" beat. Same data as the tooltip, on the broadcast line.
- **Not the linker's number** — impossible (can't read their SavedVariables; a link
  carries no earn data). This is *your* status on *their* announcement, deliberately.

### Toast (`Toast.lua`) — and the rank metric rescues the share path

- **Live earn:** current rarity is the headline ("only 2% have this") — the highest-
  frequency, screenshot-ready moment (§11, the one outbound surface).
- **`/howrare share` re-pop of an OLD achievement:** the **rank brag** — "you were in
  the first 2% to earn this." This now *works* — the rank metric is retroactive, so the
  old "no stamp for old achievements" problem that hollowed this out is gone.

### Achievement panel row (`AchievementUI.lua`) — STAYS current rarity

Decided: **do not** make the row's `%` state-aware. That column exists for
*browse-by-rarity while scrolling* — a comparable metric on every row. Swapping earned
rows to rank breaks the scan (no longer comparing like with like), and the slot (a
tight `%` by the points shield) has no room for the rank phrasing. The row stays
current rarity for earned and unearned alike; rank lives only on the focused surfaces.

### Wording

Default **"you were in the first X% to earn this"** (punchy/positive beats "earlier
than 95% of holders"). **Not** a settings option — it's one format string; settle when
seen in-game.

---

## Instance rarity — SEPARATE TRACK (different session, different work area)

> Kept in this handover for continuity, but build it on its own. It's a natural
> stopping point after the rank foundation + surfaces, depends on **none** of the
> gratz-side work, and lives in a different part of the addon. Pick it up fresh.

Show the rarity of achievements tied to a boss/instance on **Encounter Journal** tiles
+ boss rows, **world-map entrance pins**, and **Group Finder (LFD) rows**. In How
Rare?, rarity-focused — the dropped ③ instance-tooltips addon's surfaces fold in here.

- **Proven feasible** by the reverted hover probe (monolith `gratz-addon` `Gratz/
  Probe.lua` `/gz` — commits `cd19bb6` initial / `92a308a` 3-surface preserve). Each
  surface yields a `journalInstanceID`; lines append to `GameTooltip`.
- **BAKED + CURATED map, not runtime-derived.** Cherry-picked **direct achievement ↔
  instance/boss links** (heroic/mythic clears, boss kills, glory metas), shipped as a
  Lua table. A lookup, not a criteria walk — performant, additive. Dissolves the
  heroic-clear gap (those achievements are simply curated in directly — no detection
  heuristic).
- **Build-location DECIDED: in-client, not gratz-DB.** Derive the seed via an in-client
  EJ-walk dump tool (the probe's derivation) → hand-curate / gap-fill → **freeze a
  bundled Lua table in the How Rare? repo**. The gratz DB is *not* involved: its
  criteria derive discards the criterion type+asset, and the `dungeonEncounterID →
  journalInstanceID` resolution is client-only anyway, so DB-side would split the
  source of truth. (Decoupled from the rarity-library refresh clock — different,
  slower cadence.)
- **The bundled map stores ONLY structural links** (instance/boss → achievement IDs),
  **never rarity numbers**. Rarity is looked up *live* from the rarity library at
  render → a rarity refresh can never desync the map.
- **Remaining work (its own session):**
  1. Build the in-client EJ-walk dump tool (port the probe's derivation).
  2. Hand-curate / gap-fill the links (heroic clears, glory metas).
  3. Decide expansion scope — start Midnight-only, or all expansions up front
     (one-time bounded work).
  4. Port the three surface hooks into How Rare? (`Instance.lua`), reading the bundled
     map + the rarity library; reuse `G.RarityLine` etc.
- **Highest technical risk:** the EJ ScrollBox frame paths are version-specific and the
  **boss-row hook was never actually exercised** in the probe — validate on a current
  client before committing. Stay **append-only** to the already-shown `GameTooltip`
  (taint-safe via `hooksecurefunc`), especially around Group Finder.

---

## Build order

Two independent tracks; the surfaces depend only on Track 1.

1. **Foundation (gratz-side): BUILT + committed (`gratz@19940f3`,
   `achievement-rarity@3354034`/`@21feb6c`, `how-rare@2119486`).** Breakpoint computation
   folded into `rarity-counter.py` → export into the `AchievementRarity` library → library
   rank-lookup API → `Core.lua` helper. Rode the existing nightly pass as planned.
   Validated end-to-end on the dev DB (offsets monotone, the observed corpus-min earn date
   == the fixed floor). **Not yet on prod**, and the embedded data file is still the
   no-ranks prod snapshot — see the publish milestone before in-game testing.
2. **Surfaces (addon): NEXT.** tooltip → chat → toast rank lines (read Track 1). Small; the
   files already do ~90% of the work. The row stays rarity (no change).
3. **Instance rarity (separate session, above):** independent of 1 & 2; the larger,
   self-contained piece with its own work area and its own maintenance tail.

## Open items

- ~~Exact breakpoint ladder + the data-quality holder-count floor.~~ **Decided:** ladder
  `0,1,2,3,4,5,7,10,15,20,30,50,75,100`; holder floor 100 per scope; floor fixed at
  14 Oct 2008 (not corpus-min — robust against stray zero/garbage dates).
- ~~Packed vs nested encoding — decide once the generated file is measured.~~ **Decided:
  nested** — the generated file measured ~1.6 MB (ranks ~1.4 MB over counts), comfortably
  single-digit-MB resident. Delta-encoding the monotone offsets is the lever if it ever
  grows; not needed now.
- Final wording, confirmed in-game (Track 2).

---

## Deferred from the shipped library theme (don't lose)

- **Publish milestone — do these together, once v1 is settled:**
  - Crawler → export → push automation (run `gratz/scripts/export-rarity-library.py`
    after the rarity counter, push the `achievement-rarity` repo, **re-embed both halves
    into `HowRare/Libs/`**). The rank-breakpoint export folds into this same step. How
    Rare? embeds *copies* (not symlinks), so the embedded data file is whatever the last
    publish baked — keep it on the rarity-refresh cadence so the embedded baseline never
    drifts far. Releases ship PROD numbers (tunnel to prod, export, re-embed); the
    committed embed must never carry dev numbers.
  - Standalone CurseForge publish of the library + a release workflow (none yet).
  - gratz-site attribution reframe ("gratz.gg-supplied" → "the Wizzleworks"; casing).
- **Distribution model — DECIDED (revisited 2026-06-29): embed-first, optional
  standalone, NOT a hard dependency.** Every consumer embeds the library (always works
  standalone); the standalone CurseForge copy is *optional*, declared `## OptionalDeps`
  in consumers — a load-order hint + a CurseForge suggestion, never a load failure if
  absent. **LibStub freshest-wins IS the reference switch** (no manual "use external if
  present" code): a consumer just calls `GetLibrary` and transparently gets the freshest
  copy, embed or standalone. There is one shared table per major on a client, so multiple
  embedders (How Rare? + a hypothetical Krowi) converge to the single freshest snapshot —
  **no cross-surface divergence**, and only the winner's table is built (no double
  memory). Two guards keep that invariant: (a) **keep the MAJOR string stable** — bump
  `-1.0`→`-2.0` only on a breaking API change (a bump fragments data until consumers
  reconverge); (b) the static API half is now **freshest-API-wins gated** on its own
  `API_MINOR` (`achievement-rarity@21feb6c`), so consumers embedding different API
  versions can't clobber each other into a mixed-version API. *Hard-dep was reconsidered
  and rejected:* WoW's platform dep tooling is weak (a missing/disabled dep just disables
  the consumer), so a hard dep would put the headline value behind a fragile external
  moving part for **no divergence benefit freshest-wins doesn't already provide**.
  Revisit only if multiple independent consumers AND a *measured* stale-baseline problem
  emerge — and even then the WoW-native answer is usually still embed + freshest-wins.
- **Options "How the numbers work" link** → a doc in the `achievement-rarity` repo
  serving both audiences (how to *use* the library + the methodology). README already
  covers both; a dedicated landing doc is optional. (Repo is public, so unblocked.)

## In-game testing (unchanged)

- Symlinked: `Interface/AddOns/HowRare` → this repo's `HowRare/`. `/reload` for edits.
- Lua errors hidden unless `/console scriptErrors 1` (or BugSack).
- Library smoke-test: `/dump LibStub("AchievementRarity-1.0"):GetMeta()`.

## Delete me

Delete when this theme's surfaces ship (or the theme is re-scoped).
