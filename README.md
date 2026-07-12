# How Rare?

A World of Warcraft companion addon that shows **how rare each achievement is** —
the share of accounts that have earned it — right where you see achievements in
game. The numbers come from **the Wizzleworks**, supplied by the embedded
[AchievementRarity](https://github.com/wizzleworks-gg/achievement-rarity) library —
How Rare? is its reference consumer.

## Features

One master switch (**How Rare? enabled**) governs every automatic surface, and each
surface — tooltips, chat, panel rows, row tooltips, the character-sheet row, the
toast — also has its own toggle. Open the options with `/howrare` or Settings →
AddOns → How Rare?.

- **Rarity everywhere** — every achievement tooltip, incoming guild/nearby chat
  announcement, and Blizzard achievement-panel row gets its rarity (a tooltip
  reads `Rarity: 3%`; when the holder club is small it adds the raw count —
  `(one of ~830)` — with the "small club" boundary configurable in the options).
  Panel rows — and, on by default, the achievement titles —
  are tinted by rarity tier (the loot-quality colours), so you can browse by
  rarity at a glance while scrolling. Blizzard's panel shows no tooltip on row
  hover; How Rare? adds the standard achievement tooltip there, rarity included
  (toggleable — turn it off if you prefer another addon's tooltip there). Hold
  **Shift** while hovering for detail: the tier by name, the rarity in every
  region, and your earn date.
- **Your rank-at-earn** — "you were in the first ~230 to earn this" (or, for
  bigger clubs, "the first 3%"): how many tracked accounts earned it before you,
  shown on the tooltip, on chat announcements of achievements you already hold
  (with a tick/cross and how long ago you earned it), and on the toast — whenever
  you were notably early among an achievement's earners. Retroactive: it works
  for achievements earned years before installing.
- **Earned toast** — a companion toast on achievement earn carrying the rarity,
  styled to be screenshotted; it replaces Blizzard's own alert while on.
  Rare-and-rarer earns tint the celebration flourish in their tier colour.
  Auto-screenshot is a mode — off, rare earns only, or all earns. `/howrare
  share` (or the "Share rarest achievement" keybind) re-pops your rarest earned
  achievement as a shareable card.
- **How rare are YOU?** — `/howrare me` answers the addon's title question for
  your whole collection: every earned achievement adds points for how surprising
  it is to hold (rare earns add more), and your total reads out against all
  tracked accounts — "your achievements are **Epic** — rarer than 96% of EU
  accounts", banded through the same loot-quality scale as single achievements,
  with a pinnable card built to be screenshotted. The verdict also lives (on by
  default, toggleable) as an Achievements row on the Character Info stats pane —
  hover it for the full standing; it appears once your collection rates Uncommon
  or better.
- **Gz!** — enriched announcements of other players' earns get a small `[Gz!]`
  button only you can see; clicking it sends a one-line congratulation back where
  the announcement came from (guild chat for guild earns, local /say for nearby
  ones), and on notable earns the rarity rides along — `Gz! [The Immortal] — only
  0.4% of EU accounts have this!` — so the earner (and everyone else) sees the
  number too. Strictly click-to-send: the addon never posts anything on its own.
- **Commands** — `/howrare top [n]` lists your rarest earned achievements as
  hoverable links; `/howrare me` shows your collection standing; `/howrare why
  <link>` explains every number (and every suppression) for one achievement;
  `/howrare status` prints data/version state. Alt-click (configurable) any
  achievement row or chat link to preview its card.

## Privacy

Everything stays on your machine. The addon reads from Blizzard's own in-game API
and keeps its settings in local SavedVariables. WoW addons can't reach the internet
at runtime, and this one transmits nothing on its own — the single thing it ever
sends is the one-line `[Gz!]` chat reply, only when you explicitly click it, into
guild chat for a guild earn or local /say for a nearby one.

## How the data works

The rarity numbers come from the **AchievementRarity** library by the Wizzleworks,
which How Rare? embeds (under `HowRare/Libs/`) and delegates every rarity lookup to.
WoW addons are sandboxed — no internet access at runtime — so the library ships its
data baked in, as a periodic snapshot; each figure carries its own "as of" date, and
a new release embeds a fresher one. For how the numbers are measured, see the
library's [How the numbers work](https://github.com/wizzleworks-gg/achievement-rarity#how-the-numbers-work).

## Development

Symlink the addon into your WoW install and `/reload` after edits:

```sh
ln -s "$(pwd)/HowRare" \
  "/Applications/World of Warcraft/_retail_/Interface/AddOns/HowRare"
```

### Updating the embedded library

The rarity data lives in the
[AchievementRarity](https://github.com/wizzleworks-gg/achievement-rarity) repo, which
How Rare? embeds under `HowRare/Libs/AchievementRarity-1.0/`. To ship a fresher
snapshot, regenerate the library's data there (from the gratz repo's
`scripts/export-rarity-library.py`, which pulls PROD), then re-copy the library folder
into `HowRare/Libs/` and commit:

```sh
cp -R ../achievement-rarity/AchievementRarity-1.0 HowRare/Libs/
```

### Releasing

Add a `## <version>` section to `CHANGELOG.md` for the release — CI uploads that
section verbatim as the CurseForge changelog (it falls back to "Release `<version>`"
if no matching section exists). Then tag the commit — CI
(`.github/workflows/release.yml`) stamps the tag as the version, builds the zip, and
uploads it to CurseForge:

```sh
git tag v1.0.0 && git push --tags
```

The tag version must match the `CHANGELOG.md` heading (and the `## Version:` in the
TOC, which the tag also overwrites). `scripts/release.sh` builds the same zip locally
for testing. CurseForge upload is inert until the `CF_API_KEY` secret and
`CF_PROJECT_ID` variable are configured on the repo.

## License

© 2026 the Wizzleworks. All rights reserved — see [LICENSE](LICENSE). The embedded
libraries under `HowRare/Libs/` keep their own licenses: LibStub (public domain) and
AchievementRarity (MIT — the rarity data by the Wizzleworks).
