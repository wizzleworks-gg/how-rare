# HANDOVER — How Rare? rarity-surface expansion (next theme, design agreed)

**This theme:** grow where How Rare? surfaces rarity — a **rarity-at-earn** foundation, then
chat / toast surfaces that use it, then **rarity on dungeon/raid content** (Encounter
Journal, map pins, Group Finder). All **in How Rare?** (the rarity layer). Design agreed
2026-06-28; **not yet built**.

Builds on the architecture doc (`../gratz-addon/docs/addon-architecture.md`): §6
(rarity-at-earn), §7 (instance→achievement map), §3③ (the instance-tooltips addon), and the
reverted hover probe (`../gratz-addon/docs/dungeon-raid-hover-probe.md`). Those are the *why*
and the grounded findings; this is the build order.

## Previous theme — shipped

The rarity-data-library extraction is **committed and pushed**: `achievement-rarity` (new
public MIT library), How Rare? as its reference consumer (`how-rare@6fe4041`), brand sweep
(`gratz-addon@39d95d9`). Deferred loose ends carried below.

## The foundation — rarity-at-earn (§6)

Everything else reads this. **Decided: stamp-at-earn now; historical curve later.**

- **Stamp-at-earn (build now):** on `ACHIEVEMENT_EARNED`, persist the current snapshot's
  rarity for that id into `HowRareDB`. Forward-only (nothing for already-earned
  achievements) and it captures the *shipped snapshot when you earned it*, not true
  population-rarity-at-date — accepted for v1.
  - **Open design detail:** *what* to stamp. Options: just the home-region pct + `asOf`;
    or region+global pcts; or the raw `{us,eu,global}` counts + denominators + `asOf` (full
    fidelity, lets any scope/format be reconstructed later). Lean: store enough to show
    "X% when earned" under the user's scope without re-deriving — region+global pct + asOf.
- **Historical curve (later, preferred, gratz-side):** bake "fraction of accounts that had X
  by date D" from the corpus `earned_at[]` (aligned to the membership bitmap; gratz
  migrations 024/037). Retroactive + true rarity-at-earn. Swaps in behind the same display.
  Caveat: corpus historical depth bounds how far back it's *observed* vs *reconstructed* —
  verify coverage before promising it on old content.

## Surface A — chat "you've got this" (extends Chat.lua)

Chat.lua already tags incoming achievement links with *current* rarity. Add:
- **Your completion** (✓/✗) — free, `GetAchievementInfo` gives account-wide completion
  (Core's `G.SelfCompleted`).
- **Your rarity-at-earn** when earned + stamped — e.g. *"✓ You earned this ~3 months ago —
  2% then · 4% now."*
- **Relative earn age** — render *your* earn as a humanised "~X ago" (a few days / 1 week /
  1 month / 3 months / …), rougher and friendlier than an exact date.
- **The linker's own number: only if genuinely obtainable** — don't fabricate it. In
  practice a chat link carries no earn data and we can't read their SavedVariables, so the
  default is *your* status + *your* at-earn; surface theirs only where an API actually
  provides it.

## Surface B — toast, share path (Toast.lua)

At a *live* earn, rarity-at-earn == current rarity (earned today) — nothing extra. The payoff
is the **`/howrare share` re-pop of an *old* achievement**: show *"was 1% when you earned it ·
3% now."* So this is "at-earn on the share/replay path," not the live earn.

- The stamp lives in `HowRareDB` (plain), so a user *could* edit it — but it's a brag stat,
  not security-sensitive. Encoding/obfuscating to prevent tampering is **overkill**; leave it
  plain.

## Surface C — rarity on dungeons/raids (the big one)

Show the rarity of achievements tied to a boss/instance on its tooltip. **Decided: in How
Rare?**, rarity-focused. The planned separate instance-tooltips addon (③) is **dropped** — it
wasn't rarity-focused; its surfaces fold into How Rare? as a rarity feature instead.

- **Proven feasible** — the hover probe prototyped all three surfaces (then reverted to
  gratz-addon git history): **world-map entrance pins, Group-Finder (LFD) rows, Adventure
  Guide / Encounter Journal** instance tiles *and* boss rows. Each yields a
  `journalInstanceID`; lines append to `GameTooltip`. (Port note: the probe was in the
  monolith `gratz-addon` `Gratz/Probe.lua` `/gz` — commits `cd19bb6` initial / `92a308a`
  3-surface preserve; reviving = porting into How Rare? `/howrare`, reading the library API.)
- **The map is BAKED + CURATED, not runtime-derived (decided).** Rather than walk ~8,353
  achievements' criteria at runtime (the probe's approach), **build the map once and ship it**
  as a baked table in How Rare? (the way the old rarity `Data/` was baked). It's a
  **cherry-picked** set of **direct achievement ↔ instance/boss links** — deliberately pick
  the meaningful achievements (heroic/mythic clears, boss kills, glory metas) against the
  dungeons/raids/bosses and link them directly. A lookup, not a criteria walk — more
  performant, and **additive**.
- **This dissolves the heroic-clear gap:** "Heroic: \<raid\>" completion achievements that
  map via *neither* criteria type-165 nor a type-8 meta are simply **curated in directly** —
  no detection heuristic needed.
- **Open: where the curated map is built.** Either (a) an in-client dump tool (the probe's
  EJ-walk derivation) → hand-curate / gap-fill → freeze a shipped Lua table; or (b) curate
  the links in the gratz DB (like the curated categories) and export them (a second export
  script). The EJ walk that resolves `dungeonEncounterID → journalInstanceID` is client-side,
  so at least the *seed* is built in-client.

## Open sub-questions (author to ratify)

- **Stamp granularity** — what exactly to persist at earn (see Foundation).
- **Where the curated instance map is built** — in-client dump + curate vs gratz-DB curation
  + export (see Surface C).
- **Historical-curve timing** — when the gratz-side rarity-at-earn dataset becomes worth
  building.

*(Decided: ③ instance-tooltips is dropped — its surfaces fold into How Rare? as a
rarity-focused feature; see Surface C.)*

## Suggested sequencing

1. **Stamp-at-earn** (Core + `HowRareDB`) — the foundation; cheap.
2. **Chat enrichment** (A) — small, high-visibility, reads the stamp + completion.
3. **Toast share-path at-earn** (B) — small.
4. **Instance rarity** (C) — larger: port the probe, build the all-expansions map, gap-fill
   heroic-clear. The all-expansions map is one-time bounded work (today's curated data is
   Midnight-only).

## Deferred from the shipped library theme (don't lose)

- **Publish milestone — do these together, once v1 is settled:**
  - Crawler → export → push automation (run `gratz/scripts/export-rarity-library.py` after
    the rarity counter, push the `achievement-rarity` repo).
  - Standalone CurseForge publish of the library + a release workflow (the repo has none yet).
  - gratz-site attribution reframe ("gratz.gg-supplied" → "the Wizzleworks"; casing) — folded
    into the same push.
- **Options "How the numbers work" link** → a file in the `achievement-rarity` repo serving
  both audiences: how to *use* the library (the exposed API) **and** the methodology. The
  README already covers both; a dedicated landing doc is optional. (Repo is already public, so
  this no longer waits on anything.)

## In-game testing (unchanged)

- Symlinked: `Interface/AddOns/HowRare` → this repo's `HowRare/`. `/reload` for edits.
- Lua errors hidden unless `/console scriptErrors 1` (or BugSack).

## Delete me

Delete when this theme's surfaces ship (or the theme is re-scoped).
