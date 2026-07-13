# How Rare? — Achievement Rarity

**How rare is that achievement?** How Rare? answers right where you look: every
achievement tooltip, incoming chat announcement, and achievement-panel row shows the
share of accounts that have earned it — `Rarity: 3%` — with panel rows and titles tinted
by rarity tier in the loot-quality colours, so you can browse by rarity at a glance.

## What you get

- **Rarity everywhere** — tooltips, chat announcements, and panel rows all carry the
  number; small clubs add the raw count (*"one of ~830"*). Blizzard's panel shows no
  tooltip on row hover — How Rare? adds the standard achievement tooltip there, rarity
  included (toggleable). Hold **Shift** while hovering for detail: the tier by name, the
  rarity in every region, and your earn date.
- **Your rank-at-earn** — *"you were in the first ~230 to earn this"* (or, for bigger
  clubs, *"the first 3%"*): how many tracked accounts earned it before you — on
  tooltips, on chat announcements of achievements you already hold, and on the toast,
  whenever you were notably early. Fully retroactive: it works for achievements earned
  years before installing.
- **Earned toast** — a companion toast on achievement earn carrying the rarity, styled
  to be screenshotted (it replaces Blizzard's alert while on). Rare-and-rarer earns tint
  the celebration flourish in their tier colour. Auto-screenshot is a mode — off, rare
  earns only, or all. `/howrare share` re-pops your rarest earned achievement as a
  shareable card.
- **How rare are YOU?** — `/howrare me` rates your whole collection: every earned
  achievement adds points for how surprising it is to hold, and your total reads out
  against all tracked accounts — *"your achievements are **Epic** — rarer than 96% of EU
  accounts"* — with a pinnable, screenshot-ready card, and the same verdict as an
  Achievements row on the Character Info stats pane.
- **Gz!** — enriched announcements of other players' earns get a small `[Gz!]` button
  only you can see; clicking it sends a one-line congratulation back where the
  announcement came from (guild chat for guild earns, local /say for nearby ones), with
  the rarity attached on notable earns — so the earner sees the number too. Strictly
  click-to-send: the addon never posts anything on its own.
- **Commands** — `/howrare top [n]` lists your rarest earned achievements as hoverable
  links; `/howrare me` shows your collection standing; `/howrare why <link>` explains
  every number (and every suppression) for one achievement; `/howrare status` prints
  data and version state.

One master switch governs every automatic surface, and each surface — tooltips, chat,
panel rows, row tooltips, the character-sheet row, the toast — has its own toggle:
`/howrare` or Settings → AddOns → How Rare?.

## Privacy

Everything stays on your machine. WoW addons can't reach the internet at runtime, and
this one transmits nothing on its own — the single thing it ever sends is the one-line
`[Gz!]` chat reply, only when you explicitly click it.

## Where the numbers come from

The data is by **the Wizzleworks**, supplied by the embedded **AchievementRarity**
library — a dated snapshot built from 830,000+ tracked accounts across US and EU. Each
figure carries its own "as of" date, and a new release embeds a fresher snapshot.
Installing the standalone **AchievementRarity** addon alongside How Rare? automatically
keeps the numbers at the latest published snapshot. Methodology and honesty rules:
[How the numbers work](https://github.com/wizzleworks-gg/achievement-rarity#how-the-numbers-work).

---

**How Rare?** is by the Wizzleworks. Source and issues:
[github.com/wizzleworks-gg/how-rare](https://github.com/wizzleworks-gg/how-rare).
