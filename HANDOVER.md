# HANDOVER — How Rare? v1: surfaces SHIPPED + signed off; release train NEXT

**Theme status:** the rarity-surface expansion — rank metric → tooltip/chat/toast, the
v1 headliners (**"How rare are YOU?"** collection standing + **Gz!**), panel-row
tooltips, the character-sheet verdict row — is **built, in-game verified, SIGNED OFF
(2026-07-12), and committed in all three repos.** What remains of v1 is the **release
train** below: packaging and admin, no product code. Instance rarity (Track 3) stays a
separate future session — its parked design is at the bottom of this file, with the
architecture references (`../gratz-addon/docs/addon-architecture.md` §6/§7/§11,
`../gratz-addon/docs/rarity-data-library.md`).

## WHERE THINGS STAND (2026-07-12, signed off)

- **Repos:** gratz — all rarity/standing work committed AND pushed/deployed: the
  nightly 05:30 counter computes rarity + rank curves + the `rarity_score` standing
  distribution; migration 083 (`v_shipped_achievements` + `standing_meta`) is applied
  on prod (nightly run verified clean 2026-07-13: all sections wrote, standing sums
  match the denominators exactly). achievement-rarity — fully pushed through the
  2026-07-13 snapshot. how-rare — release commits on main, **NOT pushed** (its pushes
  deploy nothing; tagging pushes them).
- **Embed:** the addon carries the prod snapshot asOf **2026-07-13** (835,577 tracked
  accounts; all three standing scopes; the 4 retired achievements excluded). It drifts
  ~a day stale per cron tick — `scripts/publish-data.sh` right before tagging if a
  day+ has passed.
- **Verified:** full in-game sign-off; stub-Lua harness green against the real data
  file (standing interpolation, elite-tail cap + monotonicity, no-standing
  degradation); luac/XML clean. Library API at **API_MINOR 4**; collection standing
  lives fully in the LIBRARY (weight/score/standing/tier) — any consumer can build the
  verdict; How Rare? adds only the isEarned callback + the surfaces.

## NEXT — the release train (admin + packaging only)

1. ~~**One-command publish script**~~ **DONE (2026-07-13): `scripts/publish-data.sh`**
   (how-rare repo) — tunnel → prod export → verify (three standing scopes, no
   warnings, luac parse) → stamp the library TOC → commit+push achievement-rarity →
   re-embed → commit how-rare. Proven end-to-end twice (fresh publish + idempotent
   no-op re-run); refuses partial exports; owns port 15433 with
   ExitOnForwardFailure so it can never silently ride a squatting listener (a
   long-lived pgAdmin tunnel tends to hold 15432). Depth decided: **local
   one-command now**; box-side auto-push stays deferred (below).
