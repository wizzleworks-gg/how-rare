# Toast & collection verdict — story over flex

**Status: PROPOSAL — not signed off.** Drafted 2026-08-02 from a live design
session; **requires explicit sign-off in a future session before any
implementation.** Queued behind the Guild Finder theme. This is the addon-side
companion of gratz `docs/proposals/38-outward-surfaces-story-rework.md` (§38),
which carries the full rationale, the estate-wide principle, and the data-side
work (ordinal rarity, collection-score export). Read §38 first.

## Why (one paragraph — §38 has the argument)

The toast is the addon's one surface built to travel (screenshots reach
non-users; it carries the brand mark for exactly that reason), and today its
payload is a population flex ("Held by 0.4% of EU accounts" / "One of only ~830
people"). Field observation: posted into an achievement community, that frame
draws arguments, not congratulations — those channels celebrate *effort*, and
scarcity stapled to a self-post reads as a status claim. The addon's own Gz!
line is the counter-example: the same figure said about *someone else, in
praise* (`Chat.lua:40`) lands as generosity. Proposal: the toast celebrates the
earn by telling its **story** — self-referential, effort-shaped — and the
population percent retreats to the pull surfaces where it already lives.

## The toast: story ladder (proposed)

The rarity sentence row is replaced by **one story line, first match wins**,
all computable in-game:

1. **Journey** (meta-achievements): "Four years in the making — first step
   12 Mar 2022." From the constituent achievements' earn dates. *Probe needed:*
   confirm the client exposes per-criterion / child-achievement completion
   dates reliably enough (which meta shapes qualify; behaviour when children
   pre-date account merges).
2. **Personal best**: "Your rarest achievement yet." Rarity vs your own
   previous rarest (the `EarnedRarities` scan exists). *Semantics to pin:*
   off-snapshot new earns (no rarity value); alt earns (the event fires with
   the already-earned flag — today's no-skip rule keeps them, so the PB check
   should too); whether "rarest this year" is a second rung or copy variant.
3. **Milestone**: "Your 2,500th achievement." *Probe needed:* the client's
   completed-count API and which milestones qualify (every 500? powers of 10?).
4. **Tiny club** (under the existing small-club knob): "~830 EU accounts hold
   this." Present-tense, scoped noun, **no "only"** — see the audit below.
5. **Nothing.** Name, tier colour, points, earn date is a complete
   celebration — Blizzard's own alert carries zero numbers and is iconic.

**What stays:** tier-tinted name (quality is a property of the thing, the loot-
colour idiom), points shield, flourish, brand mark, screenshot mechanics, the
mover, the earn-date footer with its as-of note.

**What leaves the toast:** the population percent line (stays on tooltips /
panel / `/howrare why` — pull surfaces, unchanged); the **rank-at-earn brag**
in the footer ("you were in the first ~230") — it is literally a rank claim, so
it retreats to the pull surfaces too (tooltip, chat enrichment, `why`), where
it remains information you look up about yourself.

**Share paths follow the composition:** `/howrare share`, the keybind, and the
showcase pin re-pop the same card, so they inherit the story footer instead of
the rank brag. What "share your rarest" leads with under the story frame
(journey line? PB framing?) is an open call.

## The collection verdict: top-K tier, not percentile (proposed)

Today `/howrare me`, the standing card, and the Character Info row headline
with a percentile flex ("your achievements are Epic — **rarer than 96% of EU
accounts**"). Proposed headline: **your rarest K earns' mean rarity, banded to
tier** — "your rarest 20 average **Epic**" — self-referential, meaningful
against the fixed tier scale, and a climbable personal best (the "are my earns
getting rarer" metric). The percentile survives as *detail* (the hover tooltip
/ `why`-style breakdown), not the headline.

The score definition lands in the gratz-side counter + AchievementRarity
export (§38 §8) so site and addon read one definition; the rejected
denominator variant and its failure modes are recorded there. Addon-side
consumers to update together: `Toast.lua` `PopulateStanding`,
`CharacterSheet.lua`, `Options.lua` about block, `/howrare me` chat output.

## Denominator-noun audit (severable copy pass)

Rule (§38 §4): the noun always travels with the denominator — "accounts",
scoped, never "people"; no "only" in self-facing copy; small-club facts
present-tense. Audit as of 2026-08-02:

- `Toast.lua:311` — count form says `ScopeNoun("people")` while the percent
  form of the same surface says "accounts": the one **noun** drift. → scoped
  "accounts".
- `Toast.lua:309` — "One of only ~830…": the one self-facing **"only"**. →
  drop the word (or the whole line becomes ladder rung 4's phrasing).
- `Chat.lua:40` — "only X% of EU accounts have this!" **stays as is**: it's
  the Gz! praise of someone else, the counter-example this whole rework is
  built on (and its noun is already right).
- Everything else already says "accounts" (`CharacterSheet.lua:31`,
  `Options.lua:445`, `Chat.lua:41`, `Toast.lua:314/:653`).

This pass is severable and worth doing even if the rest is rejected.

## Open calls (for the sign-off session)

- Ladder order and membership: is tiny-club (rung 4) wanted at all, or does
  story-only (1–3, else nothing) read cleaner?
- The two probes: meta constituent dates; completed-count/milestone API.
- PB semantics (off-snapshot, alts, "rarest this year").
- What `/howrare share` leads with under the story frame.
- K for the collection verdict, and under-K behaviour for young collections
  (shared call with §38 §8).
- Whether the Character Info row keeps the tier word alone or gains the top-K
  phrasing on hover.

## Release note

Feature release (minor bump), own tag — and per the repo rule, don't park it on
`main` across a Wednesday reset, or the data train ships it half-done.
