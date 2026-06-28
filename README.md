# How Rare?

A World of Warcraft companion addon that shows **how rare each achievement is** —
the share of accounts that have earned it — right where you see achievements in
game. The numbers come from **the Wizzleworks**, supplied by the embedded
[AchievementRarity](https://github.com/wizzleworks-gg/achievement-rarity) library —
How Rare? is its reference consumer.

## Features

One master switch (**How Rare? enabled**) governs every automatic
surface; the toast and its screenshot have their own toggles beneath it. Open the
options with `/howrare` or Settings → AddOns → How Rare?.

- **Rarity everywhere** — every achievement tooltip, incoming guild/nearby chat
  announcement, and Blizzard achievement-panel row gets its rarity (a tooltip
  reads `Rarity: 3%`). Panel rows — and, on by default, the achievement titles —
  are tinted by rarity tier (the loot-quality colours), so you can browse by
  rarity at a glance while scrolling.
- **Earned toast** — a companion toast on achievement earn carrying the rarity,
  styled to be screenshotted; it replaces Blizzard's own alert while on (optional
  auto-screenshot on earn). `/howrare share` (or the "Share rarest achievement"
  keybind) re-pops your rarest earned achievement as a shareable card.

## Privacy

Everything stays on your machine. The addon reads from Blizzard's own in-game API
and keeps its settings in local SavedVariables — it never sends anything anywhere.
(WoW addons can't reach the internet at runtime, and this one transmits nothing.)

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
