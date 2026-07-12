# HANDOVER — How Rare? rarity-surface expansion (design revised 2026-07-02)

**This theme:** grow where How Rare? surfaces rarity. A **rarity-at-earn foundation**
(the *rank metric*, gratz-side) feeds **tooltip / chat / toast** surfaces, plus
**rarity on dungeon/raid content** (Encounter Journal, map pins, Group Finder) as a
separate track. All **in How Rare?** (the rarity layer). Design agreed 2026-06-28,
**revised 2026-06-29** (stamp → gratz-side rank metric) and **again 2026-07-02** (rank
denominator re-based to all accounts + a full product re-evaluation build — see the
amendment and SESSION STATE below). **Track 1 (the foundation) is BUILT + committed
(2026-06-29, prod OOM fixed 2026-07-01); Track 2 (surfaces) + the re-evaluation set are
BUILT, uncommitted, awaiting in-game verify (see SESSION STATE below); instance rarity
(Track 3) is its own session.**

Builds on the architecture doc (`../gratz-addon/docs/addon-architecture.md`): §6
(rarity-at-earn), §7 (instance→achievement map), §3③ (the dropped instance-tooltips
addon), §11 (naming / the toast as the outbound surface), and the reverted hover probe
(`../gratz-addon/docs/dungeon-raid-hover-probe.md`).

## SESSION STATE — 2026-07-11: v1 headliners BUILT (uncommitted) — "How rare are YOU?" + Gz!

The killer-feature decision landed (user-approved): **both** go in v1.

- **Collection standing ("your achievements are Epic" — user's wording, "achievements"
  not "collection" in copy).** Score = Σ −log2(global attainment share) over earned
  snapshot achievements ("surprise" points); the corpus distribution ships as
  percentile→score breakpoints. Chain built end-to-end: counter `rarity_score` standing
  metric (rides the existing rank pass — weights need finished counts; deci-point ints,
  `SCORE_SCALE=10`; eligibility = the SAME live∧Blizzard-indexed set the export ships —
  lockstep filters, flagged as consistency debt) → export `standingLadder`/`standing`
  (points, ÷10) → library `CollectionWeight/Score/Standing/Tier` (API_MINOR 4; tier =
  the loot bands applied to top-% of accounts) → addon `G.CollectionVerdict` +
  `/howrare me` (verdict + score print, pinnable standing card off the toast frame —
  `PopulateStanding`, `ShowSample` generalised to a fill-fn, `PinButtons` extracted).
  Validated on dev end-to-end (counter run + export show plausible curves).
  **SEQUENCING:** prod has no `rarity_score` rows until the new counter runs there
  (gratz push → next 05:30 cron), so `/howrare me` on the current embed prints the
  score + "no standing in this snapshot" line; the REAL publish (re-export + re-embed
  with standing) happens after that cron tick. Library + addon degrade gracefully.
- **Gz! (click-to-send congratulation).** `[Gz!]` affordance (gold, locally-visible,
  `garrmission:`-typed link — unknown link types aren't clickable; that's the
  established addon-space carrier) appended to every enriched announcement; click sends
  "Gz! [link]" (+ " — only 0.4% of EU accounts have this!" on IsRareTier earns) into
  the ORIGIN channel (guild→GUILD, nearby→SAY; the click is the hardware event SAY
  needs). Strictly never-auto; 30s per-(achievement,channel) cooldown; sent line
  deliberately UNBRANDED (conventions updated in CLAUDE.md). Rides the "chat" toggle.
- gratz BACKLOG gained the profile-page surfacing of the same standing (reads the same
  `population_standing` metric; tier framing over raw rank).
- **Open consistency debt (flagged via TECH_DEBT hook, user to decide):** the
  live∧Blizzard-indexed "shipped set" filter now exists in THREE expressions (export
  counts query, export ranks query, counter score-eligibility) + the ×10/÷10 scale pair
  (counter/export). Candidate fix: one `v_shipped_achievements` view + a scale row in a
  meta table; deferred unless the user opts in.

**Also built same day (user-approved design): the character-sheet row**
(`CharacterSheet.lua`, `characterSheet` option, default on): "Achievements — <Tier>"
as a stat-style row at the BOTTOM of the Character Info stats pane (own frame, no
Blizzard stat internals touched; row geometry constants are eyeball-first-cut), full
verdict on hover. Verdict cached (scope-keyed; invalidated on ACHIEVEMENT_EARNED),
refreshed via the master/scope/toggle Settings callbacks. Hidden until the snapshot
ships standing. Own sheet only — inspect can't read another player's earned list.