2. **CurseForge admin (USER — needs the CurseForge account).** Both former open
   decisions SETTLED 2026-07-13: (a) the how-rare repo is now PUBLIC; (b) a
   standalone library listing — YES, submitted FIRST (review takes days and is the
   long pole; refresh automation for BOTH projects follows right after approval —
   cadence to be discussed then). Listing assets for **AchievementRarity** are ready
   (2026-07-13): name `AchievementRarity`; logo = loot-quality percent (epic/legendary
   rings, gold slash) committed at the library repo's `assets/` (512px PNG master +
   SVG source); summary (245 chars): "Achievement rarity data by the Wizzleworks — an
   embeddable LibStub library: the share of accounts that hold each achievement
   (US/EU/global), plus rank-at-earn and collection standing. Install alongside a
   consumer addon to keep its numbers fresh." (freshest-wins mechanism promised, no
   cadence — strengthen once automation runs); categories Libraries (main) +
   Achievements (additional); license MIT; source link = the GitHub repo. Zip build
   via `scripts/release.sh` (library repo — stages the root-is-addon layout);
   description at `assets/curseforge-description.md`; CHANGELOG's `## 2026.07.13 —
   initial release` section rewritten as the public entry (the convention now: the
   tag-heading section IS what CI/an upload form gets, dev history stays in git log).
   **The AchievementRarity project is APPROVED (2026-07-13, same day).** Its
   tag-driven release workflow is BUILT + pushed (`.github/workflows/release.yml`,
   mirror of how-rare's: root-layout TOC, date-based versions, and a data-refresh
   changelog fallback — a tag without a CHANGELOG section uploads as "Data snapshot
   as of <date>"). Secrets SET (2026-07-13): `CF_API_KEY` (user-set) +
   `CF_PROJECT_ID` = 1608684 (project live on CurseForge, author "wizzleworks").
   **NIGHTLY PUBLISH AUTOMATION: BUILT + ARMED (2026-07-13).** gratz
   `scripts/cron-rarity-publish.sh`, box cron 07:00 (after the 05:30 counter):
   export → verify (three scopes, no warnings) → stamp TOC → commit → tag
   `v<snapshot-date>` → push via write deploy key (`/opt/achievement-rarity`
   checkout, `~/.ssh/achievement_rarity_deploy`); the tag fires the Actions
   workflow which does the CurseForge upload — the box never holds the CF token,
   GitHub never touches the DB. Unchanged data or a failed counter → quiet no-op;
   failures alert via ntfy. Box dry-run proved the no-change path (export
   byte-matched the committed 2026-07-13 snapshot → no publish). **The first live
   end-to-end proof (commit → tag → CI upload) is the 2026-07-14 07:00 run — CHECK
   IT: the run log, the v2026.07.14 tag, the Actions run, and the new file on the
   CurseForge project.** Known accepted edge (documented in the script header): a
   manual local publish the same morning suppresses that night's tag; never
   retro-tag unchanged data (the manually-uploaded 2026.07.13 was never CI-tagged —
   retro-tagging would double-upload). how-rare's `publish-data.sh` now pulls the
   library checkout before exporting (two writers). How Rare?'s own embed cadence
   stays slower — feature releases / periodic embed refreshes, not nightly; settle
   when its approval lands.
   Noticed 2026-07-13, unfixed (deliberately parked until after release): the
   library README's methodology section still says the rank floor is 14 Oct 2008,
   but the shipped data's `rankFloor` is 2004-11-23 (WoW launch).
   **NEXT: the How Rare? CurseForge project, same process** — assets DRAFTED
   2026-07-13: name = the TOC/CLAUDE.md title "How Rare? — Achievement Rarity";
   summary (248 chars): "How rare is that achievement? See the share of accounts
   that have each one — on every tooltip, chat announcement, and achievement-panel
   row, plus an earned toast, rank-at-earn (\"you were in the first 0.4%\"), and a
   verdict for your whole collection."; categories Achievements (main) + Tooltip,
   Chat & Communication (additional); license All Rights Reserved; description at
   `assets/curseforge-description.md` (this repo); first-upload zip built
   (`HowRare-1.0.0.zip`, untracked at repo root); changelog = the CHANGELOG's
   existing `## 1.0.0` section (already public-facing). Logo PICKED 2026-07-13:
   the family lockup (gold question + the library's loot-quality percent in the
   corner — the addon asks, the library answers), committed at `assets/` (512px
   PNG master + SVG source). **The How Rare? project is SUBMITTED — awaiting
   approval (2026-07-13; the v1.0.0 zip uploaded manually at creation).**
   Tagged `v1.0.0` 2026-07-13 — the release workflow ran GREEN (version stamped,
   zip built in CI, upload skipped as intended since how-rare's secrets aren't set
   yet). REMAINING on approval: set `CF_API_KEY` (secret) + `CF_PROJECT_ID`
   (variable, from the approved project page) on the how-rare repo; the CI upload
   path gets proven at the first post-approval release (the next embed refresh,
   e.g. v1.0.1). Also settle then: its box-side automation (an embed-refresh
   sibling of cron-rarity-publish.sh) and its cadence.
3. ~~**Library release tidy**~~ **DONE (2026-07-13):** CHANGELOG `## Unreleased` →
   `## 2026.07.13`; version scheme settled **date-based** (matches the
   snapshot-derived LibStub minor); the publish script now stamps the library TOC
   `## Version:` with the snapshot date on every publish, so it can't go stale again.
