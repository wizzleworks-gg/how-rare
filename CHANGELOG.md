# Changelog

## 1.0.2

Rarity data refresh — snapshot as of 2026-07-22.

## 1.0.1

Rarity data refresh — snapshot as of 2026-07-17.

## 1.0.0

Initial release. Achievement rarity from the Wizzleworks on every tooltip, chat line, and
achievement-panel row — the share of accounts that have each achievement, tinted by
rarity tier — plus an earned toast for your rare pickups, with a tier-tinted celebration
flourish and an optional auto-screenshot (off / rare earns / all). Blizzard's panel shows
no tooltip on row hover, so How Rare? adds the standard achievement tooltip there, rarity
included (toggleable, for players whose achievement addon already provides one).

Also in this release: your **rank-at-earn** ("you were in the first ~230 to earn this" —
or, for bigger clubs, "the first 3%": how many tracked accounts earned it before you) on
tooltips, chat, and the toast whenever you were notably early; a Shift-hover tooltip
detail view (tier, every region, your earn date); raw counts on small-club tooltips
("one of ~830"), with the small-club boundary configurable (default: clubs under
2,500); `/howrare top` (your rarest earned, as hoverable links) and
`/howrare why` (explains every number and every suppression for one achievement); and a
per-surface toggle for each of tooltips, chat, panel rows, row tooltips, and the toast.

And two headliners: **How rare are YOU?** — `/howrare me` scores your whole collection
(every earn adds points for how surprising it is to hold) and reads it out against all
tracked accounts — "your achievements are **Epic** — rarer than 96% of EU accounts" —
with a pinnable, screenshot-ready card, and the same verdict as an Achievements row on
the Character Info stats pane (hover for the full standing; shown from Uncommon up). And **Gz!** — a click-only
button on enriched announcements of others' earns that sends a one-line congratulation
back where it came from (guild chat, or /say for nearby earns), with the rarity attached
on notable earns — so non-users see the numbers too. Nothing is ever sent without your
click.