**gratz pushed + deployed 2026-07-11 (both rounds):** the standing metric + the
consistency fix (migration 083 `v_shipped_achievements` + `standing_meta` — applied on
prod, view verified returning 8,349). The 05:30 cron next computes the distribution.

**2026-07-12: standing data LIVE + first-verify fixes.** The 05:30 cron OOM'd twice at
the 5G cap — (1) deci-point buckets made ~830K accounts ~830K histogram values
(SCORE_SCALE 10→1, whole points); (2) the per-rep scores dict grew INSIDE
rank_histogram's churn loop, pinning the heap against the per-chunk malloc_trim
(preallocated flat array + upfront key→slot index; the "no long-lived allocation in
the churn window" rule, now documented in the function). cron-rarity.sh runs Python
unbuffered so a SIGKILL leaves its progress prints. Third run clean (~15K buckets per
region); fresh prod snapshot (asOf 2026-07-12, all three standing scopes) exported +
re-embedded; harness passes on the real file. From the user's first in-game pass:
character-sheet row now gated to **Uncommon or better** (junk/common there reads as an
insult; /howrare me stays honest for all tiers), and the toast's brand mark moved to
its **own line** below the footer (a long name · five-digit score · date footer needs
the full width).

**SIGNED OFF 2026-07-12** after the full in-game pass: me verdict + card, character
sheet, Gz! (a click-dead bug found by the user's manual test — `local a, b = x and
s:match(...)` truncates a multi-capture match to its first value, so the channel never
arrived; fixed, plus an 8-angle /code-review round that fixed: the "rarer than 100.0%"
display rounding, the standing cap/monotonicity at the elite tail, the standing card
destroying live toast queues, pin-button leakage onto real toasts, Gz on own earns /
modified clicks / channel allowlist, the `why` scope mismatch, a shared verdict cache
in Core with coalesced earn invalidation, and one-owner helpers for tier labels /
standing format / notability). Options page restructured on user feedback: data strap
("<denominator> · <asOf> · Data by wizzleworks") rides the page title; bottom block is
the two-sentence methodology only; checkbox label "Achievements tier on character".

**NEXT — the release train (the session-plan remainder):** one-command publish script
(tunnel → export → commit/push library → re-embed → commit addon), CurseForge admin
(create both projects, set CF_API_KEY/CF_PROJECT_ID, repo visibility decision, library
release workflow), library CHANGELOG "Unreleased" → version + TOC version refresh,
then tag v1.0.0. Instance rarity (Track 3) stays its own future session.

## Previous session state — 2026-07-10: first in-game verify done → fix round SHIPPED (committed 2026-07-11)

The 2026-07-10 in-game pass verified panel rows, chat (partially — no live broadcast seen
yet), toast, options, and `/howrare top`; it found that the rank line never showed because
its main surface didn't exist (Blizzard's panel has NO row tooltips — our processor only
fires on chat-link hovers), plus a set of taste/data issues. The agreed fix round is
**built, luac-clean, uncommitted** in all three repos:

- **Panel-row hover tooltip** (`AchievementUI.lua` HookRowTooltip + `rowTooltip` option,
  default on): pops the STANDARD achievement tooltip via `SetHyperlink`, which the
  existing Tooltip.lua processor enriches — row hover ≡ chat-link hover, rank line and
  Shift-detail included. Toggleable for Krowi/Overachiever users (they have own row tips).
- **Count-form triggers** (`G.COUNT_FORM_MAX = 10000`, one knob, Core): the tooltip
  "(one of ~N)" parenthetical now count-triggered (was pct<1%, which the user's ~1%-rarest
  account never hit); `RankPhrase` renders "first ~2,300" (count form, via new
  `G.CountForPct`) under the knob, "first 3%" above. **User suspects 10k may be too high —
  tune from in-game feel.** `/howrare why` explains both forms.
- **Junk tier lightened** (library, 0.5 → 0.75 grey; API_MINOR 3): the dark grey blended
  into the panel row background in-game.
- **Toast celebration simplified**: single pulse for every tier (multi-pulse felt like too
  much); tier tint on the shine kept. Brand-mark position confirmed fine in-game.
- **Retired achievements excluded from the data** (gratz `export-rarity-library.py`):
  achievements delisted from Blizzard's achievement API index (Giddy Up! 891 + 3 others —
  exactly 4; they enter the catalogue via the wago mirror only) are unobtainable, hidden
  from the client UI, and their rarity measures attrition — dropped from counts AND ranks
  at export. Verified on dev (8353→8349). **Fresh PROD snapshot exported (asOf 2026-07-10,
  minor 2382) + re-embedded** — the embed is current again.
- **Mode-flip gremlin fixed for good**: something (likely the WoW client reading through
  the symlink) keeps setting +x on files; `core.fileMode false` is now set in this repo's
  git config, so mode-only changes no longer show as diffs.

**Re-verify round PASSED in-game 2026-07-10** (row tooltip, junk grey, retired strays
gone, single-pulse toast, chat confirmed live via a guildie's earn). Two follow-ups from
it, BUILT (uncommitted) same day:

- **Small-club knob configurable, default 2,500** (user's call — first 1,000 "to make it
  special", then nudged to 2,500 for the median player; NOTE the user's own SavedVariables
  already hold 1,000 from the test session — defaults only fill missing keys, so they must
  flip the dropdown once):
  `G.CountFormMax()` reads `HowRareDB.countFormMax`; an options dropdown (Off / 500 /
  1,000 / 2,500 / 5,000 / 10,000) replaces the fixed 10k constant. Now drives ALL THREE
  count forms — tooltip parenthetical, rank phrase, **and the toast's "One of only ~N
  people" line** (previously legendary-gated; unified deliberately so every count form
  flips at one user-owned boundary — flagged to the user as a consistency call).
- **Toast footer tilde centred**: the footer is now three chained pieces (pre/~/post,
  `STAMP_TILDE_NUDGE = 3`) like the rarity row, so a count-form rank's "~" sits centred
  against the digits. NOTE: on tooltip/chat TEXT lines the tilde's height is the font
  glyph's own — WoW has no per-character vertical offset in a text run; stated to the
  user as a hard limit.

**NEXT — in-game check of the two follow-ups (then commit all three repos):**
1. Toast pin → footer "first ~N" tilde now centred (both nudge constants eyeballed).
2. Options → "Show counts for small clubs" dropdown appears, flips all three count
   surfaces live (tooltip needs a re-hover; toast a re-pin).
3. Judge 1,000 as the default in the wild.

## Previous session state — 2026-07-03 (superseded; kept for context)

The 2026-07-01 in-game test session found the rank metric's denominator flaw (see the
foundation amendment below) and prompted a full product re-evaluation; the whole approved
improvement set is **built, luac-clean, functionally tested outside WoW** (a stubbed-Lua
harness verified the redefined metric against a hand-computed oracle, explicit-region
scopes, and the suppression reasons), **cleaned by a 4-angle /simplify pass, and
committed in both repos** (2026-07-03, user-approved). The simplify pass consolidated:
one rare-tier predicate (screenshot mode + toast flourish share the boundary), one
snapshot-wide earned scan (share / top / pin), explicit-region scopes in the library
(consumers no longer index its packed triples), RankAtEarn nil-reasons ("off-snapshot" /
"no-curve" / "date-floor" — /howrare why reads them instead of the library's tables),
earn-date derivation threaded once through the hot chat/tooltip paths, and the toast on
the shared per-surface gate.

**Built this session (all uncommitted):**
- **Rank metric re-based (library API half, `achievement-rarity` sibling + re-embedded):**
  `RankAtEarn` now returns the share of ALL tracked accounts that earned it before you
  (= earner-percentile × rarity; denominator-consistent with the rarity %, never exceeds
  it) plus the earner-only percentile as a second return. `API_MINOR = 2`. Data file
  unchanged (same curves, prod `asOf 2026-07-01`).
- **Gate + formatting (Core):** the old 50%-of-earners flex cutoff is now a **redundancy
  gate** `G.RANK_EARLY_MAX = 75` (the line shows when you're in the first 75% of earners;
  later than that it would only restate the rarity — a live earn stays suppressed).
  `G.FormatPctFine` (whole ≥1%, one decimal to 0.1%, "<0.1%" below) formats the rank and
  the other rare-end surfaces; the site-convention FormatPct is unchanged elsewhere.
- **Tooltip:** sub-1% rarity lines append the count ("(one of ~830)"); Shift-hover detail
  view (tier name, US/EU/Global fine %s, your earn date + ago); per-surface toggle.
- **Chat:** ✓/✗ replaced with the raid ready-check icon textures (WoW fonts have no ✓/✗
  glyph — they rendered as coloured boxes in-game); per-surface toggle.
- **Toast:** tier-scaled celebration (rare+ tiers tint the shine sweep in tier colour;
  epic pulses the glow ×2, legendary ×3); small brand-gold **"How Rare?" mark** bottom-right
  (the travelling-surface exception to brand silence — CLAUDE.md conventions updated);
  screenshot became a **mode** (off / rare earns / all; old boolean saved-vars coerced);
  `/howrare toast pin` now showcases YOUR rarest earned (rank-braggable + name-fits first).
- **Options:** per-surface checkboxes (tooltip / chat / panel %), screenshot dropdown,
  and a stale-snapshot nudge on the login line (>60 days old). The about block is ONE
  compact small-font paragraph via our own settings-list element template
  (`OptionsAbout.xml` + `HowRareAboutMixin`, TOC'd) — stock section headers are 45px
  per line and don't wrap, so line-per-header truncated AND scrolled; the factory
  contract (frame:Init(initializer), extent = template height) was verified against
  Blizzard_SettingsList.lua / ScrollUtil.lua in the Gethe mirror. The credit is the
  lowercase display wordmark in brand gold: "Data by wizzleworks" (running prose keeps
  "the Wizzleworks" — convention recorded in CLAUDE.md).
- **Chat separator:** the rarity tag lost its brackets — beats chain with middle dots
  (`… · rarity 3% ✓ · ~2 years ago · first 0.4%`).
- **Commands:** `/howrare top [n]` (your rarest earned as hoverable links, fine %s +
  rank) and `/howrare why <link|id>` (full per-achievement story: rarity, count, tier,
  your earn, your rank, and exactly which rule shows/suppresses each line).
- **Docs updated for consistency:** both READMEs, both CHANGELOGs, how-rare CLAUDE.md
  (brand exception + slash list). Deliberately NOT built (product boundaries): rarity
  browser/sort UI (paint-and-glance altitude confirmed), realm scope, historical curves;
  also skipped as needing live-client verification first: comparison-frame + guild-tab
  painting, Krowi coexistence check.

**NEXT — in-game verify (then commit):**
1. `/reload`, then `/howrare why <shift-click an achievement link>` — the new
   self-diagnosis; confirm its story matches what the surfaces show.
2. Chat: broadcast → ready-check tick/cross icons (NOT coloured squares now) + "ago ·
   first N%" on early-held earns.
3. Tooltip: sub-1% count parenthetical; Shift-hover detail; rank line on early earns
   ("first 0.x%" values now — much smaller than before, by design).
4. Toast: `/howrare toast pin` (your earned card + rank row + brand mark placement —
   the mark's y-offset is eyeballed, may need a nudge); tier-tinted shine / pulses via
   `/howrare toast 3`; screenshot mode dropdown.
5. `/howrare top` — the list + hoverable links.
6. Judge the taste calls: RANK_EARLY_MAX=75, the "first 0.4%" wording, tint intensity.

(Committed 2026-07-03 with the spurious `Libs/*` 100644→100755 mode flips reverted via
chmod, so they never entered history. Anything the in-game verify shakes out lands as
follow-up commits.)

**gratz side — DONE + deployed, background only (NOT front-end work):** Track 1's rank pass
was OOM-killing the prod counter (~6 GB); fixed and deployed across four gratz commits —
`0ceda75` / `58e1788` / `87c5a9c` (the memory fix: isolate the rank histogram + malloc_trim
the per-chunk churn) and `b5c7af0` (a 5 GB cgroup cap on the nightly counter so a future
runaway kills the counter, not the web app). The nightly cron now populates the rank tables
(verified 2026-07-01: 882K reps, 0 drift, ~3.35 GB peak — fine on the 7.75 GB box; the
pre-floor date warning is a negligible stray). Full detail is in the gratz git log. The one
carried-forward item is the publish AUTOMATION (auto export→push→re-embed), still deferred
below — this session's export+embed was by hand. None of this concerns the front-end session.

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