4. **Tag — SUPERSEDED by the manual first uploads (step 2).** Both v1 files are
   already on CurseForge (uploaded manually at project creation), so the original
   "first tag uploads v1" plan no longer applies. What tags now do: how-rare
   `git tag v1.0.0 && git push --tags` marks the release commit and proves the CI
   zip step (upload skips while secrets are unset — recommended now); the library
   tags `v<snapshot-date>` per data refresh once its secrets are set. All future
   releases go through the tag→CI path.

## Shipped log (compressed — full detail in the three repos' git logs)

- **2026-07-03:** rank metric re-based to all-accounts (API_MINOR 2) + product
  re-evaluation build + 4-angle simplify pass.
- **2026-07-10/11:** verify rounds → panel-row tooltips (the rank line's real home),
  configurable count-form knob (default 2,500), junk grey 0.75 (API_MINOR 3),
  single-pulse toast, retired-achievement exclusion (4 Blizzard-API-delisted strays,
  Giddy Up! et al.), mode-flip gremlin killed (`core.fileMode false`).
- **2026-07-11/12:** v1 headliners — collection standing end-to-end (counter metric →
  export curves → library API_MINOR 4 → `/howrare me` + card + character-sheet row)
  and Gz!. gratz side survived two 5G-cap OOMs (deci-point bucket explosion →
  whole-point SCORE_SCALE 1; a scores dict grown inside the rank pass's trim-sensitive
  churn loop → preallocated flat array; both lessons documented in rarity-counter.py;
  cron now runs Python unbuffered so kills leave their progress trail). An 8-angle
  /code-review round fixed the "rarer than 100.0%" rounding, the elite-tail standing
  cap/monotonicity, standing-card queue destruction, pin-button leakage, Gz-on-own-
  earns / modified clicks / channel allowlist, and the `why` scope mismatch — plus the
  user-caught Gz click-dead bug (`x and s:match(...)` truncates a multi-capture match
  to its first value; the channel never arrived). Options page: data strap rides the
  "How Rare?" title. **SIGNED OFF and committed.**

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

> **Design change 2026-07-02 — the denominator is ALL tracked accounts, not holders.**
> In-game testing exposed the holders-only version as backwards: a mid-pack earner of a
> top-4% achievement ranked "first 85%" *of a club 96% of players never joined* —
> punishing exactly the rare achievements the metric exists for, and using a different
> denominator than the rarity line beside it. Re-based: **"first N%" = the share of all
> tracked accounts that earned it before you** (an account that never earned it can't
> have earned it before you), which is simply earner-percentile × current rarity — same
> data, one multiplication, denominator-consistent with rarity (never exceeds it). The
> library returns both values; the display gate is now a **redundancy gate** (show when
> in the first 75% of earners — later would only restate the rarity), and rank values
> format finely below 1% ("first 0.4%") since that's where they now live.

**The metric: "you were in the first N% to earn this"** — the share of all tracked
accounts that earned it before you (see the 2026-07-02 amendment above). A genuine flex
on rare achievements ("first 0.3%"), and *nice-to-know* on common ones, so we ship it
for everything.

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
2. **Surfaces (addon): BUILT (uncommitted), awaiting in-game test.** tooltip → chat → toast
   rank lines, all composed from Core's `RankPhrase` (see SESSION STATE above). The row
   stays rarity (no change). Prod ranks embedded; next is in-game wording/colour/cap tuning.
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
  - Crawler → export → push automation. The **local one-command half is DONE**
    (`scripts/publish-data.sh`, 2026-07-13 — tunnel to prod, export, verify, push the
    library repo, re-embed, commit); what stays deferred is the **box-side auto-push**
    (run the export after the nightly counter on the box and push without a human),
    which matters only once a standalone library listing exists to keep fresh. How
    Rare? embeds *copies* (not symlinks), so the embedded data file is whatever the
    last publish baked. Releases ship PROD numbers — the script tunnels to prod; the
    committed embed must never carry dev numbers.
  - Standalone CurseForge publish of the library: SUBMITTED 2026-07-13, awaiting
    approval; its tag-driven release workflow is still to build (gated on approval,
    together with the nightly automation).
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

Delete when v1 ships (the release train above completes) — the durable design
detail worth keeping (instance track, distribution model) moves to its own spec then.
