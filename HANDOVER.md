# HANDOVER — How Rare? v1 release train (in-flight)

**Ephemeral.** Current-state ledger; delete when v1 ships (release train below
completes) — the durable design blocks (instance track, distribution model)
move to their own spec then. History lives in git, not here.

**Rules of this document:** every claim carries **[checked <date> — how]**,
**[carried — prior-session claim, not re-verified]**, or **[user call <date>]**.
This is a claims list, not a truth source — verify load-bearing claims before
building on them. State facts; no self-grading narrative.

## Current state

- **Product code**: the v1 surfaces (tooltip/chat/toast rank lines, panel-row
  tooltips, `/howrare me` collection-standing card, character-sheet verdict
  row, Gz!) are built, in-game signed off, committed
  [carried — sign-off 2026-07-12].
- **Repo**: main fully pushed, no unpushed commits, working tree clean
  [checked 2026-07-17 — git]. Latest: 1f03fc2 (README rank-floor date fix —
  closes the item previously parked as "after release"), 5076f54 (diamond
  brand icon), 69afa6d (embed snapshot 2026-07-16).
- **Embed**: carries the 2026-07-16 prod snapshot [checked 2026-07-17 — git
  log]. Drifts ~a day per cron tick; `scripts/publish-data.sh` before tagging
  if a day+ has passed [carried].
- **Library (achievement-rarity)**: live on CurseForge (project 1608684,
  approved 2026-07-13) [carried]. **Nightly publish automation is live and
  proving itself daily**: tags v2026.07.14 → v2026.07.17 exist, one per day
  [checked 2026-07-17 — git tag]. The CurseForge upload leg (Actions run per
  tag) is not verifiable from this machine [not checked here].
- **gratz side**: counter + rank curves + `rarity_score` standing on prod,
  migration 083 applied [carried — verified 2026-07-13].

## Release train — what actually remains

1. **How Rare? CurseForge approval — approved and live** [checked
   2026-07-17 — public page fetch]: curseforge.com/wow/addons/how-rare is
   public, project id 1608900, live since 2026-07-13.
2. **CF pair set; upload chain proven end-to-end** [checked 2026-07-17]:
   armed manual dispatch ran the full train — embed refreshed to snapshot
   2026-07-17, v1.0.1 committed + tagged by CI (75ed867), release.yml
   dispatched on the tag, zip built, CurseForge accepted the upload (file
   id 8452385, project 1608900; runs 29593296990 → 29593311505). The
   unarmed gate leg was proven separately first (run 29593151777: no-op,
   no tag). Residual: at check time the public page still listed 1.0.0 —
   1.0.1 was in CurseForge's file-processing queue [not re-checked].
3. **OptionalDeps TOC line — done** [checked 2026-07-17 — commit bb9ea69]:
   `## OptionalDeps: AchievementRarity` in HowRare.toc, load-order comment
   updated; rides in the next release (v1.0.1). Gratz's TOC got its line
   2026-07-14 [carried].
4. **Embed automation — settled and built, not yet proven live** [checked
   2026-07-17 — written this session]: GitHub-side, not box-side —
   `.github/workflows/data-refresh.yml` re-embeds the library repo's snapshot
   every Wednesday 09:00 UTC (after both regions' weekly resets — release at
   the WoW week boundary [user call 2026-07-17]; and two hours after the
   box's 07:00 UTC nightly library publish) and, when changed, patch-bumps
   over the latest v* tag,
   stamps TOC + CHANGELOG, tags, and dispatches release.yml on the tag ref
   (GITHUB_TOKEN pushes don't fire on:push workflows). Weekly cadence per
   [user call 2026-07-13]; the box never gets a how-rare deploy key. Gated
   on the CF pair from item 2. Proven live end-to-end via armed manual
   dispatch [checked 2026-07-17 — see item 2]; next unattended proof is
   the Wednesday 2026-07-22 09:00 UTC cron tick.

Known edge [carried — documented in cron-rarity-publish.sh header]: a manual
local publish the same morning suppresses that night's tag; never retro-tag
unchanged data. Same shape weekly here: a hand-cut release embedding the
current snapshot suppresses that Wednesday's auto-release (no diff). New edge
[accepted 2026-07-17 — data-refresh.yml header]: main is auto-released as-is
on Wednesdays, so unreleased feature work parked on main ships early under a
patch bump — land it with its own release or hold it on a branch.

## Durable decisions (evidence noted; challenge if it fails)

- **Distribution model**: embed-first; the standalone CurseForge library is
  optional, declared via `OptionalDeps`, never a hard dependency (WoW's dep
  tooling makes a hard dep a fragile external moving part for no benefit).
  LibStub freshest-wins is the reference switch; one shared table per MAJOR,
  so multiple embedders converge on the freshest snapshot. Guards: keep the
  MAJOR string stable (bump only on breaking API change); the static API half
  is freshest-API-wins gated on `API_MINOR` (`achievement-rarity@21feb6c`).
  [carried — decided 2026-06-29, revisited and held]
- **Version scheme**: library releases are date-based, matching the
  snapshot-derived LibStub minor; the publish script stamps the library TOC
  per publish. Consumer (this addon) bumps semver by hand. [carried — settled
  2026-07-13]
- **Trust split**: the prod box holds DB access + a write deploy key and
  tags; GitHub Actions holds only the CF token and uploads on tag. Neither
  side ever holds both. [carried — design 2026-07-13]
- **Rank metric design** (denominator = all tracked accounts; percentile→date
  breakpoint inverse storage; 14 Oct 2008 bad-date floor; ladder
  `0,1,2,3,4,5,7,10,15,20,30,50,75,100`; holder floor 100/scope; nested
  encoding ~1.6 MB): implemented and shipped; methodology documented in the
  library README and `rarity-counter.py` comments — those are the durable
  homes, not this file. [carried — built 2026-07; in-game verified]
- **Panel row stays current rarity** (scan column must compare like with
  like; rank lives on focused surfaces only). [carried — decided pre-build]

## Parked — instance rarity (separate future session)

Rarity on Encounter Journal tiles/boss rows, world-map entrance pins, Group
Finder rows. All design decisions below [carried — probe-era, 2026-06]:

- Feasibility proven by the reverted hover probe (gratz-addon `Probe.lua`,
  commits `cd19bb6` / `92a308a`): each surface yields a `journalInstanceID`;
  lines append to `GameTooltip`.
- **Baked, hand-curated map** (instance/boss → achievement ids), not a
  runtime criteria walk. Structural links only — rarity always read live from
  the library, so a refresh can never desync the map.
- **Built in-client, not gratz-DB**: derive the seed via an in-client EJ-walk
  dump tool, hand-curate, freeze a bundled Lua table in this repo (the DB's
  criteria derive discards criterion type+asset; `dungeonEncounterID →
  journalInstanceID` is client-only).
- Remaining work: the dump tool; curation/gap-fill; expansion scope decision
  (Midnight-only vs all); port the three surface hooks (`Instance.lua`).
- Highest risk: EJ ScrollBox frame paths are version-specific and the
  boss-row hook was never exercised by the probe — validate on a current
  client first. Stay append-only on shown tooltips (taint-safe).
- References: `../gratz-addon/docs/addon-architecture.md` §6/§7/§11,
  `../gratz-addon/docs/rarity-data-library.md`.

## Deferred, not lost

- gratz-site attribution reframe ("gratz.gg-supplied" → "the Wizzleworks";
  casing) [carried — status not re-checked].
- Options "How the numbers work" link → a landing doc in the library repo;
  README already covers use + methodology, so optional [carried].

## In-game testing

- Symlink: `Interface/AddOns/HowRare` → this repo's `HowRare/`; `/reload`
  for edits. Lua errors hidden unless `/console scriptErrors 1` (or BugSack).
- Library smoke test: `/dump LibStub("AchievementRarity-1.0"):GetMeta()`.
